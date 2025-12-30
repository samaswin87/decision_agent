require "monitor"
require "time"
require_relative "storage/memory_adapter"

begin
  require_relative "storage/activerecord_adapter"
rescue LoadError, NameError
  # ActiveRecord adapter not available
end

module DecisionAgent
  module Monitoring
    # Thread-safe metrics collector for decision analytics
    class MetricsCollector
      include MonitorMixin

      attr_reader :metrics, :window_size, :storage_adapter

      def initialize(window_size: 3600, storage: :auto, cleanup_threshold: 100)
        super()
        @window_size = window_size # Default: 1 hour window
        @cleanup_threshold = cleanup_threshold # Cleanup every N records
        @cleanup_counter = 0
        @storage_adapter = initialize_storage_adapter(storage, window_size)

        # Legacy in-memory metrics for backward compatibility with observers
        @metrics = {
          decisions: [],
          evaluations: [],
          performance: [],
          errors: []
        }
        @observers = []
        freeze_config
      end

      # Record a decision for analytics
      def record_decision(decision, context, duration_ms: nil)
        synchronize do
          metric = {
            timestamp: Time.now.utc,
            decision: decision.decision,
            confidence: decision.confidence,
            evaluations_count: decision.evaluations.size,
            context_size: context.to_h.size,
            duration_ms: duration_ms,
            evaluator_names: decision.evaluations.map(&:evaluator_name).uniq
          }

          # Store in-memory for observers (backward compatibility)
          @metrics[:decisions] << metric
          maybe_cleanup_old_metrics!

          # Persist to storage adapter
          @storage_adapter.record_decision(
            decision.decision,
            context.to_h,
            confidence: decision.confidence,
            evaluations_count: decision.evaluations.size,
            duration_ms: duration_ms,
            status: determine_decision_status(decision)
          )

          notify_observers(:decision, metric)
          metric
        end
      end

      # Record individual evaluation metrics
      def record_evaluation(evaluation)
        synchronize do
          metric = {
            timestamp: Time.now.utc,
            decision: evaluation.decision,
            weight: evaluation.weight,
            evaluator_name: evaluation.evaluator_name
          }

          # Store in-memory for observers (backward compatibility)
          @metrics[:evaluations] << metric
          maybe_cleanup_old_metrics!

          # Persist to storage adapter
          @storage_adapter.record_evaluation(
            evaluation.evaluator_name,
            score: evaluation.weight,
            success: evaluation.weight.positive?,
            details: { decision: evaluation.decision }
          )

          notify_observers(:evaluation, metric)
          metric
        end
      end

      # Record performance metrics
      def record_performance(operation:, duration_ms:, success: true, metadata: {})
        synchronize do
          metric = {
            timestamp: Time.now.utc,
            operation: operation,
            duration_ms: duration_ms,
            success: success,
            metadata: metadata
          }

          # Store in-memory for observers (backward compatibility)
          @metrics[:performance] << metric
          maybe_cleanup_old_metrics!

          # Persist to storage adapter
          @storage_adapter.record_performance(
            operation,
            duration_ms: duration_ms,
            status: success ? "success" : "failure",
            metadata: metadata
          )

          notify_observers(:performance, metric)
          metric
        end
      end

      # Record error
      def record_error(error, context: {})
        synchronize do
          metric = {
            timestamp: Time.now.utc,
            error_class: error.class.name,
            error_message: error.message,
            context: context
          }

          # Store in-memory for observers (backward compatibility)
          @metrics[:errors] << metric
          maybe_cleanup_old_metrics!

          # Persist to storage adapter
          @storage_adapter.record_error(
            error.class.name,
            message: error.message,
            stack_trace: error.backtrace,
            severity: determine_error_severity(error),
            context: context
          )

          notify_observers(:error, metric)
          metric
        end
      end

      # Get aggregated statistics
      def statistics(time_range: nil)
        synchronize do
          # Use in-memory metrics for MemoryAdapter (to maintain backward compatibility)
          # Only delegate to ActiveRecordAdapter for persistent storage
          use_storage = time_range &&
                        @storage_adapter.respond_to?(:statistics) &&
                        !@storage_adapter.is_a?(Storage::MemoryAdapter)

          if use_storage
            stats = @storage_adapter.statistics(time_range: time_range)
            return stats.merge(timestamp: Time.now.utc, storage: @storage_adapter.class.name) if stats
          end

          # Use in-memory metrics
          range_start = time_range ? Time.now.utc - time_range : nil

          decisions = filter_by_time(@metrics[:decisions], range_start)
          evaluations = filter_by_time(@metrics[:evaluations], range_start)
          performance = filter_by_time(@metrics[:performance], range_start)
          errors = filter_by_time(@metrics[:errors], range_start)

          {
            summary: {
              total_decisions: decisions.size,
              total_evaluations: evaluations.size,
              total_errors: errors.size,
              time_range: range_start ? "Last #{time_range}s" : "All time"
            },
            decisions: compute_decision_stats(decisions),
            evaluations: compute_evaluation_stats(evaluations),
            performance: compute_performance_stats(performance),
            errors: compute_error_stats(errors),
            timestamp: Time.now.utc,
            storage: "memory (fallback)"
          }
        end
      end

      # Get time-series data for graphing
      def time_series(metric_type:, bucket_size: 60, time_range: 3600)
        synchronize do
          # Use in-memory metrics for MemoryAdapter (to maintain backward compatibility)
          # Only delegate to ActiveRecordAdapter for persistent storage
          use_storage = @storage_adapter.respond_to?(:time_series) &&
                        !@storage_adapter.is_a?(Storage::MemoryAdapter)

          if use_storage
            series = @storage_adapter.time_series(metric_type, bucket_size: bucket_size, time_range: time_range)
            return series if series && series[:timestamps]
          end

          # Use in-memory metrics
          data = @metrics[metric_type] || []
          range_start = Time.now.utc - time_range

          buckets = {}
          data.each do |metric|
            next if metric[:timestamp] < range_start

            bucket_key = (metric[:timestamp].to_i / bucket_size) * bucket_size
            buckets[bucket_key] ||= []
            buckets[bucket_key] << metric
          end

          buckets.sort.map do |timestamp, metrics|
            {
              timestamp: Time.at(timestamp).utc,
              count: metrics.size,
              metrics: metrics
            }
          end
        end
      end

      # Register observer for real-time updates
      def add_observer(&block)
        synchronize do
          @observers << block
        end
      end

      # Clear all metrics
      def clear!
        synchronize do
          @metrics.each_value(&:clear)
          # Also clear storage adapter if using MemoryAdapter
          if @storage_adapter.is_a?(Storage::MemoryAdapter)
            # Clear all by using a very large time period (100 years in seconds)
            @storage_adapter.cleanup(older_than: 100 * 365 * 24 * 60 * 60)
          end
        end
      end

      # Get current metrics count
      def metrics_count
        synchronize do
          # Use in-memory metrics for MemoryAdapter (to maintain backward compatibility)
          # Only delegate to ActiveRecordAdapter for persistent storage
          use_storage = @storage_adapter.respond_to?(:metrics_count) &&
                        !@storage_adapter.is_a?(Storage::MemoryAdapter)

          return @storage_adapter.metrics_count if use_storage

          # Use in-memory
          @metrics.transform_values(&:size)
        end
      end

      # Cleanup old metrics from persistent storage
      def cleanup_old_metrics_from_storage(older_than:)
        synchronize do
          return 0 unless @storage_adapter.respond_to?(:cleanup)

          @storage_adapter.cleanup(older_than: older_than)
        end
      end

      private

      def freeze_config
        @window_size.freeze
      end

      def initialize_storage_adapter(storage_option, window_size)
        case storage_option
        when :auto
          # Auto-detect: prefer ActiveRecord if available
          if defined?(DecisionAgent::Monitoring::Storage::ActiveRecordAdapter) &&
             DecisionAgent::Monitoring::Storage::ActiveRecordAdapter.available?
            DecisionAgent::Monitoring::Storage::ActiveRecordAdapter.new
          else
            DecisionAgent::Monitoring::Storage::MemoryAdapter.new(window_size: window_size)
          end
        when :activerecord, :database
          unless defined?(DecisionAgent::Monitoring::Storage::ActiveRecordAdapter)
            raise "ActiveRecord adapter not available. Install models or use :memory storage."
          end

          DecisionAgent::Monitoring::Storage::ActiveRecordAdapter.new
        when :memory
          DecisionAgent::Monitoring::Storage::MemoryAdapter.new(window_size: window_size)
        when Symbol
          raise ArgumentError, "Unknown storage option: #{storage_option}. Use :auto, :activerecord, or :memory"
        else
          # Custom adapter instance provided
          storage_option
        end
      end

      def determine_decision_status(decision)
        return "success" if decision.confidence >= 0.7
        return "failure" if decision.confidence < 0.3

        "success" # Default for medium confidence
      end

      def determine_error_severity(error)
        case error
        when ArgumentError, TypeError
          "medium"
        when StandardError
          "low"
        when Exception
          "critical"
        else
          "low"
        end
      end

      # Conditionally cleanup old metrics based on counter
      # This reduces O(n) array scans from every record to every N records
      def maybe_cleanup_old_metrics!
        @cleanup_counter += 1
        return unless @cleanup_counter >= @cleanup_threshold

        @cleanup_counter = 0
        cleanup_old_metrics!
      end

      def cleanup_old_metrics!
        cutoff_time = Time.now.utc - @window_size

        @metrics.each_value do |data|
          data.delete_if { |m| m[:timestamp] < cutoff_time }
        end
      end

      def filter_by_time(data, start_time)
        return data unless start_time

        data.select { |m| m[:timestamp] >= start_time }
      end

      def compute_decision_stats(decisions)
        return {} if decisions.empty?

        confidences = decisions.map { |d| d[:confidence] }
        durations = decisions.map { |d| d[:duration_ms] }.compact

        decision_distribution = decisions.group_by { |d| d[:decision] }
                                         .transform_values(&:size)

        {
          total: decisions.size,
          avg_confidence: (confidences.sum / confidences.size.to_f).round(4),
          min_confidence: confidences.min.round(4),
          max_confidence: confidences.max.round(4),
          decision_distribution: decision_distribution,
          avg_duration_ms: durations.empty? ? nil : (durations.sum / durations.size.to_f).round(2),
          evaluators_used: decisions.flat_map { |d| d[:evaluator_names] }.uniq
        }
      end

      def compute_evaluation_stats(evaluations)
        return {} if evaluations.empty?

        weights = evaluations.map { |e| e[:weight] }
        evaluator_distribution = evaluations.group_by { |e| e[:evaluator_name] }
                                            .transform_values(&:size)

        {
          total: evaluations.size,
          avg_weight: (weights.sum / weights.size.to_f).round(4),
          evaluator_distribution: evaluator_distribution,
          decision_distribution: evaluations.group_by { |e| e[:decision] }
                                            .transform_values(&:size)
        }
      end

      def compute_performance_stats(performance)
        return {} if performance.empty?

        durations = performance.map { |p| p[:duration_ms] }
        successes = performance.count { |p| p[:success] }

        {
          total_operations: performance.size,
          successful: successes,
          failed: performance.size - successes,
          success_rate: (successes / performance.size.to_f).round(4),
          avg_duration_ms: (durations.sum / durations.size.to_f).round(2),
          min_duration_ms: durations.min.round(2),
          max_duration_ms: durations.max.round(2),
          p95_duration_ms: percentile(durations, 0.95).round(2),
          p99_duration_ms: percentile(durations, 0.99).round(2)
        }
      end

      def compute_error_stats(errors)
        return {} if errors.empty?

        {
          total: errors.size,
          by_type: errors.group_by { |e| e[:error_class] }.transform_values(&:size),
          recent_errors: errors.last(10).map do |e|
            {
              timestamp: e[:timestamp],
              error: e[:error_class],
              message: e[:error_message]
            }
          end
        }
      end

      def percentile(array, percentile)
        return 0 if array.empty?

        sorted = array.sort
        index = (percentile * sorted.length).ceil - 1
        sorted[[index, 0].max]
      end

      def notify_observers(event_type, metric)
        @observers.each do |observer|
          observer.call(event_type, metric)
        rescue StandardError => e
          # Silently fail observer notifications to prevent disruption
          warn "Observer notification failed: #{e.message}"
        end
      end
    end
  end
end
