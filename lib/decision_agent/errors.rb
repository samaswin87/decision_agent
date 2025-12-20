module DecisionAgent
  class Error < StandardError; end

  class InvalidRuleDslError < Error
    def initialize(message = "Invalid rule DSL structure")
      super(message)
    end
  end

  class NoEvaluationsError < Error
    def initialize(message = "No evaluators returned a decision")
      super(message)
    end
  end

  class ReplayMismatchError < Error
    attr_reader :expected, :actual, :differences

    def initialize(expected:, actual:, differences:)
      @expected = expected
      @actual = actual
      @differences = differences
      super("Replay mismatch detected: #{differences.join(', ')}")
    end
  end

  class InvalidConfigurationError < Error
    def initialize(message = "Invalid agent configuration")
      super(message)
    end
  end

  class InvalidEvaluatorError < Error
    def initialize(message = "Evaluator must respond to #evaluate")
      super(message)
    end
  end

  class InvalidScoringStrategyError < Error
    def initialize(message = "Scoring strategy must respond to #score")
      super(message)
    end
  end

  class InvalidAuditAdapterError < Error
    def initialize(message = "Audit adapter must respond to #record")
      super(message)
    end
  end

  class InvalidConfidenceError < Error
    def initialize(confidence)
      super("Confidence must be between 0.0 and 1.0, got: #{confidence}")
    end
  end

  class InvalidWeightError < Error
    def initialize(weight)
      super("Weight must be between 0.0 and 1.0, got: #{weight}")
    end
  end

  class NotFoundError < Error
    def initialize(message = "Resource not found")
      super(message)
    end
  end

  class ValidationError < Error
    def initialize(message = "Validation failed")
      super(message)
    end
  end

  # Alias for backward compatibility and clearer naming
  ConfigurationError = InvalidConfigurationError
end
