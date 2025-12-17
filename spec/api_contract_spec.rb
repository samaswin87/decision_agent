require "spec_helper"

RSpec.describe "DecisionAgent API Contracts" do
  describe "Evaluator Interface Contract" do
    let(:context) { DecisionAgent::Context.new(user: "alice", priority: "high") }
    let(:feedback) { { source: "test" } }

    describe "Base evaluator interface" do
      it "defines evaluate(context, feedback: {}) method signature" do
        evaluator = DecisionAgent::Evaluators::Base.new
        expect(evaluator).to respond_to(:evaluate)

        # Should accept context and optional feedback
        expect { evaluator.evaluate(context) }.to raise_error(NotImplementedError)
        expect { evaluator.evaluate(context, feedback: feedback) }.to raise_error(NotImplementedError)
      end
    end

    describe "evaluate method return contract" do
      context "when returning an Evaluation" do
        let(:evaluator) do
          DecisionAgent::Evaluators::StaticEvaluator.new(
            decision: "approve",
            weight: 0.8,
            reason: "Test reason"
          )
        end

        it "returns DecisionAgent::Evaluation object" do
          result = evaluator.evaluate(context, feedback: feedback)
          expect(result).to be_a(DecisionAgent::Evaluation)
        end

        it "includes required evaluator_name field" do
          result = evaluator.evaluate(context, feedback: feedback)
          expect(result.evaluator_name).to be_a(String)
          expect(result.evaluator_name).not_to be_empty
        end

        it "includes required decision field" do
          result = evaluator.evaluate(context, feedback: feedback)
          expect(result.decision).to be_a(String)
          expect(result.decision).not_to be_empty
        end

        it "includes required weight field (0.0-1.0)" do
          result = evaluator.evaluate(context, feedback: feedback)
          expect(result.weight).to be_a(Float)
          expect(result.weight).to be >= 0.0
          expect(result.weight).to be <= 1.0
        end

        it "includes required reason field" do
          result = evaluator.evaluate(context, feedback: feedback)
          expect(result.reason).to be_a(String)
          expect(result.reason).not_to be_empty
        end

        it "includes metadata field (defaults to {})" do
          result = evaluator.evaluate(context, feedback: feedback)
          expect(result.metadata).to be_a(Hash)
        end

        it "records rule_id in metadata for rule-based evaluators" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "test_rule_123",
                if: { field: "priority", op: "eq", value: "high" },
                then: { decision: "escalate", weight: 0.9, reason: "High priority" }
              }
            ]
          }

          rule_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          result = rule_evaluator.evaluate(context, feedback: feedback)

          expect(result.metadata).to have_key(:rule_id)
          expect(result.metadata[:rule_id]).to eq("test_rule_123")
        end
      end

      context "when no decision can be made" do
        it "returns nil" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "no_match",
                if: { field: "priority", op: "eq", value: "impossible" },
                then: { decision: "none", weight: 0.5, reason: "Won't match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          result = evaluator.evaluate(context, feedback: feedback)

          expect(result).to be_nil
        end
      end
    end

    describe "weight bounds validation" do
      it "rejects weight < 0.0" do
        expect {
          DecisionAgent::Evaluation.new(
            decision: "test",
            weight: -0.1,
            reason: "test",
            evaluator_name: "Test"
          )
        }.to raise_error(DecisionAgent::InvalidWeightError, /must be between 0.0 and 1.0/)
      end

      it "rejects weight > 1.0" do
        expect {
          DecisionAgent::Evaluation.new(
            decision: "test",
            weight: 1.1,
            reason: "test",
            evaluator_name: "Test"
          )
        }.to raise_error(DecisionAgent::InvalidWeightError, /must be between 0.0 and 1.0/)
      end

      it "accepts weight = 0.0" do
        expect {
          DecisionAgent::Evaluation.new(
            decision: "test",
            weight: 0.0,
            reason: "test",
            evaluator_name: "Test"
          )
        }.not_to raise_error
      end

      it "accepts weight = 1.0" do
        expect {
          DecisionAgent::Evaluation.new(
            decision: "test",
            weight: 1.0,
            reason: "test",
            evaluator_name: "Test"
          )
        }.not_to raise_error
      end
    end

    describe "reason handling" do
      it "converts nil reason to empty string" do
        evaluation = DecisionAgent::Evaluation.new(
          decision: "test",
          weight: 0.5,
          reason: nil,
          evaluator_name: "Test"
        )

        expect(evaluation.reason).to eq("")
      end

      it "converts non-string reason to string" do
        evaluation = DecisionAgent::Evaluation.new(
          decision: "test",
          weight: 0.5,
          reason: 123,
          evaluator_name: "Test"
        )

        expect(evaluation.reason).to eq("123")
      end

      it "requires reason parameter to be provided" do
        expect {
          DecisionAgent::Evaluation.new(
            decision: "test",
            weight: 0.5,
            evaluator_name: "Test"
          )
        }.to raise_error(ArgumentError, /missing keyword.*reason/)
      end
    end
  end

  describe "Decision Object API Contract" do
    let(:evaluator) do
      DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.85,
        reason: "Test approval"
      )
    end

    let(:agent) do
      DecisionAgent::Agent.new(
        evaluators: [evaluator],
        scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new,
        audit_adapter: DecisionAgent::Audit::NullAdapter.new
      )
    end

    let(:context) { { user: "bob", priority: "medium" } }
    let(:result) { agent.decide(context: context) }

    describe "standardized API" do
      it "exposes decision as string" do
        expect(result.decision).to be_a(String)
        expect(result.decision).to eq("approve")
      end

      it "exposes confidence as float (0.0-1.0)" do
        expect(result.confidence).to be_a(Float)
        expect(result.confidence).to be >= 0.0
        expect(result.confidence).to be <= 1.0
      end

      it "exposes evaluations as array of Evaluation objects" do
        expect(result.evaluations).to be_an(Array)
        expect(result.evaluations).to all(be_a(DecisionAgent::Evaluation))
        expect(result.evaluations.size).to eq(1)
      end

      it "exposes explanations as array of strings" do
        expect(result.explanations).to be_an(Array)
        expect(result.explanations).to all(be_a(String))
        expect(result.explanations).not_to be_empty
      end

      it "exposes audit_payload as fully reproducible Hash" do
        expect(result.audit_payload).to be_a(Hash)
        expect(result.audit_payload).to be_frozen
      end
    end

    describe "audit_payload specification" do
      it "includes timestamp field" do
        expect(result.audit_payload).to have_key(:timestamp)
        expect(result.audit_payload[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z/)
      end

      it "includes context field" do
        expect(result.audit_payload).to have_key(:context)
        expect(result.audit_payload[:context]).to eq(user: "bob", priority: "medium")
      end

      it "includes feedback field" do
        expect(result.audit_payload).to have_key(:feedback)
      end

      it "includes evaluations array with full details" do
        expect(result.audit_payload).to have_key(:evaluations)
        expect(result.audit_payload[:evaluations]).to be_an(Array)

        eval_hash = result.audit_payload[:evaluations].first
        expect(eval_hash).to have_key(:decision)
        expect(eval_hash).to have_key(:weight)
        expect(eval_hash).to have_key(:reason)
        expect(eval_hash).to have_key(:evaluator_name)
        expect(eval_hash).to have_key(:metadata)
      end

      it "includes decision field" do
        expect(result.audit_payload).to have_key(:decision)
        expect(result.audit_payload[:decision]).to eq("approve")
      end

      it "includes confidence field" do
        expect(result.audit_payload).to have_key(:confidence)
        expect(result.audit_payload[:confidence]).to eq(result.confidence)
      end

      it "includes scoring_strategy field" do
        expect(result.audit_payload).to have_key(:scoring_strategy)
        expect(result.audit_payload[:scoring_strategy]).to eq("DecisionAgent::Scoring::WeightedAverage")
      end

      it "includes agent_version field" do
        expect(result.audit_payload).to have_key(:agent_version)
        expect(result.audit_payload[:agent_version]).to eq(DecisionAgent::VERSION)
      end

      it "includes deterministic_hash field" do
        expect(result.audit_payload).to have_key(:deterministic_hash)
        expect(result.audit_payload[:deterministic_hash]).to be_a(String)
        expect(result.audit_payload[:deterministic_hash]).to match(/^[a-f0-9]{64}$/)
      end
    end

    describe "deterministic hash generation" do
      it "generates same hash for same input" do
        result1 = agent.decide(context: context)
        result2 = agent.decide(context: context)

        expect(result1.audit_payload[:deterministic_hash]).to eq(result2.audit_payload[:deterministic_hash])
      end

      it "generates different hash for different context" do
        result1 = agent.decide(context: { user: "alice" })
        result2 = agent.decide(context: { user: "bob" })

        expect(result1.audit_payload[:deterministic_hash]).not_to eq(result2.audit_payload[:deterministic_hash])
      end

      it "excludes timestamp from hash (for determinism)" do
        # Two decisions with same context should have same hash despite different timestamps
        result1 = agent.decide(context: context)
        sleep 0.01
        result2 = agent.decide(context: context)

        expect(result1.audit_payload[:timestamp]).not_to eq(result2.audit_payload[:timestamp])
        expect(result1.audit_payload[:deterministic_hash]).to eq(result2.audit_payload[:deterministic_hash])
      end

      it "excludes feedback from hash (for determinism)" do
        result1 = agent.decide(context: context, feedback: { source: "test1" })
        result2 = agent.decide(context: context, feedback: { source: "test2" })

        expect(result1.audit_payload[:deterministic_hash]).to eq(result2.audit_payload[:deterministic_hash])
      end
    end

    describe "confidence bounds validation" do
      it "validates confidence is between 0.0 and 1.0" do
        expect {
          DecisionAgent::Decision.new(
            decision: "test",
            confidence: -0.1,
            explanations: [],
            evaluations: [],
            audit_payload: {}
          )
        }.to raise_error(DecisionAgent::InvalidConfidenceError)

        expect {
          DecisionAgent::Decision.new(
            decision: "test",
            confidence: 1.1,
            explanations: [],
            evaluations: [],
            audit_payload: {}
          )
        }.to raise_error(DecisionAgent::InvalidConfidenceError)
      end
    end
  end

  describe "Threshold Strategy Fallback Behavior" do
    let(:evaluator) do
      DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.5,  # Below threshold
        reason: "Low confidence approval"
      )
    end

    context "when no evaluation meets threshold" do
      it "returns fallback_decision" do
        agent = DecisionAgent::Agent.new(
          evaluators: [evaluator],
          scoring_strategy: DecisionAgent::Scoring::Threshold.new(
            threshold: 0.8,
            fallback_decision: "manual_review"
          )
        )

        result = agent.decide(context: { user: "test" })

        expect(result.decision).to eq("manual_review")
      end

      it "sets reduced confidence for fallback (original_weight * 0.5)" do
        agent = DecisionAgent::Agent.new(
          evaluators: [evaluator],
          scoring_strategy: DecisionAgent::Scoring::Threshold.new(
            threshold: 0.8,
            fallback_decision: "manual_review"
          )
        )

        result = agent.decide(context: { user: "test" })

        # Threshold strategy reduces confidence by 50% when falling back
        # Original weight was 0.5, so fallback confidence is 0.5 * 0.5 = 0.25
        expect(result.confidence).to eq(0.25)
      end

      it "includes fallback explanation" do
        agent = DecisionAgent::Agent.new(
          evaluators: [evaluator],
          scoring_strategy: DecisionAgent::Scoring::Threshold.new(
            threshold: 0.8,
            fallback_decision: "manual_review"
          )
        )

        result = agent.decide(context: { user: "test" })

        expect(result.explanations.join(" ")).to include("manual_review")
      end
    end

    context "when evaluation meets threshold" do
      let(:high_confidence_evaluator) do
        DecisionAgent::Evaluators::StaticEvaluator.new(
          decision: "approve",
          weight: 0.9,  # Above threshold
          reason: "High confidence approval"
        )
      end

      it "returns the decision with full confidence" do
        agent = DecisionAgent::Agent.new(
          evaluators: [high_confidence_evaluator],
          scoring_strategy: DecisionAgent::Scoring::Threshold.new(
            threshold: 0.8,
            fallback_decision: "manual_review"
          )
        )

        result = agent.decide(context: { user: "test" })

        expect(result.decision).to eq("approve")
        expect(result.confidence).to eq(0.9)
      end
    end
  end
end
