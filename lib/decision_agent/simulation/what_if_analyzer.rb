require_relative "errors"

module DecisionAgent
  module Simulation
    # Analyzer for what-if scenario simulation
    class WhatIfAnalyzer
      attr_reader :agent, :version_manager

      def initialize(agent:, version_manager: nil)
        @agent = agent
        @version_manager = version_manager || Versioning::VersionManager.new
      end

      # Analyze multiple scenarios
      # @param scenarios [Array<Hash>] Array of context hashes to simulate
      # @param rule_version [String, Integer, Hash, nil] Optional rule version to use
      # @param options [Hash] Analysis options
      #   - :parallel [Boolean] Use parallel execution (default: true)
      #   - :thread_count [Integer] Number of threads (default: 4)
      #   - :sensitivity_analysis [Boolean] Perform sensitivity analysis (default: false)
      # @return [Hash] Analysis results with decision outcomes
      def analyze(scenarios:, rule_version: nil, options: {})
        options = {
          parallel: true,
          thread_count: 4,
          sensitivity_analysis: false
        }.merge(options)

        analysis_agent = build_agent_from_version(rule_version) if rule_version
        analysis_agent ||= @agent

        results = execute_scenarios(scenarios, analysis_agent, options)

        report = {
          scenarios: results,
          total_scenarios: scenarios.size,
          decision_distribution: results.group_by { |r| r[:decision] }.transform_values(&:count),
          average_confidence: calculate_average_confidence(results)
        }

        if options[:sensitivity_analysis]
          report[:sensitivity] = perform_sensitivity_analysis(scenarios, analysis_agent)
        end

        report
      end

      # Perform sensitivity analysis to identify which inputs affect decisions most
      # @param base_scenario [Hash] Base context to vary
      # @param variations [Hash] Hash of field => [values] to test
      # @param rule_version [String, Integer, Hash, nil] Optional rule version
      # @return [Hash] Sensitivity analysis results
      def sensitivity_analysis(base_scenario:, variations:, rule_version: nil)
        analysis_agent = build_agent_from_version(rule_version) if rule_version
        analysis_agent ||= @agent

        base_decision = analysis_agent.decide(context: Context.new(base_scenario))
        base_decision_value = base_decision.decision

        sensitivity_results = {}

        variations.each do |field, values|
          field_results = []
          values.each do |value|
            modified_scenario = base_scenario.dup
            set_nested_value(modified_scenario, field, value)
            decision = analysis_agent.decide(context: Context.new(modified_scenario))

            field_results << {
              value: value,
              decision: decision.decision,
              confidence: decision.confidence,
              changed: decision.decision != base_decision_value
            }
          end

          changed_count = field_results.count { |r| r[:changed] }
          sensitivity_results[field] = {
            impact: changed_count.to_f / values.size,
            results: field_results,
            base_decision: base_decision_value
          }
        end

        {
          base_scenario: base_scenario,
          base_decision: base_decision_value,
          base_confidence: base_decision.confidence,
          field_sensitivity: sensitivity_results,
          most_sensitive_fields: sensitivity_results.sort_by { |_k, v| -v[:impact] }.to_h.keys
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

      def execute_scenarios(scenarios, analysis_agent, options)
        results = []
        mutex = Mutex.new

        if options[:parallel] && scenarios.size > 1
          execute_parallel(scenarios, analysis_agent, options, mutex) do |result|
            mutex.synchronize { results << result }
          end
        else
          scenarios.each do |scenario|
            ctx = scenario.is_a?(Context) ? scenario : Context.new(scenario)
            decision = analysis_agent.decide(context: ctx)
            results << {
              scenario: ctx.to_h,
              decision: decision.decision,
              confidence: decision.confidence,
              explanations: decision.explanations
            }
          end
        end

        results
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

              ctx = scenario.is_a?(Context) ? scenario : Context.new(scenario)
              decision = analysis_agent.decide(context: ctx)
              result = {
                scenario: ctx.to_h,
                decision: decision.decision,
                confidence: decision.confidence,
                explanations: decision.explanations
              }
              yield result
            end
          end
        end

        threads.each(&:join)
      end

      def calculate_average_confidence(results)
        confidences = results.map { |r| r[:confidence] }.compact
        confidences.any? ? confidences.sum / confidences.size : 0
      end

      def perform_sensitivity_analysis(scenarios, analysis_agent)
        # Identify numeric fields that vary across scenarios
        numeric_fields = identify_numeric_fields(scenarios)
        return {} if numeric_fields.empty?

        sensitivity = {}
        numeric_fields.each do |field|
          values = scenarios.map { |s| get_nested_value(s, field) }.compact.uniq
          next if values.size < 2

          # Test impact of varying this field
          base_scenario = scenarios.first.dup
          field_sensitivity = test_field_impact(base_scenario, field, values, analysis_agent)
          sensitivity[field] = field_sensitivity if field_sensitivity
        end

        sensitivity
      end

      def identify_numeric_fields(scenarios)
        return [] if scenarios.empty?

        all_keys = scenarios.flat_map { |s| extract_keys(s) }.uniq
        numeric_keys = []

        all_keys.each do |key|
          values = scenarios.map { |s| get_nested_value(s, key) }.compact
          if values.all? { |v| v.is_a?(Numeric) }
            numeric_keys << key
          end
        end

        numeric_keys
      end

      def extract_keys(hash, prefix = nil)
        keys = []
        hash.each do |k, v|
          full_key = prefix ? "#{prefix}.#{k}" : k.to_s
          if v.is_a?(Hash)
            keys.concat(extract_keys(v, full_key))
          else
            keys << full_key
          end
        end
        keys
      end

      def test_field_impact(base_scenario, field, values, analysis_agent)
        base_decision = analysis_agent.decide(context: Context.new(base_scenario))
        base_decision_value = base_decision.decision

        changed_count = 0
        values.each do |value|
          modified = base_scenario.dup
          set_nested_value(modified, field, value)
          decision = analysis_agent.decide(context: Context.new(modified))
          changed_count += 1 if decision.decision != base_decision_value
        end

        {
          impact: changed_count.to_f / values.size,
          values_tested: values.size,
          decisions_changed: changed_count
        }
      end

      def get_nested_value(hash, key)
        keys = key.to_s.split(".")
        keys.reduce(hash) do |h, k|
          return nil unless h.is_a?(Hash)
          h[k.to_sym] || h[k.to_s]
        end
      end

      def set_nested_value(hash, key, value)
        keys = key.to_s.split(".")
        last_key = keys.pop
        target = keys.reduce(hash) do |h, k|
          h[k.to_sym] ||= {}
          h[k.to_sym]
        end
        target[last_key.to_sym] = value
      end
    end
  end
end

