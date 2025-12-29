require "spec_helper"

RSpec.describe DecisionAgent::EvaluationValidator do
  let(:valid_evaluation) do
    DecisionAgent::Evaluation.new(
      decision: "approve",
      weight: 0.8,
      reason: "Valid reason",
      evaluator_name: "TestEvaluator"
    )
  end

  describe ".validate!" do
    it "validates a valid evaluation" do
      expect do
        described_class.validate!(valid_evaluation)
      end.not_to raise_error
    end

    it "raises error for nil evaluation" do
      expect do
        described_class.validate!(nil)
      end.to raise_error(described_class::ValidationError, /cannot be nil/)
    end

    it "raises error for non-Evaluation object" do
      expect do
        described_class.validate!("not an evaluation")
      end.to raise_error(described_class::ValidationError, /must be an Evaluation instance/)
    end

    it "validates multiple valid evaluations" do
      eval1 = DecisionAgent::Evaluation.new(
        decision: "approve",
        weight: 0.8,
        reason: "Reason 1",
        evaluator_name: "Eval1"
      )

      eval2 = DecisionAgent::Evaluation.new(
        decision: "reject",
        weight: 0.9,
        reason: "Reason 2",
        evaluator_name: "Eval2"
      )

      expect do
        described_class.validate!(eval1)
        described_class.validate!(eval2)
      end.not_to raise_error
    end
  end

  describe ".validate_all!" do
    it "validates an array of valid evaluations" do
      evaluations = [
        valid_evaluation,
        DecisionAgent::Evaluation.new(
          decision: "reject",
          weight: 0.9,
          reason: "Another reason",
          evaluator_name: "OtherEvaluator"
        )
      ]

      expect do
        described_class.validate_all!(evaluations)
      end.not_to raise_error
    end

    it "raises error for non-array input" do
      expect do
        described_class.validate_all!("not an array")
      end.to raise_error(described_class::ValidationError, /must be an Array/)
    end

    it "raises error for empty array" do
      expect do
        described_class.validate_all!([])
      end.to raise_error(described_class::ValidationError, /cannot be empty/)
    end

    it "validates all evaluations in array" do
      eval1 = DecisionAgent::Evaluation.new(
        decision: "approve",
        weight: 0.8,
        reason: "Reason 1",
        evaluator_name: "Eval1"
      )

      eval2 = DecisionAgent::Evaluation.new(
        decision: "reject",
        weight: 0.9,
        reason: "Reason 2",
        evaluator_name: "Eval2"
      )

      expect do
        described_class.validate_all!([eval1, eval2])
      end.not_to raise_error
    end

    it "includes index in error message for invalid evaluation" do
      evaluations = [
        valid_evaluation,
        nil # Invalid evaluation
      ]

      expect do
        described_class.validate_all!(evaluations)
      end.to raise_error(described_class::ValidationError, /index 1/)
    end
  end
end
