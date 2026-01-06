require_relative "errors"

module DecisionAgent
  module Simulation
    # Engine for shadow testing - comparing new rules against production without affecting outcomes
    class ShadowTestEngine
      attr_reader :production_agent, :version_manager

      def initialize(production_agent:, version_manager: nil)
        @production_agent = production_agent
        @version_manager = version_manager || Versioning::VersionManager.new
      end

      # Execute shadow test - compare shadow version against production
      # @param context [Hash, Context] Context for decision
      # @param shadow_version [String, Integer, Hash] Shadow rule version to test
      # @param options [Hash] Test options
      #   - :track_differences [Boolean] Track and return differences (default: true)
      #   - :record_results [Boolean] Record results for later analysis (default: false)
      # @return [Hash] Shadow test result
      def test(context:, shadow_version:, options: {})
        options = {
          track_differences: true,
          record_results: false
        }.merge(options)

        ctx = context.is_a?(Context) ? context : Context.new(context)

        # Execute production decision
        production_decision = @production_agent.decide(context: ctx)

        # Build shadow agent and execute
        shadow_agent = build_shadow_agent(shadow_version)
        shadow_decision = shadow_agent.decide(context: ctx)

        # Compare results
        result = {
          context: ctx.to_h,
          production_decision: production_decision.decision,
          production_confidence: production_decision.confidence,
          shadow_decision: shadow_decision.decision,
          shadow_confidence: shadow_decision.confidence,
          matches: production_decision.decision == shadow_decision.decision,
          confidence_delta: shadow_decision.confidence - production_decision.confidence,
          timestamp: Time.now.utc.iso8601
        }

        if options[:track_differences] && !result[:matches]
          result[:differences] = {
            decision_mismatch: true,
            production_explanations: production_decision.explanations,
            shadow_explanations: shadow_decision.explanations
          }
        end

        if options[:record_results]
          record_result(result, shadow_version)
        end

        result
      end

      # Batch shadow test multiple contexts
      # @param contexts [Array<Hash>] Array of contexts to test
      # @param shadow_version [String, Integer, Hash] Shadow rule version
      # @param options [Hash] Test options
      #   - :parallel [Boolean] Use parallel execution (default: true)
      #   - :thread_count [Integer] Number of threads (default: 4)
      #   - :progress_callback [Proc] Progress callback
      # @return [Hash] Batch shadow test results
      def batch_test(contexts:, shadow_version:, options: {})
        options = {
          parallel: true,
          thread_count: 4,
          progress_callback: nil,
          track_differences: true,
          record_results: false
        }.merge(options)

        shadow_agent = build_shadow_agent(shadow_version)
        results = []
        mutex = Mutex.new
        completed = 0
        total = contexts.size

        if options[:parallel] && contexts.size > 1
          execute_parallel(contexts, shadow_agent, options, mutex) do |result|
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
          contexts.each_with_index do |context, index|
            result = test(context: context, shadow_version: shadow_version, options: options)
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

      # Get shadow test summary statistics
      # @param shadow_version [String, Integer, Hash] Shadow version ID
      # @return [Hash] Summary statistics
      def get_summary(shadow_version)
        # In a real implementation, this would query stored results
        # For now, return empty summary
        {
          total_tests: 0,
          matches: 0,
          mismatches: 0,
          match_rate: 0.0,
          average_confidence_delta: 0.0
        }
      end

      private

      def build_shadow_agent(shadow_version)
        version_hash = resolve_version(shadow_version)
        evaluators = build_evaluators_from_version(version_hash)
        Agent.new(
          evaluators: evaluators,
          scoring_strategy: @production_agent.scoring_strategy,
          audit_adapter: Audit::NullAdapter.new
        )
      end

      def resolve_version(version)
        case version
        when String, Integer
          version_data = @version_manager.get_version(version_id: version)
          raise InvalidShadowTestError, "Shadow version not found: #{version}" unless version_data
          version_data
        when Hash
          version
        else
          raise InvalidShadowTestError, "Invalid shadow version format: #{version.class}"
        end
      end

      def build_evaluators_from_version(version)
        content = version[:content] || version["content"]
        raise InvalidShadowTestError, "Shadow version has no content" unless content

        if content.is_a?(Hash) && content[:evaluators]
          build_evaluators_from_config(content[:evaluators])
        elsif content.is_a?(Hash) && (content[:rules] || content["rules"])
          [Evaluators::JsonRuleEvaluator.new(rules_json: content)]
        else
          raise InvalidShadowTestError, "Cannot build evaluators from shadow version"
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
            raise InvalidShadowTestError, "Unknown evaluator type: #{config[:type]}"
          end
        end
      end

      def execute_parallel(contexts, shadow_agent, options, mutex)
        thread_count = [options[:thread_count], contexts.size].min
        queue = Queue.new
        contexts.each { |c| queue << c }

        threads = Array.new(thread_count) do
          Thread.new do
            loop do
              context = begin
                queue.pop(true)
              rescue StandardError
                nil
              end
              break unless context

              ctx = context.is_a?(Context) ? context : Context.new(context)
              production_decision = @production_agent.decide(context: ctx)
              shadow_decision = shadow_agent.decide(context: ctx)

              result = {
                context: ctx.to_h,
                production_decision: production_decision.decision,
                production_confidence: production_decision.confidence,
                shadow_decision: shadow_decision.decision,
                shadow_confidence: shadow_decision.confidence,
                matches: production_decision.decision == shadow_decision.decision,
                confidence_delta: shadow_decision.confidence - production_decision.confidence,
                timestamp: Time.now.utc.iso8601
              }

              if options[:track_differences] && !result[:matches]
                result[:differences] = {
                  decision_mismatch: true,
                  production_explanations: production_decision.explanations,
                  shadow_explanations: shadow_decision.explanations
                }
              end

              yield result
            end
          end
        end

        threads.each(&:join)
      end

      def record_result(result, shadow_version)
        # In a real implementation, this would store results in a database or file
        # For now, this is a placeholder
        version_id = shadow_version.is_a?(Hash) ? shadow_version[:id] || shadow_version["id"] : shadow_version
        # Store result for later analysis
      end

      def build_batch_report(results)
        total = results.size
        matches = results.count { |r| r[:matches] }
        mismatches = total - matches
        confidence_deltas = results.map { |r| r[:confidence_delta] }.compact

        {
          total_tests: total,
          matches: matches,
          mismatches: mismatches,
          match_rate: total > 0 ? (matches.to_f / total) : 0,
          average_confidence_delta: confidence_deltas.any? ? confidence_deltas.sum / confidence_deltas.size : 0,
          max_confidence_delta: confidence_deltas.map(&:abs).max || 0,
          decision_distribution: {
            production: results.group_by { |r| r[:production_decision] }.transform_values(&:count),
            shadow: results.group_by { |r| r[:shadow_decision] }.transform_values(&:count)
          },
          mismatched_results: results.select { |r| !r[:matches] },
          results: results
        }
      end
    end
  end
end

