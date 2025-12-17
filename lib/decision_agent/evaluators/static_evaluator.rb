module DecisionAgent
  module Evaluators
    class StaticEvaluator < Base
      attr_reader :decision, :weight, :reason, :name

      def initialize(decision:, weight: 1.0, reason: "Static decision", name: nil)
        @decision = decision
        @weight = weight.to_f
        @reason = reason
        @name = name || evaluator_name
      end

      def evaluate(context, feedback: {})
        Evaluation.new(
          decision: @decision,
          weight: @weight,
          reason: @reason,
          evaluator_name: @name,
          metadata: { type: "static" }
        )
      end
    end
  end
end
