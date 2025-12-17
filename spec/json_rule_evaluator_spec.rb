require "spec_helper"

RSpec.describe DecisionAgent::Evaluators::JsonRuleEvaluator do
  describe "basic rule matching" do
    it "matches simple equality rule" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "status", op: "eq", value: "active" },
            then: { decision: "approve", weight: 0.8, reason: "Status is active" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ status: "active" })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("approve")
      expect(evaluation.weight).to eq(0.8)
      expect(evaluation.reason).to eq("Status is active")
      expect(evaluation.metadata[:rule_id]).to eq("rule_1")
    end

    it "returns nil when no rules match" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "status", op: "eq", value: "active" },
            then: { decision: "approve" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ status: "inactive" })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).to be_nil
    end

    it "matches first rule when multiple rules match" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "priority", op: "eq", value: "high" },
            then: { decision: "escalate" }
          },
          {
            id: "rule_2",
            if: { field: "priority", op: "eq", value: "high" },
            then: { decision: "notify" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ priority: "high" })

      evaluation = evaluator.evaluate(context)

      expect(evaluation.decision).to eq("escalate")
      expect(evaluation.metadata[:rule_id]).to eq("rule_1")
    end
  end

  describe "all/any conditions" do
    it "matches 'all' condition when all sub-conditions are true" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: {
              all: [
                { field: "priority", op: "eq", value: "high" },
                { field: "hours", op: "gte", value: 4 }
              ]
            },
            then: { decision: "notify" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ priority: "high", hours: 5 })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("notify")
    end

    it "does not match 'all' when one sub-condition fails" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: {
              all: [
                { field: "priority", op: "eq", value: "high" },
                { field: "hours", op: "gte", value: 4 }
              ]
            },
            then: { decision: "notify" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ priority: "high", hours: 2 })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).to be_nil
    end

    it "matches 'any' condition when at least one sub-condition is true" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: {
              any: [
                { field: "priority", op: "eq", value: "critical" },
                { field: "hours", op: "gte", value: 24 }
              ]
            },
            then: { decision: "escalate" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ priority: "low", hours: 30 })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("escalate")
    end

    it "does not match 'any' when all sub-conditions fail" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: {
              any: [
                { field: "priority", op: "eq", value: "critical" },
                { field: "hours", op: "gte", value: 24 }
              ]
            },
            then: { decision: "escalate" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ priority: "low", hours: 5 })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).to be_nil
    end
  end

  describe "comparison operators" do
    it "supports gt (greater than)" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "score", op: "gt", value: 80 },
            then: { decision: "pass" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)

      context1 = DecisionAgent::Context.new({ score: 85 })
      context2 = DecisionAgent::Context.new({ score: 80 })

      expect(evaluator.evaluate(context1)).not_to be_nil
      expect(evaluator.evaluate(context2)).to be_nil
    end

    it "supports gte (greater than or equal)" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "score", op: "gte", value: 80 },
            then: { decision: "pass" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)

      context1 = DecisionAgent::Context.new({ score: 80 })
      context2 = DecisionAgent::Context.new({ score: 79 })

      expect(evaluator.evaluate(context1)).not_to be_nil
      expect(evaluator.evaluate(context2)).to be_nil
    end

    it "supports lt (less than)" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "temperature", op: "lt", value: 32 },
            then: { decision: "freeze" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)

      context1 = DecisionAgent::Context.new({ temperature: 30 })
      context2 = DecisionAgent::Context.new({ temperature: 32 })

      expect(evaluator.evaluate(context1)).not_to be_nil
      expect(evaluator.evaluate(context2)).to be_nil
    end

    it "supports lte (less than or equal)" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "temperature", op: "lte", value: 32 },
            then: { decision: "freeze" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)

      context1 = DecisionAgent::Context.new({ temperature: 32 })
      context2 = DecisionAgent::Context.new({ temperature: 33 })

      expect(evaluator.evaluate(context1)).not_to be_nil
      expect(evaluator.evaluate(context2)).to be_nil
    end

    it "supports neq (not equal)" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "status", op: "neq", value: "closed" },
            then: { decision: "process" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)

      context1 = DecisionAgent::Context.new({ status: "open" })
      context2 = DecisionAgent::Context.new({ status: "closed" })

      expect(evaluator.evaluate(context1)).not_to be_nil
      expect(evaluator.evaluate(context2)).to be_nil
    end

    it "supports in (array membership)" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "status", op: "in", value: ["open", "pending", "review"] },
            then: { decision: "active" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)

      context1 = DecisionAgent::Context.new({ status: "pending" })
      context2 = DecisionAgent::Context.new({ status: "closed" })

      expect(evaluator.evaluate(context1)).not_to be_nil
      expect(evaluator.evaluate(context2)).to be_nil
    end

    it "supports present (field exists and not empty)" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "assignee", op: "present" },
            then: { decision: "assigned" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)

      context1 = DecisionAgent::Context.new({ assignee: "alice" })
      context2 = DecisionAgent::Context.new({ assignee: nil })
      context3 = DecisionAgent::Context.new({ assignee: "" })
      context4 = DecisionAgent::Context.new({})

      expect(evaluator.evaluate(context1)).not_to be_nil
      expect(evaluator.evaluate(context2)).to be_nil
      expect(evaluator.evaluate(context3)).to be_nil
      expect(evaluator.evaluate(context4)).to be_nil
    end

    it "supports blank (field missing, nil, or empty)" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "description", op: "blank" },
            then: { decision: "needs_description" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)

      context1 = DecisionAgent::Context.new({ description: "" })
      context2 = DecisionAgent::Context.new({ description: nil })
      context3 = DecisionAgent::Context.new({})
      context4 = DecisionAgent::Context.new({ description: "valid" })

      expect(evaluator.evaluate(context1)).not_to be_nil
      expect(evaluator.evaluate(context2)).not_to be_nil
      expect(evaluator.evaluate(context3)).not_to be_nil
      expect(evaluator.evaluate(context4)).to be_nil
    end
  end

  describe "nested field access" do
    it "supports dot notation for nested fields" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "user.role", op: "eq", value: "admin" },
            then: { decision: "allow" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)

      context1 = DecisionAgent::Context.new({ user: { role: "admin" } })
      context2 = DecisionAgent::Context.new({ user: { role: "user" } })

      expect(evaluator.evaluate(context1)).not_to be_nil
      expect(evaluator.evaluate(context2)).to be_nil
    end

    it "handles missing nested fields gracefully" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "user.role", op: "eq", value: "admin" },
            then: { decision: "allow" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)

      context1 = DecisionAgent::Context.new({})
      context2 = DecisionAgent::Context.new({ user: nil })

      expect(evaluator.evaluate(context1)).to be_nil
      expect(evaluator.evaluate(context2)).to be_nil
    end
  end

  describe "invalid DSL handling" do
    it "raises InvalidRuleDslError for malformed JSON" do
      expect {
        DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: "{ invalid json")
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /Invalid JSON/)
    end

    it "raises InvalidRuleDslError when version is missing" do
      rules = { rules: [] }

      expect {
        DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /version/)
    end

    it "raises InvalidRuleDslError when rules array is missing" do
      rules = { version: "1.0" }

      expect {
        DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /rules/)
    end

    it "raises InvalidRuleDslError when rule is missing id" do
      rules = {
        version: "1.0",
        rules: [
          {
            if: { field: "status", op: "eq", value: "active" },
            then: { decision: "approve" }
          }
        ]
      }

      expect {
        DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /Missing required field 'id'/)
    end

    it "raises InvalidRuleDslError when rule is missing if clause" do
      rules = {
        version: "1.0",
        rules: [
          {
            id: "rule_1",
            then: { decision: "approve" }
          }
        ]
      }

      expect {
        DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /Missing required field 'if'/)
    end

    it "raises InvalidRuleDslError when rule is missing then clause" do
      rules = {
        version: "1.0",
        rules: [
          {
            id: "rule_1",
            if: { field: "status", op: "eq", value: "active" }
          }
        ]
      }

      expect {
        DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /Missing required field 'then'/)
    end

    it "raises InvalidRuleDslError when then clause is missing decision" do
      rules = {
        version: "1.0",
        rules: [
          {
            id: "rule_1",
            if: { field: "status", op: "eq", value: "active" },
            then: { weight: 0.8 }
          }
        ]
      }

      expect {
        DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /Missing required field 'decision'/)
    end
  end

  describe "default values" do
    it "uses default weight of 1.0 when not specified" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "status", op: "eq", value: "active" },
            then: { decision: "approve" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ status: "active" })

      evaluation = evaluator.evaluate(context)

      expect(evaluation.weight).to eq(1.0)
    end

    it "uses default reason when not specified" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: { field: "status", op: "eq", value: "active" },
            then: { decision: "approve" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ status: "active" })

      evaluation = evaluator.evaluate(context)

      expect(evaluation.reason).to eq("Rule matched")
    end
  end

  describe "complex nested conditions" do
    it "handles nested all/any combinations" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: {
              all: [
                { field: "priority", op: "eq", value: "high" },
                {
                  any: [
                    { field: "hours", op: "gte", value: 24 },
                    { field: "escalated", op: "eq", value: true }
                  ]
                }
              ]
            },
            then: { decision: "urgent" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)

      context1 = DecisionAgent::Context.new({ priority: "high", hours: 30, escalated: false })
      context2 = DecisionAgent::Context.new({ priority: "high", hours: 5, escalated: true })
      context3 = DecisionAgent::Context.new({ priority: "low", hours: 30, escalated: true })

      expect(evaluator.evaluate(context1)).not_to be_nil
      expect(evaluator.evaluate(context2)).not_to be_nil
      expect(evaluator.evaluate(context3)).to be_nil
    end
  end
end
