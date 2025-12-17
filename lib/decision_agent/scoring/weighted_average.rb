module DecisionAgent
  module Scoring
    class WeightedAverage < Base
      def score(evaluations)
        return { decision: nil, confidence: 0.0 } if evaluations.empty?

        grouped = evaluations.group_by(&:decision)

        weighted_scores = grouped.map do |decision, evals|
          total_weight = evals.sum(&:weight)
          [decision, total_weight]
        end

        winning_decision, winning_weight = weighted_scores.max_by { |_, weight| weight }

        total_weight = evaluations.sum(&:weight)
        confidence = total_weight > 0 ? winning_weight / total_weight : 0.0

        {
          decision: winning_decision,
          confidence: round_confidence(normalize_confidence(confidence))
        }
      end
    end
  end
end
