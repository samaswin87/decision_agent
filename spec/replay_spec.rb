require "spec_helper"

RSpec.describe DecisionAgent::Replay do
  let(:evaluator) do
    DecisionAgent::Evaluators::StaticEvaluator.new(
      decision: "approve",
      weight: 0.8,
      reason: "Static approval"
    )
  end

  let(:agent) do
    DecisionAgent::Agent.new(evaluators: [evaluator])
  end

  describe ".run" do
    it "replays decision from audit payload in strict mode" do
      context = { user: "alice", action: "login" }
      original_result = agent.decide(context: context)

      replayed_result = DecisionAgent::Replay.run(
        original_result.audit_payload,
        strict: true
      )

      expect(replayed_result.decision).to eq(original_result.decision)
      expect(replayed_result.confidence).to be_within(0.0001).of(original_result.confidence)
    end

    it "raises ReplayMismatchError in strict mode when decision differs" do
      context = { user: "alice" }
      original_result = agent.decide(context: context)

      modified_payload = original_result.audit_payload.dup
      modified_payload[:decision] = "reject"

      expect {
        DecisionAgent::Replay.run(modified_payload, strict: true)
      }.to raise_error(DecisionAgent::ReplayMismatchError) do |error|
        expect(error.differences).to include(/decision mismatch/)
        expect(error.expected[:decision]).to eq("reject")
        expect(error.actual[:decision]).to eq("approve")
      end
    end

    it "raises ReplayMismatchError in strict mode when confidence differs" do
      context = { user: "alice" }
      original_result = agent.decide(context: context)

      modified_payload = original_result.audit_payload.dup
      modified_payload[:confidence] = 0.5

      expect {
        DecisionAgent::Replay.run(modified_payload, strict: true)
      }.to raise_error(DecisionAgent::ReplayMismatchError) do |error|
        expect(error.differences).to include(/confidence mismatch/)
      end
    end

    it "allows differences in non-strict mode" do
      context = { user: "alice" }
      original_result = agent.decide(context: context)

      modified_payload = original_result.audit_payload.dup
      modified_payload[:decision] = "reject"

      expect {
        DecisionAgent::Replay.run(modified_payload, strict: false)
      }.not_to raise_error
    end

    it "logs differences in non-strict mode" do
      context = { user: "alice" }
      original_result = agent.decide(context: context)

      modified_payload = original_result.audit_payload.dup
      modified_payload[:decision] = "reject"

      expect {
        DecisionAgent::Replay.run(modified_payload, strict: false)
      }.to output(/Decision changed/).to_stderr
    end

    it "validates required fields in audit payload" do
      invalid_payload = { context: {} }

      expect {
        DecisionAgent::Replay.run(invalid_payload, strict: true)
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /missing required key/)
    end

    it "reconstructs evaluations from audit payload" do
      eval1 = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.7,
        reason: "Eval 1",
        name: "Evaluator1"
      )
      eval2 = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.9,
        reason: "Eval 2",
        name: "Evaluator2"
      )

      multi_agent = DecisionAgent::Agent.new(evaluators: [eval1, eval2])
      original_result = multi_agent.decide(context: { user: "bob" })

      replayed_result = DecisionAgent::Replay.run(
        original_result.audit_payload,
        strict: true
      )

      expect(replayed_result.evaluations.size).to eq(2)
      expect(replayed_result.evaluations.map(&:evaluator_name)).to match_array(["Evaluator1", "Evaluator2"])
    end

    it "uses correct scoring strategy from audit payload" do
      max_weight_agent = DecisionAgent::Agent.new(
        evaluators: [evaluator],
        scoring_strategy: DecisionAgent::Scoring::MaxWeight.new
      )

      original_result = max_weight_agent.decide(context: { user: "charlie" })

      expect(original_result.audit_payload[:scoring_strategy]).to include("MaxWeight")

      replayed_result = DecisionAgent::Replay.run(
        original_result.audit_payload,
        strict: true
      )

      expect(replayed_result.decision).to eq(original_result.decision)
    end

    it "handles symbol and string keys in audit payload" do
      context = { user: "alice" }
      original_result = agent.decide(context: context)

      string_key_payload = JSON.parse(JSON.generate(original_result.audit_payload))

      replayed_result = DecisionAgent::Replay.run(
        string_key_payload,
        strict: true
      )

      expect(replayed_result.decision).to eq(original_result.decision)
    end

    it "preserves feedback in replay" do
      context = { user: "alice" }
      feedback = { source: "manual_override" }

      original_result = agent.decide(context: context, feedback: feedback)

      replayed_result = DecisionAgent::Replay.run(
        original_result.audit_payload,
        strict: true
      )

      expect(replayed_result.audit_payload[:feedback]).to eq(feedback)
    end
  end

  describe "deterministic replay" do
    it "produces identical results for identical inputs across multiple replays" do
      context = { user: "alice", priority: "high" }
      original_result = agent.decide(context: context)

      results = 5.times.map do
        DecisionAgent::Replay.run(original_result.audit_payload, strict: true)
      end

      results.each do |result|
        expect(result.decision).to eq(original_result.decision)
        expect(result.confidence).to be_within(0.0001).of(original_result.confidence)
      end
    end
  end

  describe "complex scenario replay" do
    it "replays decisions from JSON rule evaluators" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "high_priority",
            if: { field: "priority", op: "eq", value: "high" },
            then: { decision: "escalate", weight: 0.9, reason: "High priority issue" }
          }
        ]
      }

      json_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      json_agent = DecisionAgent::Agent.new(evaluators: [json_evaluator])

      context = { priority: "high", user: "alice" }
      original_result = json_agent.decide(context: context)

      replayed_result = DecisionAgent::Replay.run(
        original_result.audit_payload,
        strict: true
      )

      expect(replayed_result.decision).to eq("escalate")
      expect(replayed_result.confidence).to be_within(0.0001).of(original_result.confidence)
    end
  end
end
