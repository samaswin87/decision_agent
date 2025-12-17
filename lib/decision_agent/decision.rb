module DecisionAgent
  class Decision
    attr_reader :decision, :confidence, :explanations, :evaluations, :audit_payload

    def initialize(decision:, confidence:, explanations:, evaluations:, audit_payload:)
      validate_confidence!(confidence)

      @decision = decision.to_s.freeze
      @confidence = confidence.to_f
      @explanations = Array(explanations).map(&:freeze).freeze
      @evaluations = Array(evaluations).freeze
      @audit_payload = deep_freeze(audit_payload)
    end

    def to_h
      {
        decision: @decision,
        confidence: @confidence,
        explanations: @explanations,
        evaluations: @evaluations.map(&:to_h),
        audit_payload: @audit_payload
      }
    end

    def ==(other)
      other.is_a?(Decision) &&
        @decision == other.decision &&
        (@confidence - other.confidence).abs < 0.0001 &&
        @explanations == other.explanations &&
        @evaluations == other.evaluations
    end

    private

    def validate_confidence!(confidence)
      c = confidence.to_f
      raise InvalidConfidenceError.new(confidence) unless c >= 0.0 && c <= 1.0
    end

    def deep_freeze(obj)
      case obj
      when Hash
        obj.transform_values { |v| deep_freeze(v) }.freeze
      when Array
        obj.map { |v| deep_freeze(v) }.freeze
      else
        obj.freeze
      end
    end
  end
end
