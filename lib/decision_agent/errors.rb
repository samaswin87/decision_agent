module DecisionAgent
  class Error < StandardError; end

  class InvalidRuleDslError < Error
    def initialize(message = "Invalid rule DSL structure")
      super
    end
  end

  class NoEvaluationsError < Error
    def initialize(message = "No evaluators returned a decision")
      super
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
      super
    end
  end

  class InvalidEvaluatorError < Error
    def initialize(message = "Evaluator must respond to #evaluate")
      super
    end
  end

  class InvalidScoringStrategyError < Error
    def initialize(message = "Scoring strategy must respond to #score")
      super
    end
  end

  class InvalidAuditAdapterError < Error
    def initialize(message = "Audit adapter must respond to #record")
      super
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
      super
    end
  end

  class ValidationError < Error
    def initialize(message = "Validation failed")
      super
    end
  end

  # Alias for backward compatibility and clearer naming
  ConfigurationError = InvalidConfigurationError

  # Testing-specific errors
  class ImportError < Error
    def initialize(message = "Failed to import test scenarios")
      super
    end
  end

  class InvalidTestDataError < Error
    attr_reader :row_number, :errors

    def initialize(message = "Invalid test data", row_number: nil, errors: [])
      @row_number = row_number
      @errors = errors
      full_message = message.dup
      full_message += " (row #{row_number})" if row_number
      full_message += ": #{errors.join(', ')}" if errors.any?
      super(full_message)
    end
  end

  class BatchTestError < Error
    def initialize(message = "Batch test execution failed")
      super
    end
  end
end
