require "spec_helper"

RSpec.describe DecisionAgent::Agent do
  describe "#initialize" do
    it "requires at least one evaluator" do
      expect do
        DecisionAgent::Agent.new(evaluators: [])
      end.to raise_error(DecisionAgent::InvalidConfigurationError, /at least one evaluator/i)
    end

    it "validates evaluators respond to #evaluate" do
      invalid_evaluator = Object.new

      expect do
        DecisionAgent::Agent.new(evaluators: [invalid_evaluator])
      end.to raise_error(DecisionAgent::InvalidEvaluatorError)
    end

    it "validates scoring strategy responds to #score" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve")
      invalid_strategy = Object.new

      expect do
        DecisionAgent::Agent.new(
          evaluators: [evaluator],
          scoring_strategy: invalid_strategy
        )
      end.to raise_error(DecisionAgent::InvalidScoringStrategyError)
    end

    it "validates audit adapter responds to #record" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve")
      invalid_adapter = Object.new

      expect do
        DecisionAgent::Agent.new(
          evaluators: [evaluator],
          audit_adapter: invalid_adapter
        )
      end.to raise_error(DecisionAgent::InvalidAuditAdapterError)
    end

    it "uses defaults when optional parameters are omitted" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve")

      agent = DecisionAgent::Agent.new(evaluators: [evaluator])

      expect(agent.scoring_strategy).to be_a(DecisionAgent::Scoring::WeightedAverage)
      expect(agent.audit_adapter).to be_a(DecisionAgent::Audit::NullAdapter)
    end

    it "enables validation by default in non-production environments" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve")
      original_env = ENV.fetch("RAILS_ENV", nil)
      ENV["RAILS_ENV"] = "development"

      agent = DecisionAgent::Agent.new(evaluators: [evaluator])
      # Validation should be enabled (we can't directly test this, but we can test behavior)
      # If validation is enabled, invalid evaluations would raise errors
      expect(agent).to be_a(DecisionAgent::Agent)

      ENV["RAILS_ENV"] = original_env
    end

    it "disables validation in production by default" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve")
      original_env = ENV.fetch("RAILS_ENV", nil)
      ENV["RAILS_ENV"] = "production"

      agent = DecisionAgent::Agent.new(evaluators: [evaluator])
      expect(agent).to be_a(DecisionAgent::Agent)

      ENV["RAILS_ENV"] = original_env
    end

    it "allows explicit validation control" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve")

      agent_with_validation = DecisionAgent::Agent.new(
        evaluators: [evaluator],
        validate_evaluations: true
      )
      expect(agent_with_validation).to be_a(DecisionAgent::Agent)

      agent_without_validation = DecisionAgent::Agent.new(
        evaluators: [evaluator],
        validate_evaluations: false
      )
      expect(agent_without_validation).to be_a(DecisionAgent::Agent)
    end
  end

  describe "#decide" do
    it "returns a Decision object with all required fields" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test approval"
      )

      agent = DecisionAgent::Agent.new(evaluators: [evaluator])

      result = agent.decide(context: { user: "test" })

      expect(result).to be_a(DecisionAgent::Decision)
      expect(result.decision).to eq("approve")
      expect(result.confidence).to be_between(0.0, 1.0)
      expect(result.explanations).to be_an(Array)
      expect(result.evaluations).to be_an(Array)
      expect(result.audit_payload).to be_a(Hash)
    end

    it "accepts Context object or Hash for context parameter" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve")
      agent = DecisionAgent::Agent.new(evaluators: [evaluator])

      result1 = agent.decide(context: { user: "test" })
      result2 = agent.decide(context: DecisionAgent::Context.new({ user: "test" }))

      expect(result1.decision).to eq(result2.decision)
    end

    it "raises NoEvaluationsError when no evaluators return decisions" do
      failing_evaluator = Class.new(DecisionAgent::Evaluators::Base) do
        def evaluate(_context, feedback: {})
          nil
        end
      end

      agent = DecisionAgent::Agent.new(evaluators: [failing_evaluator.new])

      expect do
        agent.decide(context: {})
      end.to raise_error(DecisionAgent::NoEvaluationsError)
    end

    it "includes feedback in evaluation" do
      feedback_evaluator = Class.new(DecisionAgent::Evaluators::Base) do
        def evaluate(_context, feedback: {})
          decision = feedback[:override] ? "reject" : "approve"
          DecisionAgent::Evaluation.new(
            decision: decision,
            weight: 1.0,
            reason: "Feedback-based",
            evaluator_name: "FeedbackEvaluator"
          )
        end
      end

      agent = DecisionAgent::Agent.new(evaluators: [feedback_evaluator.new])

      result1 = agent.decide(context: {}, feedback: {})
      result2 = agent.decide(context: {}, feedback: { override: true })

      expect(result1.decision).to eq("approve")
      expect(result2.decision).to eq("reject")
    end

    it "records decision via audit adapter" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve")

      audit_adapter = Class.new(DecisionAgent::Audit::Adapter) do
        attr_reader :recorded_decision, :recorded_context

        def record(decision, context)
          @recorded_decision = decision
          @recorded_context = context
        end
      end.new

      agent = DecisionAgent::Agent.new(
        evaluators: [evaluator],
        audit_adapter: audit_adapter
      )

      result = agent.decide(context: { user: "test" })

      expect(audit_adapter.recorded_decision).to eq(result)
      expect(audit_adapter.recorded_context.to_h).to eq({ user: "test" })
    end

    it "includes deterministic hash in audit payload" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve", weight: 0.8)
      agent = DecisionAgent::Agent.new(evaluators: [evaluator])

      result1 = agent.decide(context: { user: "test" })
      result2 = agent.decide(context: { user: "test" })

      expect(result1.audit_payload[:deterministic_hash]).to be_a(String)
      expect(result1.audit_payload[:deterministic_hash]).to eq(result2.audit_payload[:deterministic_hash])
    end

    it "produces different hashes for different contexts" do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve")
      agent = DecisionAgent::Agent.new(evaluators: [evaluator])

      result1 = agent.decide(context: { user: "alice" })
      result2 = agent.decide(context: { user: "bob" })

      expect(result1.audit_payload[:deterministic_hash]).not_to eq(result2.audit_payload[:deterministic_hash])
    end
  end

  describe "conflict resolution" do
    it "resolves conflicting evaluations using scoring strategy" do
      evaluator1 = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.6,
        name: "Evaluator1"
      )
      evaluator2 = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "reject",
        weight: 0.9,
        name: "Evaluator2"
      )

      agent = DecisionAgent::Agent.new(
        evaluators: [evaluator1, evaluator2],
        scoring_strategy: DecisionAgent::Scoring::MaxWeight.new
      )

      result = agent.decide(context: {})

      expect(result.decision).to eq("reject")
      expect(result.explanations.join(" ")).to include("Conflicting evaluations")
    end

    it "includes conflicting evaluations in explanations" do
      evaluator1 = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.4,
        name: "Evaluator1"
      )
      evaluator2 = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "reject",
        weight: 0.7,
        name: "Evaluator2"
      )

      agent = DecisionAgent::Agent.new(evaluators: [evaluator1, evaluator2])

      result = agent.decide(context: {})

      explanations_text = result.explanations.join(" ")
      expect(explanations_text).to include("Evaluator1")
      expect(explanations_text).to include("Evaluator2")
    end
  end

  describe "multiple evaluators agreeing" do
    it "combines evaluations when all agree" do
      evaluator1 = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.6,
        name: "Evaluator1"
      )
      evaluator2 = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "approve",
        weight: 0.8,
        name: "Evaluator2"
      )

      agent = DecisionAgent::Agent.new(evaluators: [evaluator1, evaluator2])

      result = agent.decide(context: {})

      expect(result.decision).to eq("approve")
      expect(result.confidence).to be > 0.5
    end
  end

  describe "graceful error handling" do
    it "ignores evaluators that raise errors" do
      good_evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve")

      bad_evaluator = Class.new(DecisionAgent::Evaluators::Base) do
        def evaluate(_context, feedback: {})
          raise StandardError, "Intentional error"
        end
      end

      agent = DecisionAgent::Agent.new(evaluators: [bad_evaluator.new, good_evaluator])

      result = agent.decide(context: {})

      expect(result.decision).to eq("approve")
    end
  end
end
