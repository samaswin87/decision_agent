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
      end

      def evaluate(context, feedback: {})
        ctx = context.is_a?(Context) ? context : Context.new(context)

        matched_rule = find_first_matching_rule(ctx)

        return nil unless matched_rule

        then_clause = matched_rule["then"]

        Evaluation.new(
          decision: then_clause["decision"],
          weight: then_clause["weight"] || 1.0,
          reason: then_clause["reason"] || "Rule matched",
          evaluator_name: @name,
          metadata: {
            type: "json_rule",
            rule_id: matched_rule["id"],
            ruleset: @ruleset_name
          }
        )
      end

      private

      def find_first_matching_rule(context)
        rules = @ruleset["rules"] || []

        rules.find do |rule|
          if_clause = rule["if"]
          next false unless if_clause

          Dsl::ConditionEvaluator.evaluate(if_clause, context)
        end
      end
    end
  end
end
