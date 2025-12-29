require "spec_helper"
require "decision_agent/ab_testing/ab_test_assignment"

RSpec.describe DecisionAgent::ABTesting::ABTestAssignment do
  describe "#initialize" do
    it "creates an assignment with required fields" do
      assignment = described_class.new(
        ab_test_id: "test_1",
        variant: :champion,
        version_id: "v1"
      )

      expect(assignment.ab_test_id).to eq("test_1")
      expect(assignment.variant).to eq(:champion)
      expect(assignment.version_id).to eq("v1")
      expect(assignment.timestamp).to be_a(Time)
    end

    it "accepts optional user_id" do
      assignment = described_class.new(
        ab_test_id: "test_1",
        variant: :champion,
        version_id: "v1",
        user_id: "user_123"
      )

      expect(assignment.user_id).to eq("user_123")
    end

    it "accepts optional timestamp" do
      custom_time = Time.new(2024, 1, 1, 12, 0, 0, "+00:00")
      assignment = described_class.new(
        ab_test_id: "test_1",
        variant: :champion,
        version_id: "v1",
        timestamp: custom_time
      )

      expect(assignment.timestamp).to eq(custom_time)
    end

    it "accepts optional decision_result and confidence" do
      assignment = described_class.new(
        ab_test_id: "test_1",
        variant: :champion,
        version_id: "v1",
        decision_result: "approve",
        confidence: 0.95
      )

      expect(assignment.decision_result).to eq("approve")
      expect(assignment.confidence).to eq(0.95)
    end

    it "accepts optional context" do
      context = { user_type: "premium", region: "us" }
      assignment = described_class.new(
        ab_test_id: "test_1",
        variant: :champion,
        version_id: "v1",
        context: context
      )

      expect(assignment.context).to eq(context)
    end

    it "defaults context to empty hash" do
      assignment = described_class.new(
        ab_test_id: "test_1",
        variant: :champion,
        version_id: "v1"
      )

      expect(assignment.context).to eq({})
    end

    it "accepts optional id" do
      assignment = described_class.new(
        ab_test_id: "test_1",
        variant: :champion,
        version_id: "v1",
        id: "assign_123"
      )

      expect(assignment.id).to eq("assign_123")
    end

    it "raises error if ab_test_id is nil" do
      expect do
        described_class.new(
          ab_test_id: nil,
          variant: :champion,
          version_id: "v1"
        )
      end.to raise_error(DecisionAgent::ValidationError, /AB test ID is required/)
    end

    it "raises error if variant is nil" do
      expect do
        described_class.new(
          ab_test_id: "test_1",
          variant: nil,
          version_id: "v1"
        )
      end.to raise_error(DecisionAgent::ValidationError, /Variant is required/)
    end

    it "raises error if version_id is nil" do
      expect do
        described_class.new(
          ab_test_id: "test_1",
          variant: :champion,
          version_id: nil
        )
      end.to raise_error(DecisionAgent::ValidationError, /Version ID is required/)
    end

    it "raises error if variant is not :champion or :challenger" do
      expect do
        described_class.new(
          ab_test_id: "test_1",
          variant: :invalid,
          version_id: "v1"
        )
      end.to raise_error(DecisionAgent::ValidationError, /Variant must be :champion or :challenger/)
    end

    it "raises error if confidence is negative" do
      expect do
        described_class.new(
          ab_test_id: "test_1",
          variant: :champion,
          version_id: "v1",
          confidence: -0.1
        )
      end.to raise_error(DecisionAgent::ValidationError, /Confidence must be between 0 and 1/)
    end

    it "raises error if confidence is greater than 1" do
      expect do
        described_class.new(
          ab_test_id: "test_1",
          variant: :champion,
          version_id: "v1",
          confidence: 1.5
        )
      end.to raise_error(DecisionAgent::ValidationError, /Confidence must be between 0 and 1/)
    end

    it "accepts confidence of 0" do
      assignment = described_class.new(
        ab_test_id: "test_1",
        variant: :champion,
        version_id: "v1",
        confidence: 0.0
      )

      expect(assignment.confidence).to eq(0.0)
    end

    it "accepts confidence of 1" do
      assignment = described_class.new(
        ab_test_id: "test_1",
        variant: :champion,
        version_id: "v1",
        confidence: 1.0
      )

      expect(assignment.confidence).to eq(1.0)
    end

    it "accepts challenger variant" do
      assignment = described_class.new(
        ab_test_id: "test_1",
        variant: :challenger,
        version_id: "v2"
      )

      expect(assignment.variant).to eq(:challenger)
    end
  end

  describe "#record_decision" do
    let(:assignment) do
      described_class.new(
        ab_test_id: "test_1",
        variant: :champion,
        version_id: "v1"
      )
    end

    it "updates decision_result and confidence" do
      assignment.record_decision("approve", 0.95)

      expect(assignment.decision_result).to eq("approve")
      expect(assignment.confidence).to eq(0.95)
    end

    it "can update multiple times" do
      assignment.record_decision("approve", 0.95)
      assignment.record_decision("reject", 0.85)

      expect(assignment.decision_result).to eq("reject")
      expect(assignment.confidence).to eq(0.85)
    end
  end

  describe "#to_h" do
    it "converts assignment to hash with all fields" do
      assignment = described_class.new(
        ab_test_id: "test_1",
        variant: :champion,
        version_id: "v1",
        id: "assign_123",
        user_id: "user_456",
        decision_result: "approve",
        confidence: 0.95,
        context: { region: "us" },
        timestamp: Time.new(2024, 1, 1, 12, 0, 0, "+00:00")
      )

      hash = assignment.to_h

      expect(hash).to eq({
        id: "assign_123",
        ab_test_id: "test_1",
        user_id: "user_456",
        variant: :champion,
        version_id: "v1",
        timestamp: Time.new(2024, 1, 1, 12, 0, 0, "+00:00"),
        decision_result: "approve",
        confidence: 0.95,
        context: { region: "us" }
      })
    end

    it "includes nil values in hash" do
      assignment = described_class.new(
        ab_test_id: "test_1",
        variant: :champion,
        version_id: "v1"
      )

      hash = assignment.to_h

      expect(hash[:id]).to be_nil
      expect(hash[:user_id]).to be_nil
      expect(hash[:decision_result]).to be_nil
      expect(hash[:confidence]).to be_nil
      expect(hash[:context]).to eq({})
    end
  end
end

