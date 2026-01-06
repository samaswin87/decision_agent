require_relative "errors"

module DecisionAgent
  module Simulation
    # Analyzer for quantifying rule change impact
    # rubocop:disable Metrics/ClassLength
    class ImpactAnalyzer
      attr_reader :version_manager

      def initialize(version_manager: nil)
        @version_manager = version_manager || Versioning::VersionManager.new
      end

      # Analyze impact of a proposed rule change
      # @param baseline_version [String, Integer, Hash] Baseline rule version
      # @param proposed_version [String, Integer, Hash] Proposed rule version
      # @param test_data [Array<Hash>] Test contexts to evaluate
      # @param options [Hash] Analysis options
      #   - :parallel [Boolean] Use parallel execution (default: true)
      #   - :thread_count [Integer] Number of threads (default: 4)
      #   - :calculate_risk [Boolean] Calculate risk score (default: true)
      # @return [Hash] Impact analysis report
      def analyze(baseline_version:, proposed_version:, test_data:, options: {})
        options = {
          parallel: true,
          thread_count: 4,
          calculate_risk: true
        }.merge(options)

        baseline_agent = build_agent_from_version(baseline_version)
        proposed_agent = build_agent_from_version(proposed_version)

        # Execute both versions on test data
        results = execute_comparison(test_data, baseline_agent, proposed_agent, options)

        # Build impact report
        build_impact_report(results, options)
      end

      # Calculate risk score for a rule change
      # @param results [Array<Hash>] Comparison results
      # @return [Float] Risk score between 0.0 (low risk) and 1.0 (high risk)
      def calculate_risk_score(results)
        return 0.0 if results.empty?

        total = results.size
        decision_changes = results.count { |r| r[:decision_changed] }
        large_confidence_shifts = results.count { |r| (r[:confidence_delta] || 0).abs > 0.2 }
        rejections_increased = count_rejection_increases(results)

        # Risk factors
        change_rate = decision_changes.to_f / total
        confidence_volatility = large_confidence_shifts.to_f / total
        rejection_risk = rejections_increased.to_f / total

        # Weighted risk score
        risk_score = (
          (change_rate * 0.4) +
          (confidence_volatility * 0.3) +
          (rejection_risk * 0.3)
        )

        [risk_score, 1.0].min # Cap at 1.0
      end

      private

      def build_agent_from_version(version)
        version_hash = resolve_version(version)
        evaluators = build_evaluators_from_version(version_hash)
        Agent.new(
          evaluators: evaluators,
          scoring_strategy: Scoring::WeightedAverage.new,
          audit_adapter: Audit::NullAdapter.new
        )
      end

      def resolve_version(version)
        case version
        when String, Integer
          version_data = @version_manager.get_version(version_id: version)
          raise VersionComparisonError, "Version not found: #{version}" unless version_data

          version_data
        when Hash
          version
        else
          raise VersionComparisonError, "Invalid version format: #{version.class}"
        end
      end

      def build_evaluators_from_version(version)
        content = version[:content] || version["content"]
        raise VersionComparisonError, "Version has no content" unless content

        if content.is_a?(Hash) && content[:evaluators]
          build_evaluators_from_config(content[:evaluators])
        elsif content.is_a?(Hash) && (content[:rules] || content["rules"])
          [Evaluators::JsonRuleEvaluator.new(rules_json: content)]
        else
          raise VersionComparisonError, "Cannot build evaluators from version content"
        end
      end

      def build_evaluators_from_config(configs)
        Array(configs).map do |config|
          case config[:type] || config["type"]
          when "json_rule"
            Evaluators::JsonRuleEvaluator.new(rules_json: config[:rules] || config["rules"])
          when "dmn"
            model = config[:model] || config["model"]
            decision_id = config[:decision_id] || config["decision_id"]
            Evaluators::DmnEvaluator.new(model: model, decision_id: decision_id)
          else
            raise VersionComparisonError, "Unknown evaluator type: #{config[:type]}"
          end
        end
      end

      def execute_comparison(test_data, baseline_agent, proposed_agent, options)
        results = []
        mutex = Mutex.new

        if options[:parallel] && test_data.size > 1
          execute_parallel(test_data, baseline_agent, proposed_agent, options, mutex) do |result|
            mutex.synchronize { results << result }
          end
        else
          test_data.each do |context|
            result = execute_single_comparison(context, baseline_agent, proposed_agent)
            results << result
          end
        end

        results
      end

      def execute_parallel(test_data, baseline_agent, proposed_agent, options, _mutex)
        thread_count = [options[:thread_count], test_data.size].min
        queue = Queue.new
        test_data.each { |c| queue << c }

        threads = Array.new(thread_count) do
          Thread.new do
            loop do
              context = begin
                queue.pop(true)
              rescue StandardError
                nil
              end
              break unless context

              result = execute_single_comparison(context, baseline_agent, proposed_agent)
              yield result
            end
          end
        end

        threads.each(&:join)
      end

      def execute_single_comparison(context, baseline_agent, proposed_agent)
        ctx = context.is_a?(Context) ? context : Context.new(context)

        baseline_metrics = measure_decision_metrics(ctx, baseline_agent, :baseline)
        proposed_metrics = measure_decision_metrics(ctx, proposed_agent, :proposed)
        delta_metrics = calculate_decision_delta(baseline_metrics, proposed_metrics)

        build_comparison_result(ctx, baseline_metrics, proposed_metrics, delta_metrics)
      end

      def measure_decision_metrics(context, agent, _label)
        start_time = Time.now
        begin
          decision = agent.decide(context: context)
          duration_ms = (Time.now - start_time) * 1000
          evaluations_count = decision.evaluations&.size || 0
          { decision: decision, duration_ms: duration_ms, evaluations_count: evaluations_count }
        rescue NoEvaluationsError
          duration_ms = (Time.now - start_time) * 1000
          { decision: nil, duration_ms: duration_ms, evaluations_count: 0 }
        end
      end

      def calculate_decision_delta(baseline_metrics, proposed_metrics)
        baseline_decision = baseline_metrics[:decision]
        proposed_decision = proposed_metrics[:decision]

        decision_changed, confidence_delta = if baseline_decision.nil? && proposed_decision.nil?
                                               [false, 0]
                                             elsif baseline_decision.nil?
                                               [true, proposed_decision.confidence]
                                             elsif proposed_decision.nil?
                                               [true, -baseline_decision.confidence]
                                             else
                                               [
                                                 baseline_decision.decision != proposed_decision.decision,
                                                 proposed_decision.confidence - baseline_decision.confidence
                                               ]
                                             end

        baseline_duration = baseline_metrics[:duration_ms]
        proposed_duration = proposed_metrics[:duration_ms]
        performance_delta_ms = proposed_duration - baseline_duration
        performance_delta_percent = baseline_duration.positive? ? (performance_delta_ms / baseline_duration * 100) : 0

        {
          decision_changed: decision_changed,
          confidence_delta: confidence_delta,
          performance_delta_ms: performance_delta_ms,
          performance_delta_percent: performance_delta_percent
        }
      end

      def build_comparison_result(context, baseline_metrics, proposed_metrics, delta_metrics)
        baseline_decision = baseline_metrics[:decision]
        proposed_decision = proposed_metrics[:decision]

        {
          context: context.to_h,
          baseline_decision: baseline_decision&.decision,
          baseline_confidence: baseline_decision&.confidence || 0,
          baseline_duration_ms: baseline_metrics[:duration_ms],
          baseline_evaluations_count: baseline_metrics[:evaluations_count],
          proposed_decision: proposed_decision&.decision,
          proposed_confidence: proposed_decision&.confidence || 0,
          proposed_duration_ms: proposed_metrics[:duration_ms],
          proposed_evaluations_count: proposed_metrics[:evaluations_count],
          decision_changed: delta_metrics[:decision_changed],
          confidence_delta: delta_metrics[:confidence_delta],
          confidence_shift_magnitude: delta_metrics[:confidence_delta].abs,
          performance_delta_ms: delta_metrics[:performance_delta_ms],
          performance_delta_percent: delta_metrics[:performance_delta_percent]
        }
      end

      def build_impact_report(results, options)
        report = build_base_report(results)
        report[:confidence_impact] = build_confidence_impact(results)
        report[:rule_execution_frequency] = build_rule_frequency(results)
        report[:performance_impact] = calculate_performance_impact(results)
        add_risk_analysis(report, results, options)
        report
      end

      def build_base_report(results)
        total = results.size
        decision_changes = results.count { |r| r[:decision_changed] }
        baseline_distribution = results.group_by { |r| r[:baseline_decision] }.transform_values(&:count)
        proposed_distribution = results.group_by { |r| r[:proposed_decision] }.transform_values(&:count)

        {
          total_contexts: total,
          decision_changes: decision_changes,
          change_rate: total.positive? ? (decision_changes.to_f / total) : 0,
          decision_distribution: {
            baseline: baseline_distribution,
            proposed: proposed_distribution
          },
          results: results
        }
      end

      def build_confidence_impact(results)
        confidence_deltas = results.map { |r| r[:confidence_delta] }.compact
        avg_confidence_delta = confidence_deltas.any? ? confidence_deltas.sum / confidence_deltas.size : 0
        max_confidence_shift = confidence_deltas.map(&:abs).max || 0

        {
          average_delta: avg_confidence_delta,
          max_shift: max_confidence_shift,
          positive_shifts: confidence_deltas.count(&:positive?),
          negative_shifts: confidence_deltas.count(&:negative?)
        }
      end

      def build_rule_frequency(results)
        {
          baseline: calculate_rule_frequency(results, :baseline_decision),
          proposed: calculate_rule_frequency(results, :proposed_decision)
        }
      end

      def add_risk_analysis(report, results, options)
        return unless options[:calculate_risk]

        report[:risk_score] = calculate_risk_score(results)
        report[:risk_level] = categorize_risk(report[:risk_score])
      end

      def calculate_rule_frequency(results, decision_key)
        # Approximate rule frequency from decision distribution
        # In a real implementation, this would track which rules fired
        results.group_by { |r| r[decision_key] }.transform_values { |v| v.size.to_f / results.size }
      end

      def count_rejection_increases(results)
        results.count do |r|
          baseline = r[:baseline_decision].to_s.downcase
          proposed = r[:proposed_decision].to_s.downcase
          (baseline.include?("approve") || baseline.include?("accept")) &&
            (proposed.include?("reject") || proposed.include?("deny"))
        end
      end

      def categorize_risk(risk_score)
        case risk_score
        when 0.0...0.2
          "low"
        when 0.2...0.5
          "medium"
        when 0.5...0.8
          "high"
        else
          "critical"
        end
      end

      # Calculate performance impact metrics
      # @param results [Array<Hash>] Comparison results with performance data
      # @return [Hash] Performance impact metrics
      def calculate_performance_impact(results)
        return {} if results.empty?

        metrics = extract_performance_metrics(results)
        latency_stats = calculate_latency_statistics(metrics)
        throughput_stats = calculate_throughput_statistics(latency_stats)
        complexity_stats = calculate_complexity_statistics(metrics)
        performance_deltas = calculate_performance_deltas(metrics, latency_stats, throughput_stats)

        build_performance_impact_hash(latency_stats, throughput_stats, complexity_stats, performance_deltas)
      end

      def extract_performance_metrics(results)
        {
          baseline_durations: results.map { |r| r[:baseline_duration_ms] }.compact,
          proposed_durations: results.map { |r| r[:proposed_duration_ms] }.compact,
          performance_deltas: results.map { |r| r[:performance_delta_ms] }.compact,
          performance_delta_percents: results.map { |r| r[:performance_delta_percent] }.compact,
          baseline_evaluations: results.map { |r| r[:baseline_evaluations_count] }.compact,
          proposed_evaluations: results.map { |r| r[:proposed_evaluations_count] }.compact
        }
      end

      def calculate_latency_statistics(metrics)
        baseline_durations = metrics[:baseline_durations]
        proposed_durations = metrics[:proposed_durations]

        {
          baseline_avg: calculate_average(baseline_durations),
          baseline_min: baseline_durations.min || 0,
          baseline_max: baseline_durations.max || 0,
          proposed_avg: calculate_average(proposed_durations),
          proposed_min: proposed_durations.min || 0,
          proposed_max: proposed_durations.max || 0
        }
      end

      def calculate_throughput_statistics(latency_stats)
        baseline_throughput = latency_stats[:baseline_avg].positive? ? (1000.0 / latency_stats[:baseline_avg]) : 0
        proposed_throughput = latency_stats[:proposed_avg].positive? ? (1000.0 / latency_stats[:proposed_avg]) : 0

        {
          baseline: baseline_throughput,
          proposed: proposed_throughput
        }
      end

      def calculate_complexity_statistics(metrics)
        baseline_avg = calculate_average(metrics[:baseline_evaluations], as_float: true)
        proposed_avg = calculate_average(metrics[:proposed_evaluations], as_float: true)

        {
          baseline_avg: baseline_avg,
          proposed_avg: proposed_avg,
          delta: proposed_avg - baseline_avg
        }
      end

      def calculate_performance_deltas(metrics, _latency_stats, throughput_stats)
        avg_delta_ms = calculate_average(metrics[:performance_deltas])
        avg_delta_percent = calculate_average(metrics[:performance_delta_percents])
        baseline_throughput = throughput_stats[:baseline]
        proposed_throughput = throughput_stats[:proposed]
        throughput_delta_percent = baseline_throughput.positive? ? ((proposed_throughput - baseline_throughput) / baseline_throughput * 100) : 0

        {
          avg_delta_ms: avg_delta_ms,
          avg_delta_percent: avg_delta_percent,
          throughput_delta_percent: throughput_delta_percent
        }
      end

      def calculate_average(values, as_float: false)
        return 0 if values.empty?

        sum = as_float ? values.sum.to_f : values.sum
        sum / values.size
      end

      def build_performance_impact_hash(latency_stats, throughput_stats, complexity_stats, performance_deltas)
        {
          latency: build_latency_impact(latency_stats, performance_deltas),
          throughput: build_throughput_impact(throughput_stats, performance_deltas),
          rule_complexity: build_complexity_impact(complexity_stats),
          impact_level: categorize_performance_impact(performance_deltas[:avg_delta_percent]),
          summary: build_performance_summary(
            performance_deltas[:avg_delta_percent],
            performance_deltas[:throughput_delta_percent],
            complexity_stats[:delta]
          )
        }
      end

      def build_latency_impact(latency_stats, performance_deltas)
        {
          baseline: {
            average_ms: latency_stats[:baseline_avg].round(4),
            min_ms: latency_stats[:baseline_min].round(4),
            max_ms: latency_stats[:baseline_max].round(4)
          },
          proposed: {
            average_ms: latency_stats[:proposed_avg].round(4),
            min_ms: latency_stats[:proposed_min].round(4),
            max_ms: latency_stats[:proposed_max].round(4)
          },
          delta_ms: performance_deltas[:avg_delta_ms].round(4),
          delta_percent: performance_deltas[:avg_delta_percent].round(2)
        }
      end

      def build_throughput_impact(throughput_stats, performance_deltas)
        {
          baseline_decisions_per_second: throughput_stats[:baseline].round(2),
          proposed_decisions_per_second: throughput_stats[:proposed].round(2),
          delta_percent: performance_deltas[:throughput_delta_percent].round(2)
        }
      end

      def build_complexity_impact(complexity_stats)
        {
          baseline_avg_evaluations: complexity_stats[:baseline_avg].round(2),
          proposed_avg_evaluations: complexity_stats[:proposed_avg].round(2),
          evaluations_delta: complexity_stats[:delta].round(2)
        }
      end

      # Categorize performance impact level
      # @param delta_percent [Float] Performance delta percentage
      # @return [String] Impact level: "improvement", "neutral", "minor_degradation", "moderate_degradation", "significant_degradation"
      def categorize_performance_impact(delta_percent)
        case delta_percent
        when -Float::INFINITY...-5.0
          "improvement"
        when -5.0...5.0
          "neutral"
        when 5.0...15.0
          "minor_degradation"
        when 15.0...30.0
          "moderate_degradation"
        else
          "significant_degradation"
        end
      end

      # Build human-readable performance summary
      # @param latency_delta_percent [Float] Latency delta percentage
      # @param throughput_delta_percent [Float] Throughput delta percentage
      # @param evaluations_delta [Float] Evaluations delta
      # @return [String] Summary text
      def build_performance_summary(latency_delta_percent, throughput_delta_percent, evaluations_delta)
        parts = []

        if latency_delta_percent.abs > 5.0
          direction = latency_delta_percent.positive? ? "slower" : "faster"
          parts << "Average latency is #{latency_delta_percent.abs.round(2)}% #{direction}"
        end

        if throughput_delta_percent.abs > 5.0
          direction = throughput_delta_percent.positive? ? "higher" : "lower"
          parts << "Throughput is #{throughput_delta_percent.abs.round(2)}% #{direction}"
        end

        if evaluations_delta.abs > 0.5
          direction = evaluations_delta.positive? ? "more" : "fewer"
          parts << "Average #{direction} #{evaluations_delta.abs.round(2)} rule evaluations per decision"
        end

        if parts.empty?
          "Performance impact is minimal (<5% change)"
        else
          "#{parts.join('. ')}."
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
