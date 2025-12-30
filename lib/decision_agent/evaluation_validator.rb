# frozen_string_literal: true

module DecisionAgent
  # Validates evaluation objects for correctness and thread-safety
  class EvaluationValidator
    class ValidationError < StandardError; end

    # Validates a single evaluation
    # @param evaluation [Evaluation] the evaluation to validate
    # @raise [ValidationError] if validation fails
    def self.validate!(evaluation)
      raise ValidationError, "Evaluation cannot be nil" if evaluation.nil?
      raise ValidationError, "Evaluation must be an Evaluation instance" unless evaluation.is_a?(Evaluation)

      validate_decision!(evaluation.decision)
      validate_weight!(evaluation.weight)
      validate_reason!(evaluation.reason)
      validate_evaluator_name!(evaluation.evaluator_name)
      validate_frozen!(evaluation)

      true
    end

    # Validates an array of evaluations
    # @param evaluations [Array<Evaluation>] the evaluations to validate
    # @raise [ValidationError] if validation fails
    def self.validate_all!(evaluations)
      raise ValidationError, "Evaluations must be an Array" unless evaluations.is_a?(Array)
      raise ValidationError, "Evaluations array cannot be empty" if evaluations.empty?

      evaluations.each_with_index do |evaluation, index|
        validate!(evaluation)
      rescue ValidationError => e
        raise ValidationError, "Validation failed for evaluation at index #{index}: #{e.message}"
      end

      true
    end

    private_class_method def self.validate_decision!(decision)
      raise ValidationError, "Decision cannot be nil" if decision.nil?
      raise ValidationError, "Decision must be a String" unless decision.is_a?(String)
      # Fast path: skip strip if string is clearly not empty (length > 0)
      raise ValidationError, "Decision cannot be empty" if decision.empty? || decision.strip.empty?
    end

    private_class_method def self.validate_weight!(weight)
      raise ValidationError, "Weight cannot be nil" if weight.nil?
      raise ValidationError, "Weight must be a Numeric" unless weight.is_a?(Numeric)
      raise ValidationError, "Weight must be between 0 and 1" unless weight.between?(0, 1)
    end

    private_class_method def self.validate_reason!(reason)
      raise ValidationError, "Reason cannot be nil" if reason.nil?
      raise ValidationError, "Reason must be a String" unless reason.is_a?(String)
      # Fast path: skip strip if string is clearly not empty (length > 0)
      raise ValidationError, "Reason cannot be empty" if reason.empty? || reason.strip.empty?
    end

    private_class_method def self.validate_evaluator_name!(name)
      raise ValidationError, "Evaluator name cannot be nil" if name.nil?
      raise ValidationError, "Evaluator name must be a String or Symbol" unless name.is_a?(String) || name.is_a?(Symbol)
    end

    private_class_method def self.validate_frozen!(evaluation)
      # Fast path: if evaluation is frozen, assume nested structures are also frozen
      # (they are frozen in Evaluation#initialize)
      return true if evaluation.frozen?

      raise ValidationError, "Evaluation must be frozen for thread-safety (call .freeze)"
    end
  end
end
