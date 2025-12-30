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

      freeze
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
      raise InvalidConfidenceError, confidence unless c.between?(0.0, 1.0)
    end

    def deep_freeze(obj)
      return obj if obj.frozen?

      case obj
      when Hash
        obj.each_value { |v| deep_freeze(v) }
        obj.freeze
      when Array
        obj.each { |v| deep_freeze(v) }
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
