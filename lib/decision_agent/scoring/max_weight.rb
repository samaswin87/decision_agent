module DecisionAgent
  module Scoring
    class MaxWeight < Base
      def score(evaluations)
        return { decision: nil, confidence: 0.0 } if evaluations.empty?

        max_eval = evaluations.max_by(&:weight)

        {
          decision: max_eval.decision,
          confidence: round_confidence(normalize_confidence(max_eval.weight))
        }
      end
    end
  end
end
