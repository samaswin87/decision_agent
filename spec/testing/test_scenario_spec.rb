require "spec_helper"

RSpec.describe DecisionAgent::Testing::TestScenario do
  describe "#initialize" do
    it "creates a test scenario with required fields" do
      scenario = DecisionAgent::Testing::TestScenario.new(
        id: "test_1",
        context: { user_id: 123, amount: 1000 }
      )

      expect(scenario.id).to eq("test_1")
      expect(scenario.context).to eq({ user_id: 123, amount: 1000 })
      expect(scenario.expected_decision).to be_nil
      expect(scenario.expected_confidence).to be_nil
    end

    it "creates a test scenario with expected results" do
      scenario = DecisionAgent::Testing::TestScenario.new(
        id: "test_2",
        context: { user_id: 456 },
        expected_decision: "approve",
        expected_confidence: 0.95
      )

      expect(scenario.expected_decision).to eq("approve")
      expect(scenario.expected_confidence).to eq(0.95)
    end

    it "freezes the scenario for immutability" do
      scenario = DecisionAgent::Testing::TestScenario.new(
        id: "test_3",
        context: { key: "value" }
      )

      expect(scenario.frozen?).to be true
    end
  end

  describe "#expected_result?" do
    it "returns true when expected_decision is set" do
      scenario = DecisionAgent::Testing::TestScenario.new(
        id: "test_1",
        context: { key: "value" },
        expected_decision: "approve"
      )

      expect(scenario.expected_result?).to be true
    end

    it "returns false when expected_decision is nil" do
      scenario = DecisionAgent::Testing::TestScenario.new(
        id: "test_1",
        context: { key: "value" }
      )

      expect(scenario.expected_result?).to be false
    end
  end

  describe "#to_h" do
    it "converts scenario to hash" do
      scenario = DecisionAgent::Testing::TestScenario.new(
        id: "test_1",
        context: { user_id: 123 },
        expected_decision: "approve",
        expected_confidence: 0.9,
        metadata: { source: "csv" }
      )

      hash = scenario.to_h

      expect(hash).to eq({
                           id: "test_1",
                           context: { user_id: 123 },
                           expected_decision: "approve",
                           expected_confidence: 0.9,
                           metadata: { source: "csv" }
                         })
    end
  end

  describe "#==" do
    it "returns true for equal scenarios" do
      scenario1 = DecisionAgent::Testing::TestScenario.new(
        id: "test_1",
        context: { user_id: 123 },
        expected_decision: "approve"
      )

      scenario2 = DecisionAgent::Testing::TestScenario.new(
        id: "test_1",
        context: { user_id: 123 },
        expected_decision: "approve"
      )

      expect(scenario1).to eq(scenario2)
    end

    it "returns false for different scenarios" do
      scenario1 = DecisionAgent::Testing::TestScenario.new(
        id: "test_1",
        context: { user_id: 123 }
      )

      scenario2 = DecisionAgent::Testing::TestScenario.new(
        id: "test_2",
        context: { user_id: 123 }
      )

      expect(scenario1).not_to eq(scenario2)
    end
  end
end
