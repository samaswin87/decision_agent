require "spec_helper"

RSpec.describe "Scoring Strategies" do
  let(:eval1) do
    DecisionAgent::Evaluation.new(
      decision: "approve",
      weight: 0.6,
      reason: "Test 1",
      evaluator_name: "Eval1"
    )
  end

  let(:eval2) do
    DecisionAgent::Evaluation.new(
      decision: "approve",
      weight: 0.8,
      reason: "Test 2",
      evaluator_name: "Eval2"
    )
  end

  let(:eval3) do
    DecisionAgent::Evaluation.new(
      decision: "reject",
      weight: 0.5,
      reason: "Test 3",
      evaluator_name: "Eval3"
    )
  end

  describe DecisionAgent::Scoring::WeightedAverage do
    it "calculates weighted average for single decision" do
      strategy = DecisionAgent::Scoring::WeightedAverage.new
      result = strategy.score([eval1, eval2])

      expect(result[:decision]).to eq("approve")
      expect(result[:confidence]).to eq(1.0)
    end

    it "calculates weighted average with conflicts" do
      strategy = DecisionAgent::Scoring::WeightedAverage.new
      result = strategy.score([eval1, eval2, eval3])

      total_weight = 0.6 + 0.8 + 0.5
      approve_weight = 0.6 + 0.8
      expected_confidence = approve_weight / total_weight

      expect(result[:decision]).to eq("approve")
      expect(result[:confidence]).to be_within(0.0001).of(expected_confidence)
    end

    it "returns 0 confidence for empty evaluations" do
      strategy = DecisionAgent::Scoring::WeightedAverage.new
      result = strategy.score([])

      expect(result[:decision]).to be_nil
      expect(result[:confidence]).to eq(0.0)
    end

    it "normalizes confidence to [0, 1]" do
      strategy = DecisionAgent::Scoring::WeightedAverage.new
      result = strategy.score([eval1])

      expect(result[:confidence]).to be_between(0.0, 1.0)
    end
  end

  describe DecisionAgent::Scoring::MaxWeight do
    it "selects decision with maximum weight" do
      strategy = DecisionAgent::Scoring::MaxWeight.new
      result = strategy.score([eval1, eval2, eval3])

      expect(result[:decision]).to eq("approve")
      expect(result[:confidence]).to eq(0.8)
    end

    it "uses first evaluation when weights are equal" do
      eval_a = DecisionAgent::Evaluation.new(
        decision: "option_a",
        weight: 0.7,
        reason: "Test A",
        evaluator_name: "EvalA"
      )
      eval_b = DecisionAgent::Evaluation.new(
        decision: "option_b",
        weight: 0.7,
        reason: "Test B",
        evaluator_name: "EvalB"
      )

      strategy = DecisionAgent::Scoring::MaxWeight.new
      result = strategy.score([eval_a, eval_b])

      expect(["option_a", "option_b"]).to include(result[:decision])
      expect(result[:confidence]).to eq(0.7)
    end

    it "returns 0 confidence for empty evaluations" do
      strategy = DecisionAgent::Scoring::MaxWeight.new
      result = strategy.score([])

      expect(result[:decision]).to be_nil
      expect(result[:confidence]).to eq(0.0)
    end
  end

  describe DecisionAgent::Scoring::Consensus do
    it "selects decision with highest agreement" do
      eval4 = DecisionAgent::Evaluation.new(
        decision: "approve",
        weight: 0.7,
        reason: "Test 4",
        evaluator_name: "Eval4"
      )

      strategy = DecisionAgent::Scoring::Consensus.new
      result = strategy.score([eval1, eval2, eval3, eval4])

      expect(result[:decision]).to eq("approve")
    end

    it "considers both agreement and weight" do
      low_weight_majority = [
        DecisionAgent::Evaluation.new(decision: "approve", weight: 0.3, reason: "A", evaluator_name: "E1"),
        DecisionAgent::Evaluation.new(decision: "approve", weight: 0.3, reason: "B", evaluator_name: "E2"),
        DecisionAgent::Evaluation.new(decision: "approve", weight: 0.3, reason: "C", evaluator_name: "E3")
      ]

      high_weight_minority = [
        DecisionAgent::Evaluation.new(decision: "reject", weight: 0.9, reason: "D", evaluator_name: "E4")
      ]

      strategy = DecisionAgent::Scoring::Consensus.new
      result = strategy.score(low_weight_majority + high_weight_minority)

      expect(result[:decision]).to eq("approve")
    end

    it "reduces confidence when minimum agreement not met" do
      eval_spread = [
        DecisionAgent::Evaluation.new(decision: "option_a", weight: 0.8, reason: "A", evaluator_name: "E1"),
        DecisionAgent::Evaluation.new(decision: "option_b", weight: 0.7, reason: "B", evaluator_name: "E2"),
        DecisionAgent::Evaluation.new(decision: "option_c", weight: 0.6, reason: "C", evaluator_name: "E3")
      ]

      strategy = DecisionAgent::Scoring::Consensus.new(minimum_agreement: 0.5)
      result = strategy.score(eval_spread)

      expect(result[:confidence]).to be < 0.5
    end

    it "allows custom minimum agreement threshold" do
      strategy = DecisionAgent::Scoring::Consensus.new(minimum_agreement: 0.7)
      result = strategy.score([eval1, eval2, eval3])

      expect(result[:decision]).to eq("approve")
    end

    it "returns 0 confidence for empty evaluations" do
      strategy = DecisionAgent::Scoring::Consensus.new
      result = strategy.score([])

      expect(result[:decision]).to be_nil
      expect(result[:confidence]).to eq(0.0)
    end
  end

  describe DecisionAgent::Scoring::Threshold do
    it "accepts decision when weight meets threshold" do
      strategy = DecisionAgent::Scoring::Threshold.new(threshold: 0.7)
      result = strategy.score([eval2])

      expect(result[:decision]).to eq("approve")
      expect(result[:confidence]).to eq(0.8)
    end

    it "returns fallback decision when weight below threshold" do
      strategy = DecisionAgent::Scoring::Threshold.new(threshold: 0.9, fallback_decision: "manual_review")
      result = strategy.score([eval2])

      expect(result[:decision]).to eq("manual_review")
      expect(result[:confidence]).to be < 0.9
    end

    it "uses average weight across evaluations with same decision" do
      strategy = DecisionAgent::Scoring::Threshold.new(threshold: 0.7)
      result = strategy.score([eval1, eval2])

      avg_weight = (0.6 + 0.8) / 2
      expect(result[:decision]).to eq("approve")
      expect(result[:confidence]).to eq(avg_weight)
    end

    it "uses default fallback decision" do
      strategy = DecisionAgent::Scoring::Threshold.new(threshold: 0.9)
      result = strategy.score([eval1])

      expect(result[:decision]).to eq("no_decision")
    end

    it "returns fallback for empty evaluations" do
      strategy = DecisionAgent::Scoring::Threshold.new(fallback_decision: "default")
      result = strategy.score([])

      expect(result[:decision]).to eq("default")
      expect(result[:confidence]).to eq(0.0)
    end
  end

  describe "confidence bounds" do
    it "ensures all strategies return confidence between 0 and 1" do
      strategies = [
        DecisionAgent::Scoring::WeightedAverage.new,
        DecisionAgent::Scoring::MaxWeight.new,
        DecisionAgent::Scoring::Consensus.new,
        DecisionAgent::Scoring::Threshold.new
      ]

      strategies.each do |strategy|
        result = strategy.score([eval1, eval2, eval3])
        expect(result[:confidence]).to be_between(0.0, 1.0)
      end
    end
  end
end
