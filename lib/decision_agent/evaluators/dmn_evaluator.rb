require_relative "../dmn/adapter"
require_relative "../dmn/errors"
require_relative "base"
require_relative "json_rule_evaluator"

module DecisionAgent
  module Evaluators
    # Evaluates DMN decision models
    class DmnEvaluator < Base
      attr_reader :model, :decision_id

      def initialize(model:, decision_id:, name: nil)
        @model = model
        @decision_id = decision_id.to_s
        @name = name || "DmnEvaluator(#{@decision_id})"

        # Find and validate decision
        @decision = @model.find_decision(@decision_id)
        raise Dmn::InvalidDmnModelError, "Decision '#{@decision_id}' not found" unless @decision
        unless @decision.decision_table
          raise Dmn::InvalidDmnModelError, "Decision '#{@decision_id}' has no decision table"
        end

        # Convert to JSON rules for execution
        adapter = Dmn::Adapter.new(@decision.decision_table)
        @rules_json = adapter.to_json_rules

        # Create internal JSON rule evaluator
        @json_evaluator = JsonRuleEvaluator.new(
          rules_json: @rules_json,
          name: @name
        )

        # Freeze for thread safety
        @model.freeze
        @decision_id.freeze
        @name.freeze
        freeze
      end

      def evaluate(context, feedback: {})
        # Delegate to JSON evaluator
        evaluation = @json_evaluator.evaluate(context, feedback: feedback)

        # Apply hit policy if multiple rules match
        # For Phase 2A, JsonRuleEvaluator already implements FIRST policy
        # Enhanced hit policy support in Phase 2B

        evaluation
      end

      private

      def evaluator_name
        @name
      end
    end
  end
end
