require "spec_helper"

RSpec.describe DecisionAgent::Decision do
  let(:evaluation) do
    DecisionAgent::Evaluation.new(
      decision: "approve",
      weight: 0.8,
      reason: "Test reason",
      evaluator_name: "TestEvaluator"
    )
  end

  let(:audit_payload) do
    {
      timestamp: "2025-01-01T00:00:00Z",
      context: { user: "test" },
      decision: "approve",
      confidence: 0.8
    }
  end

  describe "#initialize" do
    it "creates a decision with all required fields" do
      decision = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: ["Test explanation"],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      expect(decision.decision).to eq("approve")
      expect(decision.confidence).to eq(0.8)
      expect(decision.explanations).to eq(["Test explanation"])
      expect(decision.evaluations).to eq([evaluation])
      expect(decision.audit_payload).to eq(audit_payload)
    end

    it "converts decision to string" do
      decision = described_class.new(
        decision: :approve,
        confidence: 0.8,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      expect(decision.decision).to eq("approve")
    end

    it "converts confidence to float" do
      decision = described_class.new(
        decision: "approve",
        confidence: "0.8",
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      expect(decision.confidence).to eq(0.8)
    end

    it "freezes the decision object" do
      decision = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      expect(decision).to be_frozen
    end

    it "freezes nested structures" do
      decision = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: ["explanation"],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      expect(decision.decision).to be_frozen
      expect(decision.explanations).to be_frozen
      expect(decision.explanations.first).to be_frozen
      expect(decision.evaluations).to be_frozen
    end

    it "deep freezes audit payload" do
      nested_payload = {
        context: { user: { name: "test" } },
        metadata: [1, 2, 3]
      }

      decision = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: nested_payload
      )

      expect(decision.audit_payload).to be_frozen
      expect(decision.audit_payload[:context]).to be_frozen
      expect(decision.audit_payload[:context][:user]).to be_frozen
      expect(decision.audit_payload[:metadata]).to be_frozen
    end

    it "raises error for confidence outside 0-1 range" do
      expect do
        described_class.new(
          decision: "approve",
          confidence: 1.5,
          explanations: [],
          evaluations: [evaluation],
          audit_payload: audit_payload
        )
      end.to raise_error(DecisionAgent::InvalidConfidenceError)
    end

    it "raises error for negative confidence" do
      expect do
        described_class.new(
          decision: "approve",
          confidence: -0.1,
          explanations: [],
          evaluations: [evaluation],
          audit_payload: audit_payload
        )
      end.to raise_error(DecisionAgent::InvalidConfidenceError)
    end

    it "accepts confidence at boundaries" do
      decision1 = described_class.new(
        decision: "approve",
        confidence: 0.0,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )
      expect(decision1.confidence).to eq(0.0)

      decision2 = described_class.new(
        decision: "approve",
        confidence: 1.0,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )
      expect(decision2.confidence).to eq(1.0)
    end

    it "handles array explanations" do
      explanations = %w[explanation1 explanation2]
      decision = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: explanations,
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      expect(decision.explanations).to eq(explanations)
    end

    it "converts non-array explanations to array" do
      decision = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: "single explanation",
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      expect(decision.explanations).to eq(["single explanation"])
    end
  end

  describe "#to_h" do
    it "converts decision to hash" do
      decision = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: ["explanation"],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      hash = decision.to_h

      expect(hash).to be_a(Hash)
      expect(hash[:decision]).to eq("approve")
      expect(hash[:confidence]).to eq(0.8)
      expect(hash[:explanations]).to eq(["explanation"])
      expect(hash[:evaluations]).to be_an(Array)
      expect(hash[:evaluations].first).to be_a(Hash)
      expect(hash[:audit_payload]).to eq(audit_payload)
    end

    it "converts evaluations to hashes" do
      decision = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      hash = decision.to_h
      expect(hash[:evaluations].first[:decision]).to eq("approve")
      expect(hash[:evaluations].first[:weight]).to eq(0.8)
    end
  end

  describe "#==" do
    it "compares decisions by all fields" do
      decision1 = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: ["explanation"],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      decision2 = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: ["explanation"],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      expect(decision1).to eq(decision2)
    end

    it "returns false for different decisions" do
      decision1 = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      decision2 = described_class.new(
        decision: "reject",
        confidence: 0.8,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      expect(decision1).not_to eq(decision2)
    end

    it "returns false for different confidences" do
      decision1 = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      decision2 = described_class.new(
        decision: "approve",
        confidence: 0.9,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      expect(decision1).not_to eq(decision2)
    end

    it "allows small confidence differences" do
      decision1 = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      decision2 = described_class.new(
        decision: "approve",
        confidence: 0.8000001,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      expect(decision1).to eq(decision2)
    end

    it "returns false for different explanations" do
      decision1 = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: ["explanation1"],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      decision2 = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: ["explanation2"],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      expect(decision1).not_to eq(decision2)
    end

    it "returns false for different evaluations" do
      eval2 = DecisionAgent::Evaluation.new(
        decision: "reject",
        weight: 0.9,
        reason: "Different reason",
        evaluator_name: "OtherEvaluator"
      )

      decision1 = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      decision2 = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: [],
        evaluations: [eval2],
        audit_payload: audit_payload
      )

      expect(decision1).not_to eq(decision2)
    end

    it "returns false for non-Decision objects" do
      decision = described_class.new(
        decision: "approve",
        confidence: 0.8,
        explanations: [],
        evaluations: [evaluation],
        audit_payload: audit_payload
      )

      expect(decision).not_to eq("not a decision")
      expect(decision).not_to eq(nil)
    end
  end
end
