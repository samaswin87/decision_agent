require "rack"
require "json"
require_relative "../web/rack_helpers"
require_relative "../web/rack_request_helpers"

# Faye/WebSocket is optional for real-time features
begin
  require "faye/websocket"
  WEBSOCKET_AVAILABLE = true
rescue LoadError
  WEBSOCKET_AVAILABLE = false
  warn "Warning: faye-websocket gem not found. Real-time dashboard features will be disabled."
  warn "Install with: gem install faye-websocket"
end

module DecisionAgent
  module Monitoring
    # Real-time monitoring dashboard server
    # Framework-agnostic: Pure Rack application compatible with any Rack server
    class DashboardServer
      PUBLIC_FOLDER = File.expand_path("dashboard/public", __dir__)
      VIEWS_FOLDER = File.expand_path("dashboard/views", __dir__)

      class << self
        attr_accessor :metrics_collector, :prometheus_exporter, :alert_manager, :public_folder, :views_folder, :bind, :port
        attr_reader :websocket_clients

        def router
          @router ||= begin
            router = Web::RackHelpers::Router.new
            define_routes(router)
            router
          end
        end

        # Rack call method - entry point for Rack requests
        def call(env)
          new.call(env)
        end

        def define_routes(router)
          # Enable CORS
          router.before do |ctx|
            ctx.headers["Access-Control-Allow-Origin"] = "*"
            ctx.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
            ctx.headers["Access-Control-Allow-Headers"] = "Content-Type"
          end

          # OPTIONS handler for CORS preflight
          router.options "*" do |ctx|
            ctx.status(200)
            ctx.body("")
          end

      # Class-level configuration
      class << self
        attr_accessor :metrics_collector, :prometheus_exporter, :alert_manager
        attr_reader :websocket_clients

        def configure_monitoring(metrics_collector:, prometheus_exporter:, alert_manager:)
          @metrics_collector = metrics_collector
          @prometheus_exporter = prometheus_exporter
          @alert_manager = alert_manager
          @websocket_clients = []

          setup_real_time_updates
        end

        def setup_real_time_updates
          # Register observer for real-time metric updates
          @metrics_collector.add_observer do |event_type, metric|
            broadcast_to_clients({
                                   type: "metric_update",
                                   event: event_type,
                                   data: metric,
                                   timestamp: Time.now.utc.iso8601
                                 })
          end

          # Register alert handler
          @alert_manager.add_handler do |alert|
            broadcast_to_clients({
                                   type: "alert",
                                   data: alert,
                                   timestamp: Time.now.utc.iso8601
                                 })
          end
        end

        def broadcast_to_clients(message)
          return unless WEBSOCKET_AVAILABLE
          return if @websocket_clients.empty? # Skip if no clients connected

          json_message = message.to_json
          @websocket_clients.each do |client|
            client.send(json_message) if client.ready_state == Faye::WebSocket::API::OPEN
          rescue StandardError => e
            warn "WebSocket send failed: #{e.message}"
          end
        end

        def add_websocket_client(ws)
          @websocket_clients << ws
        end

        def remove_websocket_client(ws)
          @websocket_clients.delete(ws)
        end
      end

          # Main dashboard page
          router.get "/" do |ctx|
            index_file = File.join(DashboardServer.public_folder || PUBLIC_FOLDER, "index.html")
            if File.exist?(index_file)
              ctx.send_file(index_file)
            else
              ctx.status(404)
              ctx.body("Dashboard page not found")
            end
          end

          # WebSocket endpoint for real-time updates
          router.get "/ws" do |ctx|
            unless WEBSOCKET_AVAILABLE
              ctx.status(503)
              ctx.content_type "application/json"
              ctx.json({ error: "WebSocket support not available. Install faye-websocket gem." })
              next
            end

            if Faye::WebSocket.websocket?(ctx.env)
              ws = Faye::WebSocket.new(ctx.env)

              ws.on :open do |_event|
                DashboardServer.add_websocket_client(ws)

                # Send initial state
                ws.send({
                  type: "connected",
                  message: "Connected to DecisionAgent monitoring",
                  timestamp: Time.now.utc.iso8601
                }.to_json)
              end

              ws.on :message do |event|
                # Handle client messages
                DashboardServer.handle_websocket_message(ws, event.data)
              end

              ws.on :close do |_event|
                DashboardServer.remove_websocket_client(ws)
              end

              ws.rack_response
            else
              ctx.status(426)
              ctx.content_type "application/json"
              ctx.json({ error: "WebSocket connection required" })
            end
          end

          # API: Get current statistics
          router.get "/api/stats" do |ctx|
            ctx.content_type "application/json"

            time_range = (ctx.params[:time_range] || ctx.params["time_range"])&.to_i
            stats = DashboardServer.metrics_collector.statistics(time_range: time_range)

            ctx.json(stats)
          end

          # API: Get time series data
          router.get "/api/timeseries/:metric_type" do |ctx|
            ctx.content_type "application/json"

            metric_type = (ctx.params[:metric_type] || ctx.params["metric_type"]).to_sym
            bucket_size = ((ctx.params[:bucket_size] || ctx.params["bucket_size"]) || 60).to_i
            time_range = ((ctx.params[:time_range] || ctx.params["time_range"]) || 3600).to_i

            data = DashboardServer.metrics_collector.time_series(
              metric_type: metric_type,
              bucket_size: bucket_size,
              time_range: time_range
            )

            ctx.json(data)
          end

          # API: Prometheus metrics endpoint
          router.get "/metrics" do |ctx|
            ctx.content_type DashboardServer.prometheus_exporter.class::CONTENT_TYPE
            ctx.body(DashboardServer.prometheus_exporter.export)
          end

          # API: Get Prometheus metrics in JSON format
          router.get "/api/metrics" do |ctx|
            ctx.content_type "application/json"
            ctx.json(DashboardServer.prometheus_exporter.metrics_hash)
          end

          # API: Register custom KPI
          router.post "/api/kpi" do |ctx|
            ctx.content_type "application/json"

            begin
              request_body = Web::RackRequestHelpers.read_body(ctx.env)
              data = JSON.parse(request_body, symbolize_names: true)

              DashboardServer.prometheus_exporter.register_kpi(
                name: data[:name],
                value: data[:value],
                labels: data[:labels] || {},
                help: data[:help]
              )

              ctx.json({ success: true, message: "KPI registered" })
            rescue StandardError => e
              ctx.status(400)
              ctx.json({ error: e.message })
            end
          end

          # API: Get active alerts
          router.get "/api/alerts" do |ctx|
            ctx.content_type "application/json"
            ctx.json(DashboardServer.alert_manager.active_alerts)
          end

          # API: Get all alerts
          router.get "/api/alerts/all" do |ctx|
            ctx.content_type "application/json"
            limit = ((ctx.params[:limit] || ctx.params["limit"]) || 100).to_i
            ctx.json(DashboardServer.alert_manager.all_alerts(limit: limit))
          end

          # API: Create alert rule
          router.post "/api/alerts/rules" do |ctx|
            ctx.content_type "application/json"

            begin
              request_body = Web::RackRequestHelpers.read_body(ctx.env)
              data = JSON.parse(request_body, symbolize_names: true)

              # Parse condition
              condition = DashboardServer.parse_alert_condition(data[:condition], data[:condition_type])

              rule = DashboardServer.alert_manager.add_rule(
                name: data[:name],
                condition: condition,
                severity: (data[:severity] || :warning).to_sym,
                threshold: data[:threshold],
                message: data[:message],
                cooldown: data[:cooldown] || 300
              )

              ctx.status(201)
              ctx.json(rule)
            rescue StandardError => e
              ctx.status(400)
              ctx.json({ error: e.message })
            end
          end

          # API: Toggle alert rule
          router.put "/api/alerts/rules/:rule_id/toggle" do |ctx|
            ctx.content_type "application/json"

            begin
              request_body = Web::RackRequestHelpers.read_body(ctx.env)
              data = JSON.parse(request_body, symbolize_names: true)
              enabled = data[:enabled] || false
              rule_id = ctx.params[:rule_id] || ctx.params["rule_id"]

              DashboardServer.alert_manager.toggle_rule(rule_id, enabled)

              ctx.json({ success: true, message: "Rule #{enabled ? 'enabled' : 'disabled'}" })
            rescue StandardError => e
              ctx.status(400)
              ctx.json({ error: e.message })
            end
          end

          # API: Acknowledge alert
          router.post "/api/alerts/:alert_id/acknowledge" do |ctx|
            ctx.content_type "application/json"

            begin
              request_body = Web::RackRequestHelpers.read_body(ctx.env)
              data = JSON.parse(request_body, symbolize_names: true)
              acknowledged_by = data[:acknowledged_by] || "user"
              alert_id = ctx.params[:alert_id] || ctx.params["alert_id"]

              DashboardServer.alert_manager.acknowledge_alert(alert_id, acknowledged_by: acknowledged_by)

              ctx.json({ success: true, message: "Alert acknowledged" })
            rescue StandardError => e
              ctx.status(400)
              ctx.json({ error: e.message })
            end
          end

          # API: Resolve alert
          router.post "/api/alerts/:alert_id/resolve" do |ctx|
            ctx.content_type "application/json"

            begin
              request_body = Web::RackRequestHelpers.read_body(ctx.env)
              data = JSON.parse(request_body, symbolize_names: true)
              resolved_by = data[:resolved_by] || "user"
              alert_id = ctx.params[:alert_id] || ctx.params["alert_id"]

              DashboardServer.alert_manager.resolve_alert(alert_id, resolved_by: resolved_by)

              ctx.json({ success: true, message: "Alert resolved" })
            rescue StandardError => e
              ctx.status(400)
              ctx.json({ error: e.message })
            end
          end

          # Health check
          router.get "/health" do |ctx|
            ctx.content_type "application/json"
            ctx.json({
              status: "ok",
              version: DecisionAgent::VERSION,
              websocket_clients: DashboardServer.websocket_clients.size,
              metrics_count: DashboardServer.metrics_collector.metrics_count
            })
          end
        end

        def configure_monitoring(metrics_collector:, prometheus_exporter:, alert_manager:)
          @metrics_collector = metrics_collector
          @prometheus_exporter = prometheus_exporter
          @alert_manager = alert_manager
          @websocket_clients = []

          setup_real_time_updates
        end

        def setup_real_time_updates
          # Register observer for real-time metric updates
          @metrics_collector.add_observer do |event_type, metric|
            broadcast_to_clients({
                                   type: "metric_update",
                                   event: event_type,
                                   data: metric,
                                   timestamp: Time.now.utc.iso8601
                                 })
          end

          # Register alert handler
          @alert_manager.add_handler do |alert|
            broadcast_to_clients({
                                   type: "alert",
                                   data: alert,
                                   timestamp: Time.now.utc.iso8601
                                 })
          end
        end

        def broadcast_to_clients(message)
          return unless WEBSOCKET_AVAILABLE
          return if @websocket_clients.empty? # Skip if no clients connected

          json_message = message.to_json
          @websocket_clients.each do |client|
            client.send(json_message) if client.ready_state == Faye::WebSocket::API::OPEN
          rescue StandardError => e
            warn "WebSocket send failed: #{e.message}"
          end
        end

        def add_websocket_client(ws)
          @websocket_clients ||= []
          @websocket_clients << ws
        end

        def remove_websocket_client(ws)
          @websocket_clients ||= []
          @websocket_clients.delete(ws)
        end

        def handle_websocket_message(ws, data)
          message = JSON.parse(data, symbolize_names: true)

          case message[:action]
          when "subscribe"
            # Send current stats
            stats = metrics_collector.statistics
            ws.send({ type: "stats", data: stats }.to_json)
          when "get_alerts"
            alerts = alert_manager.active_alerts
            ws.send({ type: "alerts", data: alerts }.to_json)
          end
        rescue StandardError => e
          ws.send({ type: "error", message: e.message }.to_json)
        end

        def parse_alert_condition(condition_data, condition_type)
          case condition_type
          when "high_error_rate"
            AlertManager.high_error_rate(threshold: condition_data[:threshold] || 0.1)
          when "low_confidence"
            AlertManager.low_confidence(threshold: condition_data[:threshold] || 0.5)
          when "high_latency"
            AlertManager.high_latency(threshold_ms: condition_data[:threshold_ms] || 1000)
          when "error_spike"
            AlertManager.error_spike(threshold: condition_data[:threshold] || 10)
          when "custom"
            condition_data
          else
            raise "Unknown condition type: #{condition_type}"
          end
        end

        # Class method to start the server
        # Framework-agnostic: uses Rack::Server which supports any Rack-compatible server
        def start!(metrics_collector:, prometheus_exporter:, alert_manager:, port: 4568, host: "0.0.0.0")
          configure_monitoring(
            metrics_collector: metrics_collector,
            prometheus_exporter: prometheus_exporter,
            alert_manager: alert_manager
          )

          @port = port
          @bind = host
          @public_folder = PUBLIC_FOLDER
          @views_folder = VIEWS_FOLDER

          puts "🎯 DecisionAgent Monitoring Dashboard starting..."
          puts "📍 Server: http://#{host == '0.0.0.0' ? 'localhost' : host}:#{port}"
          puts "⚡️  Press Ctrl+C to stop"
          puts ""

          # Use Rack::Server which automatically selects the best available handler
          # Supports: Puma, WEBrick, Thin, Unicorn, etc. (any Rack-compatible server)
          Rack::Server.start(
            app: self,
            Port: port,
            Host: host,
            server: ENV.fetch("RACK_HANDLER", nil), # Allows override via ENV
            environment: ENV.fetch("RACK_ENV", "development")
          )
        end
      end

      def call(env)
        route_match = DashboardServer.router.match(env)
        unless route_match
          return [404, { "Content-Type" => "text/plain" }, ["Not Found"]]
        end

        # Create request context with route params
        ctx = Web::RackRequestHelpers::RequestContext.new(env, route_match[:params] || {})

        # Run before filters
        route_match[:before_filters].each do |filter|
          filter.call(ctx)
          return ctx.to_rack_response if ctx.halted?
        end

        # Execute route handler
        begin
          route_match[:handler].call(ctx)
          ctx.to_rack_response
        rescue StandardError => e
          [500, { "Content-Type" => "application/json" }, [{ error: e.message }.to_json]]
        end
      end
    end
  end
end
