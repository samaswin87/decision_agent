require_relative "errors"

module DecisionAgent
  module Simulation
    # Engine for managing and executing test scenarios
    class ScenarioEngine
      attr_reader :agent, :version_manager

      def initialize(agent:, version_manager: nil)
        @agent = agent
        @version_manager = version_manager || Versioning::VersionManager.new
      end

      # Execute a single scenario
      # @param scenario [Hash] Scenario definition with context and optional metadata
      # @param rule_version [String, Integer, Hash, nil] Optional rule version to use
      # @return [Hash] Scenario execution result
      def execute(scenario:, rule_version: nil)
        context = scenario[:context] || scenario["context"] || scenario
        metadata = scenario[:metadata] || scenario["metadata"] || {}

        analysis_agent = build_agent_from_version(rule_version) if rule_version
        analysis_agent ||= @agent

        ctx = context.is_a?(Context) ? context : Context.new(context)
        decision = analysis_agent.decide(context: ctx)

        {
          scenario_id: scenario[:id] || scenario["id"] || generate_scenario_id,
          context: ctx.to_h,
          decision: decision.decision,
          confidence: decision.confidence,
          explanations: decision.explanations,
          metadata: metadata,
          executed_at: Time.now.utc.iso8601
        }
      end

      # Execute multiple scenarios
      # @param scenarios [Array<Hash>] Array of scenario definitions
      # @param rule_version [String, Integer, Hash, nil] Optional rule version
      # @param options [Hash] Execution options
      #   - :parallel [Boolean] Use parallel execution (default: true)
      #   - :thread_count [Integer] Number of threads (default: 4)
      #   - :progress_callback [Proc] Progress callback
      # @return [Hash] Batch execution results
      def execute_batch(scenarios:, rule_version: nil, options: {})
        options = {
          parallel: true,
          thread_count: 4,
          progress_callback: nil
        }.merge(options)

        analysis_agent = build_agent_from_version(rule_version) if rule_version
        analysis_agent ||= @agent

        results = []
        mutex = Mutex.new
        completed = 0
        total = scenarios.size

        if options[:parallel] && scenarios.size > 1
          execute_parallel(scenarios, analysis_agent, options, mutex) do |result|
            mutex.synchronize do
              results << result
              completed += 1
              options[:progress_callback]&.call(
                completed: completed,
                total: total,
                percentage: (completed.to_f / total * 100).round(2)
              )
            end
          end
        else
          scenarios.each_with_index do |scenario, index|
            result = execute(scenario: scenario, rule_version: rule_version)
            results << result
            completed = index + 1
            options[:progress_callback]&.call(
              completed: completed,
              total: total,
              percentage: (completed.to_f / total * 100).round(2)
            )
          end
        end

        build_batch_report(results)
      end

      # Compare scenarios across different rule versions
      # @param scenarios [Array<Hash>] Scenarios to test
      # @param versions [Array<String, Integer, Hash>] Rule versions to compare
      # @param options [Hash] Execution options
      # @return [Hash] Comparison results
      def compare_versions(scenarios:, versions:, options: {})
        options = {
          parallel: true,
          thread_count: 4
        }.merge(options)

        version_results = {}
        versions.each do |version|
          results = execute_batch(scenarios: scenarios, rule_version: version, options: options)
          version_id = version.is_a?(Hash) ? (version[:id] || version["id"]) : version
          version_results[version_id.to_s] = results
        end

        {
          scenarios: scenarios,
          versions: versions.map { |v| v.is_a?(Hash) ? (v[:id] || v["id"]) : v },
          results_by_version: version_results,
          comparison: build_version_comparison(version_results)
        }
      end

      private

      def build_agent_from_version(version)
        version_hash = resolve_version(version)
        evaluators = build_evaluators_from_version(version_hash)
        Agent.new(
          evaluators: evaluators,
          scoring_strategy: @agent.scoring_strategy,
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
        return @agent.evaluators unless content

        if content.is_a?(Hash) && content[:evaluators]
          build_evaluators_from_config(content[:evaluators])
        elsif content.is_a?(Hash) && (content[:rules] || content["rules"])
          [Evaluators::JsonRuleEvaluator.new(rules_json: content)]
        else
          @agent.evaluators
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

      def execute_parallel(scenarios, analysis_agent, options, mutex)
        thread_count = [options[:thread_count], scenarios.size].min
        queue = Queue.new
        scenarios.each { |s| queue << s }

        threads = Array.new(thread_count) do
          Thread.new do
            loop do
              scenario = begin
                queue.pop(true)
              rescue StandardError
                nil
              end
              break unless scenario

              context = scenario[:context] || scenario["context"] || scenario
              metadata = scenario[:metadata] || scenario["metadata"] || {}
              ctx = context.is_a?(Context) ? context : Context.new(context)
              decision = analysis_agent.decide(context: ctx)

              result = {
                scenario_id: scenario[:id] || scenario["id"] || generate_scenario_id,
                context: ctx.to_h,
                decision: decision.decision,
                confidence: decision.confidence,
                explanations: decision.explanations,
                metadata: metadata,
                executed_at: Time.now.utc.iso8601
              }

              yield result
            end
          end
        end

        threads.each(&:join)
      end

      def build_batch_report(results)
        {
          total_scenarios: results.size,
          decision_distribution: results.group_by { |r| r[:decision] }.transform_values(&:count),
          average_confidence: calculate_average_confidence(results),
          min_confidence: results.map { |r| r[:confidence] }.min || 0,
          max_confidence: results.map { |r| r[:confidence] }.max || 0,
          results: results
        }
      end

      def build_version_comparison(version_results)
        comparison = {}
        version_ids = version_results.keys

        # Compare decision distributions
        decision_comparison = {}
        version_ids.each do |version_id|
          results = version_results[version_id][:results] || []
          decision_comparison[version_id] = results.group_by { |r| r[:decision] }.transform_values(&:count)
        end

        comparison[:decision_distributions] = decision_comparison

        # Compare average confidence
        confidence_comparison = {}
        version_ids.each do |version_id|
          results = version_results[version_id][:results] || []
          confidences = results.map { |r| r[:confidence] }.compact
          confidence_comparison[version_id] = confidences.any? ? confidences.sum / confidences.size : 0
        end

        comparison[:average_confidence] = confidence_comparison

        comparison
      end

      def calculate_average_confidence(results)
        confidences = results.map { |r| r[:confidence] }.compact
        confidences.any? ? confidences.sum / confidences.size : 0
      end

      def generate_scenario_id
        "scenario_#{Time.now.to_f}_#{rand(1000)}"
      end
    end
  end
end

