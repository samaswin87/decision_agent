require_relative "errors"

module DecisionAgent
  module Simulation
    # Analyzer for quantifying rule change impact
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
        report = build_impact_report(results, options)

        report
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
          change_rate * 0.4 +
          confidence_volatility * 0.3 +
          rejection_risk * 0.3
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

      def execute_parallel(test_data, baseline_agent, proposed_agent, options, mutex)
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

        baseline_decision = baseline_agent.decide(context: ctx)
        proposed_decision = proposed_agent.decide(context: ctx)

        decision_changed = baseline_decision.decision != proposed_decision.decision
        confidence_delta = proposed_decision.confidence - baseline_decision.confidence

        {
          context: ctx.to_h,
          baseline_decision: baseline_decision.decision,
          baseline_confidence: baseline_decision.confidence,
          proposed_decision: proposed_decision.decision,
          proposed_confidence: proposed_decision.confidence,
          decision_changed: decision_changed,
          confidence_delta: confidence_delta,
          confidence_shift_magnitude: confidence_delta.abs
        }
      end

      def build_impact_report(results, options)
        total = results.size
        decision_changes = results.count { |r| r[:decision_changed] }
        confidence_deltas = results.map { |r| r[:confidence_delta] }.compact

        # Decision distribution changes
        baseline_distribution = results.group_by { |r| r[:baseline_decision] }.transform_values(&:count)
        proposed_distribution = results.group_by { |r| r[:proposed_decision] }.transform_values(&:count)

        # Confidence statistics
        avg_confidence_delta = confidence_deltas.any? ? confidence_deltas.sum / confidence_deltas.size : 0
        max_confidence_shift = confidence_deltas.map(&:abs).max || 0

        # Rule execution frequency (approximate from decision distribution)
        baseline_frequency = calculate_rule_frequency(results, :baseline_decision)
        proposed_frequency = calculate_rule_frequency(results, :proposed_decision)

        report = {
          total_contexts: total,
          decision_changes: decision_changes,
          change_rate: total > 0 ? (decision_changes.to_f / total) : 0,
          decision_distribution: {
            baseline: baseline_distribution,
            proposed: proposed_distribution
          },
          confidence_impact: {
            average_delta: avg_confidence_delta,
            max_shift: max_confidence_shift,
            positive_shifts: confidence_deltas.count { |d| d > 0 },
            negative_shifts: confidence_deltas.count { |d| d < 0 }
          },
          rule_execution_frequency: {
            baseline: baseline_frequency,
            proposed: proposed_frequency
          },
          results: results
        }

        if options[:calculate_risk]
          report[:risk_score] = calculate_risk_score(results)
          report[:risk_level] = categorize_risk(report[:risk_score])
        end

        report
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
    end
  end
end

