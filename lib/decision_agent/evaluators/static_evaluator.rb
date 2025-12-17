module DecisionAgent
  module Evaluators
    class StaticEvaluator < Base
      attr_reader :decision, :weight, :reason, :name, :custom_metadata

      def initialize(decision:, weight: 1.0, reason: "Static decision", name: nil, metadata: nil)
        @decision = decision
        @weight = weight.to_f
        @reason = reason
        @name = name || evaluator_name
        @custom_metadata = metadata
      end

      def evaluate(context, feedback: {})
        metadata = if @custom_metadata
          @custom_metadata
        else
          { type: "static" }
        end

        Evaluation.new(
          decision: @decision,
          weight: @weight,
          reason: @reason,
          evaluator_name: @name,
          metadata: metadata
        )
      end
    end
  end
end
