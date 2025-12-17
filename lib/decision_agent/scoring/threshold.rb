module DecisionAgent
  module Scoring
    class Threshold < Base
      attr_reader :threshold, :fallback_decision

      def initialize(threshold: 0.7, fallback_decision: "no_decision")
        @threshold = threshold.to_f
        @fallback_decision = fallback_decision
      end

      def score(evaluations)
        return { decision: @fallback_decision, confidence: 0.0 } if evaluations.empty?

        grouped = evaluations.group_by(&:decision)

        weighted_scores = grouped.map do |decision, evals|
          total_weight = evals.sum(&:weight)
          avg_weight = total_weight / evals.size
          [decision, avg_weight]
        end

        weighted_scores.sort_by! { |_, weight| -weight }

        winning_decision, winning_weight = weighted_scores.first

        if winning_weight >= @threshold
          {
            decision: winning_decision,
            confidence: round_confidence(normalize_confidence(winning_weight))
          }
        else
          {
            decision: @fallback_decision,
            confidence: round_confidence(normalize_confidence(winning_weight * 0.5))
          }
        end
      end
    end
  end
end
