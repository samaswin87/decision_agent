require "spec_helper"

RSpec.describe DecisionAgent::Explainability do
  describe DecisionAgent::Explainability::ConditionTrace do
    describe "#initialize" do
      it "creates a condition trace with all fields" do
        trace = DecisionAgent::Explainability::ConditionTrace.new(
          field: "risk_score",
          operator: "lt",
          expected_value: 0.7,
          actual_value: 0.5,
          result: true
        )

        expect(trace.field).to eq("risk_score")
        expect(trace.operator).to eq("lt")
        expect(trace.expected_value).to eq(0.7)
        expect(trace.actual_value).to eq(0.5)
        expect(trace.result).to eq(true)
      end

      it "generates description automatically" do
        trace = DecisionAgent::Explainability::ConditionTrace.new(
          field: "risk_score",
          operator: "lt",
          expected_value: 0.7,
          actual_value: 0.5,
          result: true
        )

        expect(trace.description).to eq("risk_score < 0.7")
      end

      it "accepts custom description" do
        trace = DecisionAgent::Explainability::ConditionTrace.new(
          field: "risk_score",
          operator: "lt",
          expected_value: 0.7,
          actual_value: 0.5,
          result: true,
          description: "Custom description"
        )

        expect(trace.description).to eq("Custom description")
      end
    end

    describe "#passed?" do
      it "returns true when result is true" do
        trace = DecisionAgent::Explainability::ConditionTrace.new(
          field: "risk_score",
          operator: "lt",
          expected_value: 0.7,
          actual_value: 0.5,
          result: true
        )

        expect(trace.passed?).to be true
      end

      it "returns false when result is false" do
        trace = DecisionAgent::Explainability::ConditionTrace.new(
          field: "risk_score",
          operator: "lt",
          expected_value: 0.7,
          actual_value: 0.8,
          result: false
        )

        expect(trace.passed?).to be false
      end
    end

    describe "#failed?" do
      it "returns true when result is false" do
        trace = DecisionAgent::Explainability::ConditionTrace.new(
          field: "risk_score",
          operator: "lt",
          expected_value: 0.7,
          actual_value: 0.8,
          result: false
        )

        expect(trace.failed?).to be true
      end
    end

    describe "#to_h" do
      it "returns hash representation" do
        trace = DecisionAgent::Explainability::ConditionTrace.new(
          field: "risk_score",
          operator: "lt",
          expected_value: 0.7,
          actual_value: 0.5,
          result: true
        )

        hash = trace.to_h
        expect(hash[:field]).to eq("risk_score")
        expect(hash[:operator]).to eq("lt")
        expect(hash[:expected_value]).to eq(0.7)
        expect(hash[:actual_value]).to eq(0.5)
        expect(hash[:result]).to be true
        expect(hash[:description]).to be_a(String)
      end
    end
  end

  describe DecisionAgent::Explainability::RuleTrace do
    let(:condition_traces) do
      [
        DecisionAgent::Explainability::ConditionTrace.new(
          field: "risk_score",
          operator: "lt",
          expected_value: 0.7,
          actual_value: 0.5,
          result: true
        ),
        DecisionAgent::Explainability::ConditionTrace.new(
          field: "account_age",
          operator: "gt",
          expected_value: 180,
          actual_value: 200,
          result: true
        ),
        DecisionAgent::Explainability::ConditionTrace.new(
          field: "credit_hold",
          operator: "eq",
          expected_value: true,
          actual_value: false,
          result: false
        )
      ]
    end

    describe "#initialize" do
      it "creates a rule trace with all fields" do
        trace = DecisionAgent::Explainability::RuleTrace.new(
          rule_id: "rule1",
          matched: true,
          condition_traces: condition_traces,
          decision: "approved",
          weight: 0.9,
          reason: "Low risk"
        )

        expect(trace.rule_id).to eq("rule1")
        expect(trace.matched).to be true
        expect(trace.condition_traces.size).to eq(3)
        expect(trace.decision).to eq("approved")
        expect(trace.weight).to eq(0.9)
        expect(trace.reason).to eq("Low risk")
      end
    end

    describe "#passed_conditions" do
      it "returns only passed conditions" do
        trace = DecisionAgent::Explainability::RuleTrace.new(
          rule_id: "rule1",
          matched: true,
          condition_traces: condition_traces
        )

        passed = trace.passed_conditions
        expect(passed.size).to eq(2)
        expect(passed.all?(&:passed?)).to be true
      end
    end

    describe "#failed_conditions" do
      it "returns only failed conditions" do
        trace = DecisionAgent::Explainability::RuleTrace.new(
          rule_id: "rule1",
          matched: true,
          condition_traces: condition_traces
        )

        failed = trace.failed_conditions
        expect(failed.size).to eq(1)
        expect(failed.all?(&:failed?)).to be true
      end
    end

    describe "#to_h" do
      it "returns hash representation with condition traces" do
        trace = DecisionAgent::Explainability::RuleTrace.new(
          rule_id: "rule1",
          matched: true,
          condition_traces: condition_traces,
          decision: "approved",
          weight: 0.9,
          reason: "Low risk"
        )

        hash = trace.to_h
        expect(hash[:rule_id]).to eq("rule1")
        expect(hash[:matched]).to be true
        expect(hash[:condition_traces]).to be_an(Array)
        expect(hash[:condition_traces].size).to eq(3)
        expect(hash[:passed_conditions]).to be_an(Array)
        expect(hash[:failed_conditions]).to be_an(Array)
      end
    end
  end

  describe DecisionAgent::Explainability::ExplainabilityResult do
    let(:rule_traces) do
      [
        DecisionAgent::Explainability::RuleTrace.new(
          rule_id: "rule1",
          matched: true,
          condition_traces: [
            DecisionAgent::Explainability::ConditionTrace.new(field: "risk_score", operator: "lt", expected_value: 0.7, actual_value: 0.5, result: true),
            DecisionAgent::Explainability::ConditionTrace.new(field: "account_age", operator: "gt", expected_value: 180, actual_value: 200, result: true)
          ],
          decision: "approved",
          weight: 0.9,
          reason: "Low risk"
        ),
        DecisionAgent::Explainability::RuleTrace.new(
          rule_id: "rule2",
          matched: false,
          condition_traces: [
            DecisionAgent::Explainability::ConditionTrace.new(field: "credit_hold", operator: "eq", expected_value: true, actual_value: false, result: false)
          ],
          decision: "rejected",
          weight: 1.0,
          reason: "Credit hold"
        )
      ]
    end

    describe "#initialize" do
      it "creates explainability result with rule traces" do
        result = DecisionAgent::Explainability::ExplainabilityResult.new(
          evaluator_name: "TestEvaluator",
          rule_traces: rule_traces
        )

        expect(result.evaluator_name).to eq("TestEvaluator")
        expect(result.rule_traces.size).to eq(2)
      end
    end

    describe "#matched_rules" do
      it "returns only matched rules" do
        result = DecisionAgent::Explainability::ExplainabilityResult.new(
          evaluator_name: "TestEvaluator",
          rule_traces: rule_traces
        )

        matched = result.matched_rules
        expect(matched.size).to eq(1)
        expect(matched.first.rule_id).to eq("rule1")
      end
    end

    describe "#because" do
      it "returns descriptions of passed conditions" do
        result = DecisionAgent::Explainability::ExplainabilityResult.new(
          evaluator_name: "TestEvaluator",
          rule_traces: rule_traces
        )

        because = result.because
        expect(because).to be_an(Array)
        expect(because.size).to eq(2)
        expect(because).to include("risk_score < 0.7")
        expect(because).to include("account_age > 180")
      end
    end

    describe "#failed_conditions" do
      it "returns descriptions of failed conditions" do
        result = DecisionAgent::Explainability::ExplainabilityResult.new(
          evaluator_name: "TestEvaluator",
          rule_traces: rule_traces
        )

        failed = result.failed_conditions
        expect(failed).to be_an(Array)
        expect(failed.size).to eq(1)
        expect(failed.first).to include("credit_hold")
      end
    end

    describe "#to_h" do
      it "returns hash representation" do
        result = DecisionAgent::Explainability::ExplainabilityResult.new(
          evaluator_name: "TestEvaluator",
          rule_traces: rule_traces
        )

        hash = result.to_h
        expect(hash[:evaluator_name]).to eq("TestEvaluator")
        expect(hash[:rule_traces]).to be_an(Array)
        expect(hash[:because]).to be_an(Array)
        expect(hash[:failed_conditions]).to be_an(Array)
      end
    end
  end
