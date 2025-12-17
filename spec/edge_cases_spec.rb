require "spec_helper"

RSpec.describe "Edge Cases" do
  describe "missing fields in context" do
    it "handles missing fields gracefully in rule evaluation" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "missing_field", op: "eq", value: "value" },
            then: { decision: "approve" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({})

      evaluation = evaluator.evaluate(context)

      expect(evaluation).to be_nil
    end

    it "handles nil values in comparisons" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "value", op: "gt", value: 10 },
            then: { decision: "approve" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ value: nil })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).to be_nil
    end
  end

  describe "confidence edge cases" do
    it "raises error when confidence exceeds 1.0" do
      expect {
        DecisionAgent::Decision.new(
          decision: "test",
          confidence: 1.5,
          explanations: [],
          evaluations: [],
          audit_payload: {}
        )
      }.to raise_error(DecisionAgent::InvalidConfidenceError)
    end

    it "raises error when confidence is negative" do
      expect {
        DecisionAgent::Decision.new(
          decision: "test",
          confidence: -0.1,
          explanations: [],
          evaluations: [],
          audit_payload: {}
        )
      }.to raise_error(DecisionAgent::InvalidConfidenceError)
    end

    it "accepts confidence at boundary values" do
      decision0 = DecisionAgent::Decision.new(
        decision: "test",
        confidence: 0.0,
        explanations: [],
        evaluations: [],
        audit_payload: {}
      )

      decision1 = DecisionAgent::Decision.new(
        decision: "test",
        confidence: 1.0,
        explanations: [],
        evaluations: [],
        audit_payload: {}
      )

      expect(decision0.confidence).to eq(0.0)
      expect(decision1.confidence).to eq(1.0)
    end
  end

  describe "weight edge cases" do
    it "raises error when weight exceeds 1.0" do
      expect {
        DecisionAgent::Evaluation.new(
          decision: "test",
          weight: 1.5,
          reason: "test",
          evaluator_name: "test"
        )
      }.to raise_error(DecisionAgent::InvalidWeightError)
    end

    it "raises error when weight is negative" do
      expect {
        DecisionAgent::Evaluation.new(
          decision: "test",
          weight: -0.1,
          reason: "test",
          evaluator_name: "test"
        )
      }.to raise_error(DecisionAgent::InvalidWeightError)
    end

    it "accepts weight at boundary values" do
      eval0 = DecisionAgent::Evaluation.new(
        decision: "test",
        weight: 0.0,
        reason: "test",
        evaluator_name: "test"
      )

      eval1 = DecisionAgent::Evaluation.new(
        decision: "test",
        weight: 1.0,
        reason: "test",
        evaluator_name: "test"
      )

      expect(eval0.weight).to eq(0.0)
      expect(eval1.weight).to eq(1.0)
    end
  end

  describe "empty arrays and collections" do
    it "handles rules with empty 'all' conditions" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { all: [] },
            then: { decision: "approve" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({})

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
    end

    it "handles rules with empty 'any' conditions" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { any: [] },
            then: { decision: "approve" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({})

      evaluation = evaluator.evaluate(context)

      expect(evaluation).to be_nil
    end
  end

  describe "type mismatches in comparisons" do
    it "handles type mismatches in numeric comparisons" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "value", op: "gt", value: 10 },
            then: { decision: "approve" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ value: "not_a_number" })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).to be_nil
    end
  end

  describe "immutability" do
    it "freezes context data to prevent modification" do
      context = DecisionAgent::Context.new({ user: "alice" })

      expect {
        context.to_h[:user] = "bob"
      }.to raise_error(FrozenError)
    end

    it "freezes evaluation fields" do
      evaluation = DecisionAgent::Evaluation.new(
        decision: "approve",
        weight: 0.8,
        reason: "test",
        evaluator_name: "test"
      )

      expect(evaluation.decision).to be_frozen
      expect(evaluation.reason).to be_frozen
      expect(evaluation.evaluator_name).to be_frozen
    end

    it "freezes decision fields" do
      decision = DecisionAgent::Decision.new(
        decision: "approve",
        confidence: 0.8,
        explanations: ["test"],
        evaluations: [],
        audit_payload: {}
      )

      expect(decision.decision).to be_frozen
      expect(decision.explanations).to be_frozen
    end
  end

  describe "special characters and unicode" do
    it "handles unicode in context values" do
      context = DecisionAgent::Context.new({ user: "用户", message: "Hello 世界" })

      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve")
      agent = DecisionAgent::Agent.new(evaluators: [evaluator])

      result = agent.decide(context: context)

      expect(result.audit_payload[:context][:user]).to eq("用户")
    end

    it "handles special characters in rule values" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "symbol", op: "eq", value: "@#$%^&*()" },
            then: { decision: "special" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ symbol: "@#$%^&*()" })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("special")
    end
  end

  describe "very large numbers and values" do
    it "handles large numeric values in comparisons" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "amount", op: "gte", value: 1_000_000_000 },
            then: { decision: "large_amount" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ amount: 5_000_000_000 })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("large_amount")
    end
  end

  describe "deeply nested context" do
    it "handles deeply nested field access" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "a.b.c.d.e", op: "eq", value: "deep" },
            then: { decision: "found_deep" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({
        a: {
          b: {
            c: {
              d: {
                e: "deep"
              }
            }
          }
        }
      })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("found_deep")
    end
  end

  describe "audit adapter errors" do
    it "propagates errors from audit adapter" do
      failing_adapter = Class.new(DecisionAgent::Audit::Adapter) do
        def record(decision, context)
          raise StandardError, "Audit failed"
        end
      end

      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve")
      agent = DecisionAgent::Agent.new(
        evaluators: [evaluator],
        audit_adapter: failing_adapter.new
      )

      expect {
        agent.decide(context: {})
      }.to raise_error(StandardError, "Audit failed")
    end
  end
end
