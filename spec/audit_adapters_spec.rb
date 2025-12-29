require "spec_helper"

RSpec.describe "Audit Adapters" do
  describe DecisionAgent::Audit::Adapter do
    it "raises NotImplementedError when record is called" do
      adapter = DecisionAgent::Audit::Adapter.new
      decision = DecisionAgent::Decision.new(
        decision: "approve",
        confidence: 0.8,
        explanations: [],
        evaluations: [],
        audit_payload: {}
      )
      context = DecisionAgent::Context.new({ user: "alice" })

      expect do
        adapter.record(decision, context)
      end.to raise_error(NotImplementedError, /Subclasses must implement #record/)
    end
  end

  describe DecisionAgent::Audit::NullAdapter do
    it "implements record method without side effects" do
      adapter = DecisionAgent::Audit::NullAdapter.new

      decision = DecisionAgent::Decision.new(
        decision: "approve",
        confidence: 0.8,
        explanations: [],
        evaluations: [],
        audit_payload: {}
      )

      context = DecisionAgent::Context.new({ user: "alice" })

      expect do
        adapter.record(decision, context)
      end.not_to raise_error
    end
  end

  describe DecisionAgent::Audit::LoggerAdapter do
    it "logs decision to provided logger" do
      io = StringIO.new
      logger = Logger.new(io)

      adapter = DecisionAgent::Audit::LoggerAdapter.new(logger: logger)

      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve")
      agent = DecisionAgent::Agent.new(
        evaluators: [evaluator],
        audit_adapter: adapter
      )

      agent.decide(context: { user: "alice" })

      log_output = io.string
      expect(log_output).to include("approve")
      expect(log_output).to include("alice")
    end

    it "uses default logger when none provided" do
      adapter = DecisionAgent::Audit::LoggerAdapter.new

      expect(adapter.logger).to be_a(Logger)
    end

    it "logs JSON format" do
      io = StringIO.new
      logger = Logger.new(io)
      logger.formatter = proc { |_severity, _datetime, _progname, msg| "#{msg}\n" }

      adapter = DecisionAgent::Audit::LoggerAdapter.new(logger: logger)

      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "test_decision", weight: 0.9)
      agent = DecisionAgent::Agent.new(
        evaluators: [evaluator],
        audit_adapter: adapter
      )

      agent.decide(context: { key: "value" })

      log_output = io.string
      log_json = JSON.parse(log_output.strip)

      expect(log_json["decision"]).to eq("test_decision")
      expect(log_json["confidence"]).to be_a(Numeric)
      expect(log_json["context"]).to eq({ "key" => "value" })
      expect(log_json["audit_hash"]).to be_a(String)
    end
  end
end
