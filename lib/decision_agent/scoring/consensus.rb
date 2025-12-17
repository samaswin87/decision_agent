module DecisionAgent
  module Scoring
    class Consensus < Base
      attr_reader :minimum_agreement

      def initialize(minimum_agreement: 0.5)
        @minimum_agreement = minimum_agreement.to_f
      end

      def score(evaluations)
        return { decision: nil, confidence: 0.0 } if evaluations.empty?

        grouped = evaluations.group_by(&:decision)
        total_count = evaluations.size

        candidates = grouped.map do |decision, evals|
          agreement = evals.size.to_f / total_count
          avg_weight = evals.sum(&:weight) / evals.size

          [decision, agreement, avg_weight]
        end

        candidates.sort_by! { |_, agreement, weight| [-agreement, -weight] }

        winning_decision, agreement, avg_weight = candidates.first

        if agreement >= @minimum_agreement
          confidence = agreement * avg_weight
        else
          confidence = agreement * avg_weight * 0.5
        end

        {
          decision: winning_decision,
          confidence: round_confidence(normalize_confidence(confidence))
        }
      end
    end
  end
end
