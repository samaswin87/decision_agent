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

  describe "optimized frozen validation" do
    it "uses fast path for frozen evaluations" do
      # Evaluations are always frozen in their initializer
      evaluation = DecisionAgent::Evaluation.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test reason",
        evaluator_name: "TestEvaluator"
      )

      expect(evaluation).to be_frozen
      expect do
        described_class.validate!(evaluation)
      end.not_to raise_error
    end

    it "skips nested frozen checks when evaluation is frozen" do
      # Since evaluations are always frozen in initializer,
      # the optimized validator should skip checking nested structures
      evaluation = DecisionAgent::Evaluation.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test reason",
        evaluator_name: "TestEvaluator",
        metadata: { nested: { data: "value" } }
      )

      expect(evaluation).to be_frozen
      expect(evaluation.metadata).to be_frozen
      expect do
        described_class.validate!(evaluation)
      end.not_to raise_error
    end

    it "still validates unfrozen evaluations" do
      # Create a mock object that isn't frozen (simulating an edge case)
      # In practice, evaluations are always frozen in their initializer
      unfrozen_evaluation = double("UnfrozenEvaluation")
      allow(unfrozen_evaluation).to receive(:frozen?).and_return(false)
      allow(unfrozen_evaluation).to receive(:is_a?).with(DecisionAgent::Evaluation).and_return(true)
      allow(unfrozen_evaluation).to receive(:decision).and_return("approve")
      allow(unfrozen_evaluation).to receive(:weight).and_return(0.8)
      allow(unfrozen_evaluation).to receive(:reason).and_return("Test reason")
      allow(unfrozen_evaluation).to receive(:evaluator_name).and_return("TestEvaluator")

      expect do
        described_class.validate!(unfrozen_evaluation)
      end.to raise_error(described_class::ValidationError, /must be frozen/)
    end
  end
end
