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

      freeze
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
      raise InvalidWeightError, weight unless w.between?(0.0, 1.0)
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
