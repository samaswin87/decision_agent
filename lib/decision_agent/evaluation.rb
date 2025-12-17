module DecisionAgent
  class Evaluation
    attr_reader :decision, :weight, :reason, :evaluator_name, :metadata

    def initialize(decision:, weight:, reason:, evaluator_name:, metadata: {})
      validate_weight!(weight)

      @decision = decision.to_s.freeze
      @weight = weight.to_f
      @reason = reason.to_s.freeze
      @evaluator_name = evaluator_name.to_s.freeze
      @metadata = deep_freeze(metadata)
    end

    def to_h
      {
        decision: @decision,
        weight: @weight,
        reason: @reason,
        evaluator_name: @evaluator_name,
        metadata: @metadata
      }
    end

    def ==(other)
      other.is_a?(Evaluation) &&
        @decision == other.decision &&
        @weight == other.weight &&
        @reason == other.reason &&
        @evaluator_name == other.evaluator_name &&
        @metadata == other.metadata
    end

    private

    def validate_weight!(weight)
      w = weight.to_f
      raise InvalidWeightError.new(weight) unless w >= 0.0 && w <= 1.0
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
