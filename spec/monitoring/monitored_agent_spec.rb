require "spec_helper"
require "decision_agent/monitoring/metrics_collector"
require "decision_agent/monitoring/monitored_agent"

RSpec.describe DecisionAgent::Monitoring::MonitoredAgent do
  let(:collector) { DecisionAgent::Monitoring::MetricsCollector.new(storage: :memory) }
  let(:evaluator) do
    DecisionAgent::Evaluators::JsonRuleEvaluator.new(
      rules_json: {
        version: "1.0",
        ruleset: "test",
        rules: [{
          id: "test_rule",
          if: { field: "amount", op: "gt", value: 100 },
          then: { decision: "approve", weight: 0.9, reason: "Test reason" }
        }]
      },
      name: "test_evaluator"
    )
  end
  let(:agent) { DecisionAgent::Agent.new(evaluators: [evaluator]) }
  let(:monitored_agent) { described_class.new(agent: agent, metrics_collector: collector) }

  describe "#initialize" do
    it "wraps an agent with metrics collection" do
      expect(monitored_agent.agent).to eq(agent)
      expect(monitored_agent.metrics_collector).to eq(collector)
    end
  end

  describe "#decide" do
    let(:context) { { amount: 1000 } }

    it "makes a decision and records metrics" do
      result = monitored_agent.decide(context: context)

      expect(result).to be_a(DecisionAgent::Decision)
      expect(result.decision).to eq("approve")
      expect(collector.metrics_count[:decisions]).to eq(1)
      expect(collector.metrics_count[:evaluations]).to eq(1)
      expect(collector.metrics_count[:performance]).to eq(1)
    end

    it "records decision metrics with duration" do
      monitored_agent.decide(context: context)

      stats = collector.statistics
      expect(stats[:decisions][:total]).to eq(1)
      expect(stats[:decisions][:avg_duration_ms]).to be > 0
    end

    it "records evaluation metrics" do
      monitored_agent.decide(context: context)

      stats = collector.statistics
      expect(stats[:evaluations][:total]).to eq(1)
      expect(stats[:evaluations][:evaluator_distribution]["test_evaluator"]).to eq(1)
    end

    it "records performance metrics as successful" do
      monitored_agent.decide(context: context)

      stats = collector.statistics
      expect(stats[:performance][:total_operations]).to eq(1)
      expect(stats[:performance][:successful]).to eq(1)
      expect(stats[:performance][:success_rate]).to eq(1.0)
    end

    it "includes metadata in performance metrics" do
      monitored_agent.decide(context: context)

      collector.statistics
      perf_metric = collector.instance_variable_get(:@metrics)[:performance].first

      expect(perf_metric[:metadata][:evaluators_count]).to eq(1)
      expect(perf_metric[:metadata][:decision]).to eq("approve")
      expect(perf_metric[:metadata][:confidence]).to be_a(Float)
    end

    context "when decision fails" do
      before do
        allow(agent).to receive(:decide).and_raise(StandardError.new("Test error"))
      end

      it "records error metrics" do
        expect do
          monitored_agent.decide(context: context)
        end.to raise_error(StandardError, "Test error")

        expect(collector.metrics_count[:errors]).to eq(1)
      end

      it "records failed performance metrics" do
        expect do
          monitored_agent.decide(context: context)
        end.to raise_error(StandardError)

        stats = collector.statistics
        expect(stats[:performance][:total_operations]).to eq(1)
        expect(stats[:performance][:failed]).to eq(1)
        expect(stats[:performance][:success_rate]).to eq(0.0)
      end

      it "includes error details in metrics" do
        expect do
          monitored_agent.decide(context: context)
        end.to raise_error(StandardError)

        error_metric = collector.instance_variable_get(:@metrics)[:errors].first
        expect(error_metric[:error_class]).to eq("StandardError")
        expect(error_metric[:error_message]).to eq("Test error")
        expect(error_metric[:context]).to eq(context)
      end

      it "re-raises the error" do
        expect do
          monitored_agent.decide(context: context)
        end.to raise_error(StandardError, "Test error")
      end
    end

    it "handles Context objects" do
      ctx = DecisionAgent::Context.new(context)
      result = monitored_agent.decide(context: ctx)

      expect(result).to be_a(DecisionAgent::Decision)
      expect(collector.metrics_count[:decisions]).to eq(1)
    end

    it "handles hash contexts" do
      result = monitored_agent.decide(context: context)

      expect(result).to be_a(DecisionAgent::Decision)
      expect(collector.metrics_count[:decisions]).to eq(1)
    end

    it "measures decision duration accurately" do
      # Mock agent to introduce delay
      allow(agent).to receive(:decide) do |context:, **_kwargs|
        sleep 0.01 # 10ms delay
        evaluation = evaluator.evaluate(context)
        DecisionAgent::Decision.new(
          decision: "approve",
          confidence: 0.9,
          explanations: ["Test"],
          evaluations: [evaluation].compact, # Remove nils in case evaluation returns nil
          audit_payload: {}
        )
      end

      monitored_agent.decide(context: context)

      stats = collector.statistics
      expect(stats[:decisions][:avg_duration_ms]).to be >= 10
    end
  end

  describe "method delegation" do
    it "delegates methods to wrapped agent" do
      expect(monitored_agent.evaluators).to eq(agent.evaluators)
      expect(monitored_agent.scoring_strategy).to eq(agent.scoring_strategy)
      expect(monitored_agent.audit_adapter).to eq(agent.audit_adapter)
    end

    it "responds to agent methods" do
      expect(monitored_agent).to respond_to(:evaluators)
      expect(monitored_agent).to respond_to(:scoring_strategy)
      expect(monitored_agent).to respond_to(:audit_adapter)
    end
  end

  describe "thread safety" do
    it "handles concurrent decisions safely" do
      # Materialize let variables before creating threads
      test_context = { amount: 1000 }
      test_monitored_agent = monitored_agent
      test_collector = collector

      threads = 10.times.map do
        Thread.new do
          10.times do
            test_monitored_agent.decide(context: test_context)
          end
        end
      end

      threads.each(&:join)

      expect(test_collector.metrics_count[:decisions]).to eq(100)
      expect(test_collector.metrics_count[:evaluations]).to eq(100)
      expect(test_collector.metrics_count[:performance]).to eq(100)
    end
  end

  describe "integration test" do
    it "provides comprehensive metrics for multiple decisions" do
      contexts = [
        { amount: 500 },
        { amount: 1500 },
        { amount: 2000 }
      ]

      contexts.each do |ctx|
        monitored_agent.decide(context: ctx)
      end

      stats = collector.statistics

      # Summary
      expect(stats[:summary][:total_decisions]).to eq(3)
      expect(stats[:summary][:total_evaluations]).to eq(3)
      expect(stats[:summary][:total_errors]).to eq(0)

      # Decision stats
      expect(stats[:decisions][:total]).to eq(3)
      expect(stats[:decisions][:avg_confidence]).to be > 0
      expect(stats[:decisions][:decision_distribution]["approve"]).to eq(3)

      # Performance stats
      expect(stats[:performance][:total_operations]).to eq(3)
      expect(stats[:performance][:success_rate]).to eq(1.0)
      expect(stats[:performance][:avg_duration_ms]).to be > 0
    end
  end
end