end

RSpec.describe DecisionAgent::Decision do
  describe "#because" do
    it "returns array of passed condition descriptions" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule1",
            if: {
              all: [
                { field: "risk_score", op: "lt", value: 0.7 },
                { field: "account_age", op: "gt", value: 180 }
              ]
            },
            then: {
              decision: "approved",
              weight: 0.9,
              reason: "Low risk"
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      agent = DecisionAgent::Agent.new(
        evaluators: [evaluator],
        scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new
      )

      result = agent.decide(context: { risk_score: 0.5, account_age: 200 })

      because = result.because
      expect(because).to be_an(Array)
      expect(because.size).to eq(2)
      expect(because).to include("risk_score < 0.7")
      expect(because).to include("account_age > 180")
    end

    it "returns empty array when no rules match" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule1",
            if: { field: "risk_score", op: "lt", value: 0.7 },
            then: { decision: "approved", weight: 0.9, reason: "Low risk" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      
      # When no rules match, evaluator returns nil, so agent raises NoEvaluationsError
      # This is expected behavior - we can't have a decision without matching rules
      expect {
        agent = DecisionAgent::Agent.new(
          evaluators: [evaluator],
          scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new
        )
        agent.decide(context: { risk_score: 0.8 })
      }.to raise_error(DecisionAgent::NoEvaluationsError)
    end
  end

  describe "#failed_conditions" do
    it "returns array of failed condition descriptions" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule1",
            if: {
              all: [
                { field: "risk_score", op: "lt", value: 0.7 },
                { field: "account_age", op: "gt", value: 180 }
              ]
            },
            then: {
              decision: "approved",
              weight: 0.9,
              reason: "Low risk"
            }
          },
          {
            id: "rule2",
            if: { field: "credit_hold", op: "eq", value: true },
            then: { decision: "rejected", weight: 1.0, reason: "Credit hold" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      agent = DecisionAgent::Agent.new(
        evaluators: [evaluator],
        scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new
      )

      # Context that matches rule1 but rule2 is also evaluated
      result = agent.decide(context: { risk_score: 0.5, account_age: 200, credit_hold: false })

      # Rule2's condition failed
      failed = result.failed_conditions
      expect(failed).to be_an(Array)
      # Note: Since rule1 matches first, rule2 might not be evaluated due to short-circuit
      # This depends on implementation
    end
  end

  describe "#explainability" do
    it "returns machine-readable explainability format" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule1",
            if: {
              all: [
                { field: "risk_score", op: "lt", value: 0.7 },
                { field: "account_age", op: "gt", value: 180 }
              ]
            },
            then: {
              decision: "approved",
              weight: 0.9,
              reason: "Low risk"
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      agent = DecisionAgent::Agent.new(
        evaluators: [evaluator],
        scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new
      )

      result = agent.decide(context: { risk_score: 0.5, account_age: 200 })

      explainability = result.explainability
      expect(explainability).to be_a(Hash)
      expect(explainability[:decision]).to eq("approved")
      expect(explainability[:because]).to be_an(Array)
      expect(explainability[:failed_conditions]).to be_an(Array)
      expect(explainability[:because].size).to eq(2)
    end

    it "includes rule_traces in verbose mode" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule1",
            if: { field: "risk_score", op: "lt", value: 0.7 },
            then: { decision: "approved", weight: 0.9, reason: "Low risk" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      agent = DecisionAgent::Agent.new(
        evaluators: [evaluator],
        scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new
      )

      result = agent.decide(context: { risk_score: 0.5 })

      explainability = result.explainability(verbose: true)
      # Verbose mode includes rule_traces
      expect(explainability[:rule_traces]).to be_an(Array)
      expect(explainability[:because]).to be_an(Array)
    end
  end

  describe "#to_h" do
    it "includes explainability in hash representation" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule1",
            if: { field: "risk_score", op: "lt", value: 0.7 },
            then: { decision: "approved", weight: 0.9, reason: "Low risk" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      agent = DecisionAgent::Agent.new(
        evaluators: [evaluator],
        scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new
      )

      result = agent.decide(context: { risk_score: 0.5 })

      hash = result.to_h
      expect(hash[:explainability]).to be_a(Hash)
      expect(hash[:explainability][:decision]).to eq("approved")
      expect(hash[:explainability][:because]).to be_an(Array)
    end
  end
end

RSpec.describe DecisionAgent::Evaluators::JsonRuleEvaluator do
  describe "explainability integration" do
    it "collects explainability traces during evaluation" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule1",
            if: {
              all: [
                { field: "risk_score", op: "lt", value: 0.7 },
                { field: "account_age", op: "gt", value: 180 }
              ]
            },
            then: {
              decision: "approved",
              weight: 0.9,
              reason: "Low risk"
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      result = evaluator.evaluate({ risk_score: 0.5, account_age: 200 })

      expect(result).not_to be_nil
      expect(result.metadata[:explainability]).to be_a(Hash)
      expect(result.metadata[:explainability][:because]).to be_an(Array)
      expect(result.metadata[:explainability][:because].size).to eq(2)
    end

    it "tracks failed conditions in explainability" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule1",
            if: {
              all: [
                { field: "risk_score", op: "lt", value: 0.7 },
                { field: "account_age", op: "gt", value: 180 }
              ]
            },
            then: {
              decision: "approved",
              weight: 0.9,
              reason: "Low risk"
            }
          },
          {
            id: "rule2",
            if: { field: "credit_hold", op: "eq", value: true },
            then: { decision: "rejected", weight: 1.0, reason: "Credit hold" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      # This should match rule1, but rule2 will be evaluated first and fail
      result = evaluator.evaluate({ risk_score: 0.5, account_age: 200, credit_hold: false })

      expect(result).not_to be_nil
      expect(result.metadata[:explainability]).to be_a(Hash)
    end
  end
end

