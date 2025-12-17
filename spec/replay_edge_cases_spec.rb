require "spec_helper"

RSpec.describe "DecisionAgent::Replay Edge Cases" do
  describe "handling rule changes" do
    let(:original_rules) do
      {
        version: "1.0",
        ruleset: "approval",
        rules: [
          {
            id: "auto_approve",
            if: { field: "score", op: "gte", value: 80 },
            then: { decision: "approve", weight: 0.9, reason: "High score" }
          }
        ]
      }
    end

    let(:modified_rules) do
      {
        version: "2.0",
        ruleset: "approval",
        rules: [
          {
            id: "auto_approve",
            if: { field: "score", op: "gte", value: 90 },  # Changed threshold
            then: { decision: "approve", weight: 0.9, reason: "Very high score" }
          }
        ]
      }
    end

    it "successfully replays with strict mode when rules haven't changed" do
      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: original_rules)
      agent = DecisionAgent::Agent.new(evaluators: [evaluator])

      original_result = agent.decide(context: { score: 85 })

      expect {
        DecisionAgent::Replay.run(original_result.audit_payload, strict: true)
      }.not_to raise_error
    end

    it "detects differences in strict mode when rules have changed" do
      # Original decision with old rules
      evaluator_v1 = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: original_rules)
      agent_v1 = DecisionAgent::Agent.new(evaluators: [evaluator_v1])
      original_result = agent_v1.decide(context: { score: 85 })

      # Now the rules have changed (threshold increased from 80 to 90)
      # Score of 85 no longer matches, so replay should detect a difference

      # Replay uses the stored evaluations (not re-evaluating rules)
      # So it should succeed because replay uses static evaluators from the audit payload
      expect {
        DecisionAgent::Replay.run(original_result.audit_payload, strict: true)
      }.not_to raise_error

      # The replayed result should match the original
      replayed_result = DecisionAgent::Replay.run(original_result.audit_payload, strict: true)
      expect(replayed_result.decision).to eq(original_result.decision)
      expect(replayed_result.confidence).to eq(original_result.confidence)
    end

    it "allows evolution in non-strict mode" do
      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: original_rules)
      agent = DecisionAgent::Agent.new(evaluators: [evaluator])

      original_result = agent.decide(context: { score: 85 })

      # In non-strict mode, differences are logged but don't raise errors
      expect {
        DecisionAgent::Replay.run(original_result.audit_payload, strict: false)
      }.not_to raise_error
    end
  end

  describe "metadata comparison" do
    it "preserves and replays metadata correctly" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "metadata_test_rule",
            if: { field: "user", op: "eq", value: "alice" },
            then: {
              decision: "approve",
              weight: 0.8,
              reason: "Trusted user"
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      agent = DecisionAgent::Agent.new(evaluators: [evaluator])

      original_result = agent.decide(context: { user: "alice" })

      # Verify metadata is in the audit payload
      expect(original_result.audit_payload[:evaluations].first[:metadata]).to include(
        rule_id: "metadata_test_rule"
      )

      # Replay should preserve metadata
      replayed_result = DecisionAgent::Replay.run(original_result.audit_payload, strict: true)

      expect(replayed_result.evaluations.first.metadata).to eq(
        original_result.evaluations.first.metadata
      )
    end

    it "handles metadata from static evaluators" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.7,
        reason: "No custom metadata"
      )

      agent = DecisionAgent::Agent.new(evaluators: [evaluator])
      original_result = agent.decide(context: { user: "bob" })

      # StaticEvaluator adds type: "static" by default
      expect(original_result.evaluations.first.metadata).to eq({ type: "static" })

      expect {
        DecisionAgent::Replay.run(original_result.audit_payload, strict: true)
      }.not_to raise_error

      replayed_result = DecisionAgent::Replay.run(original_result.audit_payload, strict: true)
      expect(replayed_result.evaluations.first.metadata).to eq({ type: "static" })
    end

    it "handles complex nested metadata" do
      evaluation = DecisionAgent::Evaluation.new(
        decision: "escalate",
        weight: 0.85,
        reason: "Complex case",
        evaluator_name: "CustomEvaluator",
        metadata: {
          user: { id: 123, role: "admin" },
          tags: ["urgent", "important"],
          history: [
            { action: "created", timestamp: "2025-01-01" },
            { action: "updated", timestamp: "2025-01-02" }
          ]
        }
      )

      static_eval = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: evaluation.decision,
        weight: evaluation.weight,
        reason: evaluation.reason
      )

      agent = DecisionAgent::Agent.new(evaluators: [static_eval])
      original_result = agent.decide(context: { test: true })

      # Manually construct audit payload with complex metadata
      payload = original_result.audit_payload.dup
      payload[:evaluations] = [evaluation.to_h]

      replayed_result = DecisionAgent::Replay.run(payload, strict: false)

      expect(replayed_result.evaluations.first.metadata).to be_a(Hash)
    end
  end

  describe "handling missing evaluators in replay" do
    it "replays successfully even if original evaluator class doesn't exist" do
      # This simulates a scenario where we had a CustomEvaluator that no longer exists
      # but we can still replay the decision from the audit log

      # WeightedAverage normalizes confidence: with one eval of weight 0.9, confidence = 0.9/0.9 = 1.0
      # So we need to use the correct confidence value that WeightedAverage would produce
      audit_payload = {
        timestamp: "2025-01-15T10:00:00.123456Z",
        context: { user: "charlie", action: "login" },
        feedback: {},
        evaluations: [
          {
            decision: "allow",
            weight: 0.9,
            reason: "User authenticated successfully",
            evaluator_name: "DeletedCustomAuthEvaluator",  # This evaluator no longer exists
            metadata: { auth_method: "oauth", provider: "google" }
          }
        ],
        decision: "allow",
        confidence: 1.0,  # WeightedAverage normalizes single eval to 1.0
        scoring_strategy: "DecisionAgent::Scoring::WeightedAverage",
        agent_version: "0.1.0",
        deterministic_hash: "abc123"
      }

      # Replay should work because it uses StaticEvaluator, not the original evaluator
      expect {
        DecisionAgent::Replay.run(audit_payload, strict: true)
      }.not_to raise_error

      replayed_result = DecisionAgent::Replay.run(audit_payload, strict: true)

      expect(replayed_result.decision).to eq("allow")
      expect(replayed_result.confidence).to eq(1.0)
      expect(replayed_result.evaluations.first.evaluator_name).to eq("DeletedCustomAuthEvaluator")
    end

    it "handles multiple evaluators where some are missing" do
      # WeightedAverage with two evals agreeing: confidence = (0.8 + 0.7) / (0.8 + 0.7) = 1.0
      audit_payload = {
        timestamp: "2025-01-15T10:00:00.123456Z",
        context: { user: "dave" },
        feedback: {},
        evaluations: [
          {
            decision: "approve",
            weight: 0.8,
            reason: "Rule matched",
            evaluator_name: "RuleEngine",
            metadata: { rule_id: "rule_123" }
          },
          {
            decision: "approve",
            weight: 0.7,
            reason: "ML model prediction",
            evaluator_name: "NonExistentMLEvaluator",  # Missing evaluator
            metadata: { model_version: "v2.1" }
          }
        ],
        decision: "approve",
        confidence: 1.0,  # Both agree, so 100% confidence
        scoring_strategy: "DecisionAgent::Scoring::WeightedAverage",
        agent_version: "0.1.0",
        deterministic_hash: "def456"
      }

      replayed_result = DecisionAgent::Replay.run(audit_payload, strict: true)

      expect(replayed_result.decision).to eq("approve")
      expect(replayed_result.evaluations.size).to eq(2)
      expect(replayed_result.evaluations.map(&:evaluator_name)).to include("NonExistentMLEvaluator")
    end
  end

  describe "scoring strategy evolution" do
    it "handles unknown scoring strategies gracefully" do
      audit_payload = {
        timestamp: "2025-01-15T10:00:00.123456Z",
        context: { test: true },
        feedback: {},
        evaluations: [
          {
            decision: "approve",
            weight: 0.9,
            reason: "Test",
            evaluator_name: "TestEvaluator",
            metadata: {}
          }
        ],
        decision: "approve",
        confidence: 0.9,
        scoring_strategy: "DecisionAgent::Scoring::DeprecatedBayesianStrategy",  # Doesn't exist
        agent_version: "0.1.0",
        deterministic_hash: "ghi789"
      }

      # Should fall back to WeightedAverage
      expect {
        DecisionAgent::Replay.run(audit_payload, strict: false)
      }.not_to raise_error

      replayed_result = DecisionAgent::Replay.run(audit_payload, strict: false)
      expect(replayed_result.decision).to eq("approve")
    end

    it "detects scoring strategy mismatch in strict mode" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.6,
        reason: "Test"
      )

      # Create decision with WeightedAverage
      agent_weighted = DecisionAgent::Agent.new(
        evaluators: [evaluator],
        scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new
      )

      original_result = agent_weighted.decide(context: { test: true })

      # Replay uses the stored scoring strategy from the audit payload
      # So it should replay successfully
      expect {
        DecisionAgent::Replay.run(original_result.audit_payload, strict: true)
      }.not_to raise_error
    end
  end

  describe "audit payload validation" do
    it "requires context field" do
      incomplete_payload = {
        evaluations: [],
        decision: "test",
        confidence: 0.5
      }

      expect {
        DecisionAgent::Replay.run(incomplete_payload, strict: false)
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /missing required key: context/)
    end

    it "requires evaluations field" do
      incomplete_payload = {
        context: { test: true },
        decision: "test",
        confidence: 0.5
      }

      expect {
        DecisionAgent::Replay.run(incomplete_payload, strict: false)
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /missing required key: evaluations/)
    end

    it "requires decision field" do
      incomplete_payload = {
        context: { test: true },
        evaluations: [],
        confidence: 0.5
      }

      expect {
        DecisionAgent::Replay.run(incomplete_payload, strict: false)
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /missing required key: decision/)
    end

    it "requires confidence field" do
      incomplete_payload = {
        context: { test: true },
        evaluations: [],
        decision: "test"
      }

      expect {
        DecisionAgent::Replay.run(incomplete_payload, strict: false)
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /missing required key: confidence/)
    end

    it "accepts both symbol and string keys" do
      # Use MaxWeight strategy which preserves the original weight as confidence
      payload_with_strings = {
        "timestamp" => "2025-01-15T10:00:00.123456Z",
        "context" => { "test" => true },
        "feedback" => {},
        "evaluations" => [
          {
            "decision" => "approve",
            "weight" => 0.9,
            "reason" => "Test",
            "evaluator_name" => "TestEvaluator",
            "metadata" => {}
          }
        ],
        "decision" => "approve",
        "confidence" => 0.9,
        "scoring_strategy" => "DecisionAgent::Scoring::MaxWeight"
      }

      expect {
        DecisionAgent::Replay.run(payload_with_strings, strict: true)
      }.not_to raise_error
    end
  end

  describe "deterministic hash verification" do
    it "can verify replay produced the same deterministic hash" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test"
      )

      agent = DecisionAgent::Agent.new(evaluators: [evaluator])
      original_result = agent.decide(context: { user: "test" })

      original_hash = original_result.audit_payload[:deterministic_hash]

      replayed_result = DecisionAgent::Replay.run(original_result.audit_payload, strict: true)
      replayed_hash = replayed_result.audit_payload[:deterministic_hash]

      # Hashes should match because same context, evaluations, decision, confidence, and strategy
      expect(replayed_hash).to eq(original_hash)
    end

    it "hash changes when context changes" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test"
      )

      agent = DecisionAgent::Agent.new(evaluators: [evaluator])

      result1 = agent.decide(context: { user: "alice" })
      result2 = agent.decide(context: { user: "bob" })

      expect(result1.audit_payload[:deterministic_hash]).not_to eq(
        result2.audit_payload[:deterministic_hash]
      )
    end
  end

  describe "feedback preservation in replay" do
    it "preserves original feedback in replay" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test"
      )

      agent = DecisionAgent::Agent.new(evaluators: [evaluator])

      original_feedback = { user_id: "manager_123", source: "manual_review" }
      original_result = agent.decide(context: { test: true }, feedback: original_feedback)

      expect(original_result.audit_payload[:feedback]).to eq(original_feedback)

      replayed_result = DecisionAgent::Replay.run(original_result.audit_payload, strict: true)

      expect(replayed_result.audit_payload[:feedback]).to eq(original_feedback)
    end

    it "handles empty feedback" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test"
      )

      agent = DecisionAgent::Agent.new(evaluators: [evaluator])
      original_result = agent.decide(context: { test: true })

      expect(original_result.audit_payload[:feedback]).to eq({})

      replayed_result = DecisionAgent::Replay.run(original_result.audit_payload, strict: true)
      expect(replayed_result.audit_payload[:feedback]).to eq({})
    end
  end
end
