require "monitor"

module DecisionAgent
  module Monitoring
    # Prometheus-compatible metrics exporter
    class PrometheusExporter
      include MonitorMixin

      CONTENT_TYPE = "text/plain; version=0.0.4"

      def initialize(metrics_collector:, namespace: "decision_agent")
        super()
        @metrics_collector = metrics_collector
        @namespace = namespace
        @custom_metrics = {}
        freeze_config
      end

      # Export metrics in Prometheus format
      def export
        synchronize do
          lines = []

          # Add header
          lines << "# DecisionAgent Metrics Export"
          lines << "# Timestamp: #{Time.now.utc.iso8601}"
          lines << ""

          # Decision metrics
          lines.concat(export_decision_metrics)

          # Performance metrics
          lines.concat(export_performance_metrics)

          # Error metrics
          lines.concat(export_error_metrics)

          # Custom KPI metrics
          lines.concat(export_custom_metrics)

          # System info
          lines.concat(export_system_metrics)

          lines.join("\n")
        end
      end

      # Register custom KPI
      def register_kpi(name:, value:, labels: {}, help: nil)
        synchronize do
          metric_name = sanitize_name(name)
          @custom_metrics[metric_name] = {
            value: value,
            labels: labels,
            help: help || "Custom KPI: #{name}",
            timestamp: Time.now.utc
          }
        end
      end

      # Get metrics in hash format
      def metrics_hash
        synchronize do
          stats = @metrics_collector.statistics

          {
            decisions: {
              total: counter_metric("decisions_total", stats.dig(:decisions, :total) || 0),
              avg_confidence: gauge_metric("decision_confidence_avg", stats.dig(:decisions, :avg_confidence) || 0),
              avg_duration_ms: gauge_metric("decision_duration_ms_avg", stats.dig(:decisions, :avg_duration_ms) || 0)
            },
            performance: {
              success_rate: gauge_metric("success_rate", stats.dig(:performance, :success_rate) || 0),
              avg_duration_ms: gauge_metric("operation_duration_ms_avg", stats.dig(:performance, :avg_duration_ms) || 0),
              p95_duration_ms: gauge_metric("operation_duration_ms_p95", stats.dig(:performance, :p95_duration_ms) || 0),
              p99_duration_ms: gauge_metric("operation_duration_ms_p99", stats.dig(:performance, :p99_duration_ms) || 0)
            },
            errors: {
              total: counter_metric("errors_total", stats.dig(:errors, :total) || 0)
            },
            system: {
              version: info_metric("version", DecisionAgent::VERSION)
            }
          }
        end
      end

      private

      def freeze_config
        @namespace.freeze
      end

      def export_decision_metrics
        stats = @metrics_collector.statistics
        lines = []

        # Total decisions
        lines << "# HELP #{metric_name('decisions_total')} Total number of decisions made"
        lines << "# TYPE #{metric_name('decisions_total')} counter"
        lines << "#{metric_name('decisions_total')} #{stats.dig(:decisions, :total) || 0}"
        lines << ""

        # Average confidence
        lines << "# HELP #{metric_name('decision_confidence_avg')} Average decision confidence"
        lines << "# TYPE #{metric_name('decision_confidence_avg')} gauge"
        lines << "#{metric_name('decision_confidence_avg')} #{stats.dig(:decisions, :avg_confidence) || 0}"
        lines << ""

        # Decision distribution
        if stats.dig(:decisions, :decision_distribution)
          lines << "# HELP #{metric_name('decisions_by_type')} Decisions grouped by type"
          lines << "# TYPE #{metric_name('decisions_by_type')} counter"
          stats[:decisions][:decision_distribution].each do |decision, count|
            lines << "#{metric_name('decisions_by_type')}{decision=\"#{decision}\"} #{count}"
          end
          lines << ""
        end

        # Average duration
        if stats.dig(:decisions, :avg_duration_ms)
          lines << "# HELP #{metric_name('decision_duration_ms_avg')} Average decision duration in milliseconds"
          lines << "# TYPE #{metric_name('decision_duration_ms_avg')} gauge"
          lines << "#{metric_name('decision_duration_ms_avg')} #{stats[:decisions][:avg_duration_ms]}"
          lines << ""
        end

        lines
      end

      def export_performance_metrics
        stats = @metrics_collector.statistics
        lines = []

        # Success rate
        lines << "# HELP #{metric_name('success_rate')} Operation success rate (0-1)"
        lines << "# TYPE #{metric_name('success_rate')} gauge"
        lines << "#{metric_name('success_rate')} #{stats.dig(:performance, :success_rate) || 0}"
        lines << ""

        # Duration metrics
        if stats.dig(:performance, :avg_duration_ms)
          lines << "# HELP #{metric_name('operation_duration_ms')} Operation duration in milliseconds"
          lines << "# TYPE #{metric_name('operation_duration_ms')} summary"
          lines << "#{metric_name('operation_duration_ms')}{quantile=\"0.5\"} #{stats[:performance][:avg_duration_ms]}"
          lines << "#{metric_name('operation_duration_ms')}{quantile=\"0.95\"} #{stats[:performance][:p95_duration_ms]}"
          lines << "#{metric_name('operation_duration_ms')}{quantile=\"0.99\"} #{stats[:performance][:p99_duration_ms]}"
          lines << "#{metric_name('operation_duration_ms_sum')} #{stats[:performance][:avg_duration_ms] * stats[:performance][:total_operations]}"
          lines << "#{metric_name('operation_duration_ms_count')} #{stats[:performance][:total_operations]}"
          lines << ""
        end

        lines
      end

      def export_error_metrics
        stats = @metrics_collector.statistics
        lines = []

        # Total errors
        lines << "# HELP #{metric_name('errors_total')} Total number of errors"
        lines << "# TYPE #{metric_name('errors_total')} counter"
        lines << "#{metric_name('errors_total')} #{stats.dig(:errors, :total) || 0}"
        lines << ""

        # Errors by type
        if stats.dig(:errors, :by_type)
          lines << "# HELP #{metric_name('errors_by_type')} Errors grouped by type"
          lines << "# TYPE #{metric_name('errors_by_type')} counter"
          stats[:errors][:by_type].each do |error_type, count|
            lines << "#{metric_name('errors_by_type')}{error=\"#{sanitize_label(error_type)}\"} #{count}"
          end
          lines << ""
        end

        lines
      end

      def export_custom_metrics
        lines = []

        @custom_metrics.each do |name, metric|
          full_name = metric_name(name)
          lines << "# HELP #{full_name} #{metric[:help]}"
          lines << "# TYPE #{full_name} gauge"

          if metric[:labels].empty?
            lines << "#{full_name} #{metric[:value]}"
          else
            label_str = metric[:labels].map { |k, v| "#{k}=\"#{sanitize_label(v)}\"" }.join(",")
            lines << "#{full_name}{#{label_str}} #{metric[:value]}"
          end
          lines << ""
        end

        lines
      end

      def export_system_metrics
        lines = []

        # Version info
        lines << "# HELP #{metric_name('info')} DecisionAgent version info"
        lines << "# TYPE #{metric_name('info')} gauge"
        lines << "#{metric_name('info')}{version=\"#{DecisionAgent::VERSION}\"} 1"
        lines << ""

        # Metrics count
        counts = @metrics_collector.metrics_count
        lines << "# HELP #{metric_name('metrics_stored')} Number of metrics stored in memory"
        lines << "# TYPE #{metric_name('metrics_stored')} gauge"
        counts.each do |type, count|
          lines << "#{metric_name('metrics_stored')}{type=\"#{type}\"} #{count}"
        end
        lines << ""

        lines
      end

      def metric_name(name)
        "#{@namespace}_#{sanitize_name(name)}"
      end

      def sanitize_name(name)
        name.to_s.gsub(/[^a-zA-Z0-9_]/, "_")
      end

      def sanitize_label(value)
        value.to_s.gsub(/"/, '\\"')
      end

      def counter_metric(name, value)
        { name: name, type: "counter", value: value }
      end

      def gauge_metric(name, value)
        { name: name, type: "gauge", value: value }
      end

      def info_metric(name, value)
        { name: name, type: "info", value: value }
      end
    end
  end
end
