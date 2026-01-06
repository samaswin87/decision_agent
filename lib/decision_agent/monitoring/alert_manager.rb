require "monitor"

module DecisionAgent
  module Monitoring
    # Alert manager for anomaly detection and notifications
    class AlertManager
      include MonitorMixin

      attr_reader :rules, :alerts

      def initialize(metrics_collector:)
        super()
        @metrics_collector = metrics_collector
        @rules = []
        @alerts = []
        @alert_handlers = []
        @check_interval = 60 # seconds
        @monitoring_thread = nil
        @rule_counter = 0
        freeze_config
      end

      # Define an alert rule
      def add_rule(name:, condition:, severity: :warning, threshold: nil, message: nil, cooldown: 300)
        synchronize do
          rule = {
            id: generate_rule_id(name),
            name: name,
            condition: condition,
            severity: severity,
            threshold: threshold,
            message: message || "Alert: #{name}",
            cooldown: cooldown,
            last_triggered: nil,
            enabled: true
          }

          @rules << rule
          rule
        end
      end

      # Remove a rule
      def remove_rule(rule_id)
        synchronize do
          @rules.reject! { |r| r[:id] == rule_id }
        end
      end

      # Enable/disable rule
      def toggle_rule(rule_id, enabled)
        synchronize do
          rule = @rules.find { |r| r[:id] == rule_id }
          rule[:enabled] = enabled if rule
        end
      end

      # Register alert handler
      def add_handler(&block)
        synchronize do
          @alert_handlers << block
        end
      end

      # Start monitoring
      def start_monitoring(interval: 60)
        synchronize do
          return if @monitoring_thread&.alive?

          @check_interval = interval
          @monitoring_thread = Thread.new do
            loop do
              check_rules
              sleep @check_interval
            rescue StandardError => e
              warn "Alert monitoring error: #{e.message}"
            end
          end
        end
      end

      # Stop monitoring
      def stop_monitoring
        synchronize do
          @monitoring_thread&.kill
          @monitoring_thread = nil
        end
      end

      # Manually check all rules
      def check_rules
        stats = @metrics_collector.statistics

        @rules.each do |rule|
          next unless rule[:enabled]
          next if in_cooldown?(rule)

          trigger_alert(rule, stats) if evaluate_condition(rule[:condition], stats)
        end
      end

      # Get active alerts
      def active_alerts
        synchronize do
          @alerts.select { |a| a[:status] == :active }
        end
      end

      # Get all alerts
      def all_alerts(limit: 100)
        synchronize do
          @alerts.last(limit)
        end
      end

      # Acknowledge alert
      def acknowledge_alert(alert_id, acknowledged_by: "system")
        synchronize do
          alert = @alerts.find { |a| a[:id] == alert_id }
          if alert
            alert[:status] = :acknowledged
            alert[:acknowledged_by] = acknowledged_by
            alert[:acknowledged_at] = Time.now.utc
          end
        end
      end

      # Resolve alert
      def resolve_alert(alert_id, resolved_by: "system")
        synchronize do
          alert = @alerts.find { |a| a[:id] == alert_id }
          if alert
            alert[:status] = :resolved
            alert[:resolved_by] = resolved_by
            alert[:resolved_at] = Time.now.utc
          end
        end
      end

      # Clear old alerts
      def clear_old_alerts(older_than: 86_400)
        synchronize do
          cutoff = Time.now.utc - older_than
          @alerts.reject! { |a| a[:triggered_at] < cutoff && a[:status] != :active }
        end
      end

      # Built-in alert conditions
      def self.high_error_rate(threshold: 0.1)
        lambda do |stats|
          total_ops = stats.dig(:performance, :total_operations) || 0
          return false if total_ops.zero?

          success_rate = stats.dig(:performance, :success_rate) || 1.0
          (1.0 - success_rate) > threshold
        end
      end

      def self.low_confidence(threshold: 0.5)
        lambda do |stats|
          avg_confidence = stats.dig(:decisions, :avg_confidence)
          avg_confidence && avg_confidence < threshold
        end
      end

      def self.high_latency(threshold_ms: 1000)
        lambda do |stats|
          p95 = stats.dig(:performance, :p95_duration_ms)
          p95 && p95 > threshold_ms
        end
      end

      def self.error_spike(threshold: 10, time_window: 300)
        lambda do |stats|
          recent_errors = stats.dig(:errors, :total) || 0
          recent_errors > threshold
        end
      end

      def self.decision_anomaly(expected_rate: 100, variance: 0.3)
        lambda do |stats|
          total = stats.dig(:decisions, :total) || 0
          time_range = stats.dig(:summary, :time_range)

          # Simple anomaly detection based on rate
          return false unless time_range

          lower_bound = expected_rate * (1 - variance)
          upper_bound = expected_rate * (1 + variance)

          total < lower_bound || total > upper_bound
        end
      end

      private

      def freeze_config
        # No immutable config to freeze yet
      end

      def generate_rule_id(name)
        synchronize do
          @rule_counter += 1
          "#{sanitize_name(name)}_#{Time.now.to_i}_#{@rule_counter}"
        end
      end

      def sanitize_name(name)
        name.to_s.downcase.gsub(/[^a-z0-9]/, "_")
      end

      def in_cooldown?(rule)
        return false unless rule[:last_triggered]

        Time.now.utc - rule[:last_triggered] < rule[:cooldown]
      end

      def evaluate_condition(condition, stats)
        case condition
        when Proc
          condition.call(stats)
        when Hash
          evaluate_hash_condition(condition, stats)
        else
          false
        end
      end

      def evaluate_hash_condition(condition, stats)
        # Support simple hash-based conditions
        # Example: { metric: "decisions.avg_confidence", op: "lt", value: 0.5 }
        metric_path = condition[:metric]&.split(".")
        return false unless metric_path

        value = stats.dig(*metric_path.map(&:to_sym))
        return false if value.nil?

        case condition[:op]
        when "gt", ">"
          value > condition[:value]
        when "lt", "<"
          value < condition[:value]
        when "eq", "=="
          value == condition[:value]
        when "gte", ">="
          value >= condition[:value]
        when "lte", "<="
          value <= condition[:value]
        else
          false
        end
      end

      def trigger_alert(rule, stats)
        alert = {
          id: "alert_#{Time.now.to_i}_#{rand(10_000)}",
          rule_id: rule[:id],
          rule_name: rule[:name],
          severity: rule[:severity],
          message: rule[:message],
          triggered_at: Time.now.utc,
          status: :active,
          context: {
            stats_snapshot: stats
          }
        }

        @alerts << alert
        rule[:last_triggered] = Time.now.utc

        # Notify handlers
        notify_handlers(alert)

        alert
      end

      def notify_handlers(alert)
        @alert_handlers.each do |handler|
          handler.call(alert)
        rescue StandardError => e
          warn "Alert handler failed: #{e.message}"
        end
      end
    end
  end
end
