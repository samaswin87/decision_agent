require "spec_helper"

RSpec.describe DecisionAgent::Evaluation do
  describe "#initialize" do
    it "creates an evaluation with all required fields" do
      evaluation = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test reason",
        evaluator_name: "TestEvaluator"
      )

      expect(evaluation.decision).to eq("approve")
      expect(evaluation.weight).to eq(0.8)
      expect(evaluation.reason).to eq("Test reason")
      expect(evaluation.evaluator_name).to eq("TestEvaluator")
      expect(evaluation.metadata).to eq({})
    end

    it "converts decision to string" do
      evaluation = described_class.new(
        decision: :approve,
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test"
      )

      expect(evaluation.decision).to eq("approve")
    end

    it "converts weight to float" do
      evaluation = described_class.new(
        decision: "approve",
        weight: "0.8",
        reason: "Test",
        evaluator_name: "Test"
      )

      expect(evaluation.weight).to eq(0.8)
    end

    it "converts reason to string" do
      evaluation = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: :test_reason,
        evaluator_name: "Test"
      )

      expect(evaluation.reason).to eq("test_reason")
    end

    it "converts evaluator_name to string" do
      evaluation = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: :TestEvaluator
      )

      expect(evaluation.evaluator_name).to eq("TestEvaluator")
    end

    it "freezes the evaluation object" do
      evaluation = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test"
      )

      expect(evaluation).to be_frozen
    end

    it "freezes nested structures" do
      evaluation = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test",
        metadata: { key: "value", nested: { data: [1, 2, 3] } }
      )

      expect(evaluation.decision).to be_frozen
      expect(evaluation.reason).to be_frozen
      expect(evaluation.evaluator_name).to be_frozen
      expect(evaluation.metadata).to be_frozen
      expect(evaluation.metadata[:nested]).to be_frozen
      expect(evaluation.metadata[:nested][:data]).to be_frozen
    end

    it "freezes metadata in-place without creating new objects" do
      original_metadata = { key: "value", nested: { data: [1, 2, 3] } }
      original_metadata_id = original_metadata.object_id
      original_nested_id = original_metadata[:nested].object_id

      evaluation = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test",
        metadata: original_metadata
      )

      # Should freeze in-place, not create new objects
      expect(evaluation.metadata.object_id).to eq(original_metadata_id)
      expect(evaluation.metadata[:nested].object_id).to eq(original_nested_id)
      expect(evaluation.metadata).to be_frozen
      expect(evaluation.metadata[:nested]).to be_frozen
    end

    it "skips already frozen objects in deep_freeze" do
      frozen_metadata = { key: "value", nested: { data: [1, 2, 3] } }
      frozen_metadata.freeze
      frozen_metadata[:nested].freeze

      evaluation = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test",
        metadata: frozen_metadata
      )

      expect(evaluation.metadata).to be_frozen
      expect(evaluation.metadata[:nested]).to be_frozen
    end

    it "does not freeze hash keys unnecessarily" do
      key_symbol = :test_key
      key_string = "test_key"
      metadata = {
        key_symbol => "value1",
        key_string => "value2"
      }

      evaluation = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test",
        metadata: metadata
      )

      # Keys should not be frozen (they're typically symbols/strings that don't need freezing)
      expect(evaluation.metadata.keys.first).to eq(key_symbol)
      expect(evaluation.metadata.keys.last).to eq(key_string)
      # Values should be frozen
      expect(evaluation.metadata[key_symbol]).to be_frozen
      expect(evaluation.metadata[key_string]).to be_frozen
    end

    it "raises error for weight outside 0-1 range" do
      expect do
        described_class.new(
          decision: "approve",
          weight: 1.5,
          reason: "Test",
          evaluator_name: "Test"
        )
      end.to raise_error(DecisionAgent::InvalidWeightError)
    end

    it "raises error for negative weight" do
      expect do
        described_class.new(
          decision: "approve",
          weight: -0.1,
          reason: "Test",
          evaluator_name: "Test"
        )
      end.to raise_error(DecisionAgent::InvalidWeightError)
    end

    it "accepts weight at boundaries" do
      eval1 = described_class.new(
        decision: "approve",
        weight: 0.0,
        reason: "Test",
        evaluator_name: "Test"
      )
      expect(eval1.weight).to eq(0.0)

      eval2 = described_class.new(
        decision: "approve",
        weight: 1.0,
        reason: "Test",
        evaluator_name: "Test"
      )
      expect(eval2.weight).to eq(1.0)
    end

    it "handles metadata" do
      metadata = { rule_id: "rule_1", source: "test" }
      evaluation = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test",
        metadata: metadata
      )

      expect(evaluation.metadata).to eq(metadata)
    end

    it "defaults to empty metadata" do
      evaluation = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test"
      )

      expect(evaluation.metadata).to eq({})
    end
  end

  describe "#to_h" do
    it "converts evaluation to hash" do
      evaluation = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test reason",
        evaluator_name: "TestEvaluator",
        metadata: { key: "value" }
      )

      hash = evaluation.to_h

      expect(hash).to be_a(Hash)
      expect(hash[:decision]).to eq("approve")
      expect(hash[:weight]).to eq(0.8)
      expect(hash[:reason]).to eq("Test reason")
      expect(hash[:evaluator_name]).to eq("TestEvaluator")
      expect(hash[:metadata]).to eq({ key: "value" })
    end
  end

  describe "#==" do
    it "compares evaluations by all fields" do
      eval1 = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test",
        metadata: { key: "value" }
      )

      eval2 = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test",
        metadata: { key: "value" }
      )

      expect(eval1).to eq(eval2)
    end

    it "returns false for different decisions" do
      eval1 = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test"
      )

      eval2 = described_class.new(
        decision: "reject",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test"
      )

      expect(eval1).not_to eq(eval2)
    end

    it "returns false for different weights" do
      eval1 = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test"
      )

      eval2 = described_class.new(
        decision: "approve",
        weight: 0.9,
        reason: "Test",
        evaluator_name: "Test"
      )

      expect(eval1).not_to eq(eval2)
    end

    it "returns false for different reasons" do
      eval1 = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Reason 1",
        evaluator_name: "Test"
      )

      eval2 = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Reason 2",
        evaluator_name: "Test"
      )

      expect(eval1).not_to eq(eval2)
    end

    it "returns false for different evaluator names" do
      eval1 = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Evaluator1"
      )

      eval2 = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Evaluator2"
      )

      expect(eval1).not_to eq(eval2)
    end

    it "returns false for different metadata" do
      eval1 = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test",
        metadata: { key: "value1" }
      )

      eval2 = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test",
        metadata: { key: "value2" }
      )

      expect(eval1).not_to eq(eval2)
    end

    it "returns false for non-Evaluation objects" do
      evaluation = described_class.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test",
        evaluator_name: "Test"
      )

      expect(evaluation).not_to eq("not an evaluation")
      expect(evaluation).not_to eq(nil)
    end
  end
end
