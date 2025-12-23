require "sinatra/base"
require "json"
require "faye/websocket"

module DecisionAgent
  module Monitoring
    # Real-time monitoring dashboard server
    class DashboardServer < Sinatra::Base
      set :public_folder, File.expand_path("dashboard/public", __dir__)
      set :views, File.expand_path("dashboard/views", __dir__)
      set :bind, "0.0.0.0"
      set :port, 4568
      set :server, :puma

      # Enable CORS
      before do
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        headers["Access-Control-Allow-Headers"] = "Content-Type"
      end

      options "*" do
        200
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
          json_message = message.to_json
          @websocket_clients.each do |client|
            client.send(json_message) if client.ready_state == Faye::WebSocket::API::OPEN
          rescue => e
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
      get "/" do
        send_file File.join(settings.public_folder, "index.html")
      end

      # WebSocket endpoint for real-time updates
      get "/ws" do
        if Faye::WebSocket.websocket?(request.env)
          ws = Faye::WebSocket.new(request.env)

          ws.on :open do |event|
            self.class.add_websocket_client(ws)

            # Send initial state
            ws.send({
              type: "connected",
              message: "Connected to DecisionAgent monitoring",
              timestamp: Time.now.utc.iso8601
            }.to_json)
          end

          ws.on :message do |event|
            # Handle client messages
            handle_websocket_message(ws, event.data)
          end

          ws.on :close do |event|
            self.class.remove_websocket_client(ws)
          end

          ws.rack_response
        else
          status 426
          { error: "WebSocket connection required" }.to_json
        end
      end

      # API: Get current statistics
      get "/api/stats" do
        content_type :json

        time_range = params[:time_range]&.to_i
        stats = self.class.metrics_collector.statistics(time_range: time_range)

        stats.to_json
      end

      # API: Get time series data
      get "/api/timeseries/:metric_type" do
        content_type :json

        metric_type = params[:metric_type].to_sym
        bucket_size = (params[:bucket_size] || 60).to_i
        time_range = (params[:time_range] || 3600).to_i

        data = self.class.metrics_collector.time_series(
          metric_type: metric_type,
          bucket_size: bucket_size,
          time_range: time_range
        )

        data.to_json
      end

      # API: Prometheus metrics endpoint
      get "/metrics" do
        content_type PrometheusExporter::CONTENT_TYPE
        self.class.prometheus_exporter.export
      end

      # API: Get Prometheus metrics in JSON format
      get "/api/metrics" do
        content_type :json
        self.class.prometheus_exporter.metrics_hash.to_json
      end

      # API: Register custom KPI
      post "/api/kpi" do
        content_type :json

        begin
          data = JSON.parse(request.body.read, symbolize_names: true)

          self.class.prometheus_exporter.register_kpi(
            name: data[:name],
            value: data[:value],
            labels: data[:labels] || {},
            help: data[:help]
          )

          { success: true, message: "KPI registered" }.to_json
        rescue => e
          status 400
          { error: e.message }.to_json
        end
      end

      # API: Get active alerts
      get "/api/alerts" do
        content_type :json
        self.class.alert_manager.active_alerts.to_json
      end

      # API: Get all alerts
      get "/api/alerts/all" do
        content_type :json
        limit = (params[:limit] || 100).to_i
        self.class.alert_manager.all_alerts(limit: limit).to_json
      end

      # API: Create alert rule
      post "/api/alerts/rules" do
        content_type :json

        begin
          data = JSON.parse(request.body.read, symbolize_names: true)

          # Parse condition
          condition = parse_alert_condition(data[:condition], data[:condition_type])

          rule = self.class.alert_manager.add_rule(
            name: data[:name],
            condition: condition,
            severity: (data[:severity] || :warning).to_sym,
            threshold: data[:threshold],
            message: data[:message],
            cooldown: data[:cooldown] || 300
          )

          status 201
          rule.to_json
        rescue => e
          status 400
          { error: e.message }.to_json
        end
      end

      # API: Toggle alert rule
      put "/api/alerts/rules/:rule_id/toggle" do
        content_type :json

        begin
          data = JSON.parse(request.body.read, symbolize_names: true)
          enabled = data[:enabled] || false

          self.class.alert_manager.toggle_rule(params[:rule_id], enabled)

          { success: true, message: "Rule #{enabled ? 'enabled' : 'disabled'}" }.to_json
        rescue => e
          status 400
          { error: e.message }.to_json
        end
      end

      # API: Acknowledge alert
      post "/api/alerts/:alert_id/acknowledge" do
        content_type :json

        begin
          data = JSON.parse(request.body.read, symbolize_names: true)
          acknowledged_by = data[:acknowledged_by] || "user"

          self.class.alert_manager.acknowledge_alert(params[:alert_id], acknowledged_by: acknowledged_by)

          { success: true, message: "Alert acknowledged" }.to_json
        rescue => e
          status 400
          { error: e.message }.to_json
        end
      end

      # API: Resolve alert
      post "/api/alerts/:alert_id/resolve" do
        content_type :json

        begin
          data = JSON.parse(request.body.read, symbolize_names: true)
          resolved_by = data[:resolved_by] || "user"

          self.class.alert_manager.resolve_alert(params[:alert_id], resolved_by: resolved_by)

          { success: true, message: "Alert resolved" }.to_json
        rescue => e
          status 400
          { error: e.message }.to_json
        end
      end

      # Health check
      get "/health" do
        content_type :json
        {
          status: "ok",
          version: DecisionAgent::VERSION,
          websocket_clients: self.class.websocket_clients.size,
          metrics_count: self.class.metrics_collector.metrics_count
        }.to_json
      end

      # Class method to start the server
      def self.start!(port: 4568, host: "0.0.0.0", metrics_collector:, prometheus_exporter:, alert_manager:)
        configure_monitoring(
          metrics_collector: metrics_collector,
          prometheus_exporter: prometheus_exporter,
          alert_manager: alert_manager
        )

        set :port, port
        set :bind, host
        run!
      end

      private

      def handle_websocket_message(ws, data)
        message = JSON.parse(data, symbolize_names: true)

        case message[:action]
        when "subscribe"
          # Send current stats
          stats = self.class.metrics_collector.statistics
          ws.send({ type: "stats", data: stats }.to_json)
        when "get_alerts"
          alerts = self.class.alert_manager.active_alerts
          ws.send({ type: "alerts", data: alerts }.to_json)
        end
      rescue => e
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
    end
  end
end
