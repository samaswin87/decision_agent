require "json"

module DecisionAgent
  module Evaluators
    class JsonRuleEvaluator < Base
      attr_reader :ruleset_name

      def initialize(rules_json:, name: nil)
        @rules_json = rules_json.is_a?(String) ? rules_json : JSON.generate(rules_json)
        @ruleset = Dsl::RuleParser.parse(@rules_json)
        @ruleset_name = @ruleset["ruleset"] || "unknown"
        @name = name || "JsonRuleEvaluator(#{@ruleset_name})"

        # Freeze ruleset to ensure thread-safety
        deep_freeze(@ruleset)
        @rules_json.freeze
        @ruleset_name.freeze
        @name.freeze
      end

      def evaluate(context, feedback: {})
        ctx = context.is_a?(DecisionAgent::Context) ? context : DecisionAgent::Context.new(context)

        # Collect explainability traces (this also finds the matching rule)
        explainability_result = collect_explainability(ctx)

        # Find the matched rule from explainability result
        matched_rule_trace = explainability_result&.matched_rules&.first
        return nil unless matched_rule_trace

        # Find the original rule to get the then clause
        rules = @ruleset["rules"] || []
        matched_rule = rules.find { |r| (r["id"] || "rule_#{rules.index(r)}") == matched_rule_trace.rule_id }
        return nil unless matched_rule

        then_clause = matched_rule["then"]

        metadata = {
          type: "json_rule",
          rule_id: matched_rule["id"],
          ruleset: @ruleset_name
        }

        # Add explainability data to metadata
        metadata[:explainability] = explainability_result.to_h if explainability_result

        Evaluation.new(
          decision: then_clause["decision"],
          weight: then_clause["weight"] || 1.0,
          reason: then_clause["reason"] || "Rule matched",
          evaluator_name: @name,
          metadata: metadata
        )
      end

      private

      def collect_explainability(context)
        rules = @ruleset["rules"] || []
        rule_traces = []

        rules.each do |rule|
          rule_id = rule["id"] || "rule_#{rules.index(rule)}"
          if_clause = rule["if"]
          next unless if_clause

          # Create trace collector for this rule
          trace_collector = Explainability::TraceCollector.new

          # Evaluate condition with tracing
          matched = Dsl::ConditionEvaluator.evaluate(
            if_clause,
            context,
            trace_collector: trace_collector
          )

          then_clause = rule["then"] || {}
          rule_trace = Explainability::RuleTrace.new(
            rule_id: rule_id,
            matched: matched,
            condition_traces: trace_collector.traces,
            decision: then_clause["decision"],
            weight: then_clause["weight"],
            reason: then_clause["reason"]
          )

          rule_traces << rule_trace

          # Stop after first match (short-circuit evaluation)
          break if matched
        end

        Explainability::ExplainabilityResult.new(
          evaluator_name: @name,
          rule_traces: rule_traces
        )
      end

      def find_first_matching_rule(context, explainability_result = nil)
        rules = @ruleset["rules"] || []

        rules.find do |rule|
          if_clause = rule["if"]
          next false unless if_clause

          # If explainability is already collected, use the trace data
          if explainability_result
            rule_trace = explainability_result.rule_traces.find { |rt| rt.rule_id == (rule["id"] || "rule_#{rules.index(rule)}") }
            rule_trace&.matched
          else
            Dsl::ConditionEvaluator.evaluate(if_clause, context)
          end
        end
      end

      # Deep freeze helper method
      def deep_freeze(obj)
        case obj
        when Hash
          obj.each do |k, v|
            deep_freeze(k)
            deep_freeze(v)
          end
          obj.freeze
        when Array
          obj.each { |item| deep_freeze(item) }
          obj.freeze
        when String, Symbol, Numeric, TrueClass, FalseClass, NilClass
          obj.freeze
        else
          obj.freeze if obj.respond_to?(:freeze)
        end
        obj
      end
    end
  end
end
