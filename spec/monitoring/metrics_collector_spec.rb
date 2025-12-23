require "spec_helper"
require "decision_agent/monitoring/metrics_collector"

RSpec.describe DecisionAgent::Monitoring::MetricsCollector do
  let(:collector) { described_class.new(window_size: 60) }
  let(:decision) do
    double(
      "Decision",
      decision: "approve",
      confidence: 0.85,
      evaluations: [
        double("Evaluation", evaluator_name: "test_evaluator")
      ]
    )
  end
  let(:context) { double("Context", to_h: { user: "test" }) }

  describe "#initialize" do
    it "initializes with default window size" do
      collector = described_class.new
      expect(collector.window_size).to eq(3600)
    end

    it "initializes with custom window size" do
      expect(collector.window_size).to eq(60)
    end

    it "initializes empty metrics" do
      counts = collector.metrics_count
      expect(counts[:decisions]).to eq(0)
      expect(counts[:evaluations]).to eq(0)
      expect(counts[:performance]).to eq(0)
      expect(counts[:errors]).to eq(0)
    end
  end

  describe "#record_decision" do
    it "records a decision metric" do
      metric = collector.record_decision(decision, context, duration_ms: 10.5)

      expect(metric[:decision]).to eq("approve")
      expect(metric[:confidence]).to eq(0.85)
      expect(metric[:duration_ms]).to eq(10.5)
      expect(metric[:context_size]).to eq(1)
      expect(metric[:evaluations_count]).to eq(1)
      expect(metric[:evaluator_names]).to eq(["test_evaluator"])
    end

    it "increments decision count" do
      expect {
        collector.record_decision(decision, context)
      }.to change { collector.metrics_count[:decisions] }.by(1)
    end

    it "notifies observers" do
      observed = []
      collector.add_observer do |type, metric|
        observed << [type, metric]
      end

      collector.record_decision(decision, context)

      expect(observed.size).to eq(1)
      expect(observed[0][0]).to eq(:decision)
      expect(observed[0][1][:decision]).to eq("approve")
    end
  end

  describe "#record_evaluation" do
    let(:evaluation) do
      double(
        "Evaluation",
        decision: "approve",
        weight: 0.9,
        evaluator_name: "test_evaluator"
      )
    end

    it "records an evaluation metric" do
      metric = collector.record_evaluation(evaluation)

      expect(metric[:decision]).to eq("approve")
      expect(metric[:weight]).to eq(0.9)
      expect(metric[:evaluator_name]).to eq("test_evaluator")
    end

    it "increments evaluation count" do
      expect {
        collector.record_evaluation(evaluation)
      }.to change { collector.metrics_count[:evaluations] }.by(1)
    end
  end

  describe "#record_performance" do
    it "records performance metrics" do
      metric = collector.record_performance(
        operation: "decide",
        duration_ms: 25.5,
        success: true,
        metadata: { evaluators: 2 }
      )

      expect(metric[:operation]).to eq("decide")
      expect(metric[:duration_ms]).to eq(25.5)
      expect(metric[:success]).to be true
      expect(metric[:metadata]).to eq({ evaluators: 2 })
    end

    it "records failed operations" do
      metric = collector.record_performance(
        operation: "decide",
        duration_ms: 10.0,
        success: false
      )

      expect(metric[:success]).to be false
    end
  end

  describe "#record_error" do
    let(:error) { StandardError.new("Test error") }

    it "records error metrics" do
      metric = collector.record_error(error, context: { user_id: 123 })

      expect(metric[:error_class]).to eq("StandardError")
      expect(metric[:error_message]).to eq("Test error")
      expect(metric[:context]).to eq({ user_id: 123 })
    end

    it "increments error count" do
      expect {
        collector.record_error(error)
      }.to change { collector.metrics_count[:errors] }.by(1)
    end
  end

  describe "#statistics" do
    before do
      # Record some metrics
      5.times do |i|
        collector.record_decision(decision, context, duration_ms: (i + 1) * 10)
      end

      2.times do
        collector.record_performance(operation: "decide", duration_ms: 15.0, success: true)
      end
      collector.record_performance(operation: "decide", duration_ms: 20.0, success: false)

      collector.record_error(StandardError.new("Error 1"))
    end

    it "returns summary statistics" do
      stats = collector.statistics

      expect(stats[:summary][:total_decisions]).to eq(5)
      expect(stats[:summary][:total_evaluations]).to eq(0)
      expect(stats[:summary][:total_errors]).to eq(1)
    end

    it "computes decision statistics" do
      stats = collector.statistics

      expect(stats[:decisions][:total]).to eq(5)
      expect(stats[:decisions][:avg_confidence]).to eq(0.85)
      expect(stats[:decisions][:min_confidence]).to eq(0.85)
      expect(stats[:decisions][:max_confidence]).to eq(0.85)
      expect(stats[:decisions][:avg_duration_ms]).to be_within(0.1).of(30.0)
    end

    it "computes performance statistics" do
      stats = collector.statistics

      expect(stats[:performance][:total_operations]).to eq(3)
      expect(stats[:performance][:successful]).to eq(2)
      expect(stats[:performance][:failed]).to eq(1)
      expect(stats[:performance][:success_rate]).to be_within(0.01).of(0.6667)
    end

    it "computes error statistics" do
      stats = collector.statistics

      expect(stats[:errors][:total]).to eq(1)
      expect(stats[:errors][:by_type]["StandardError"]).to eq(1)
    end

    it "filters by time range" do
      stats = collector.statistics(time_range: 30)
      expect(stats[:summary][:time_range]).to eq("Last 30s")
    end
  end

  describe "#time_series" do
    before do
      10.times do
        collector.record_decision(decision, context)
        sleep 0.01 # Small delay to ensure different buckets
      end
    end

    it "returns time series data" do
      series = collector.time_series(metric_type: :decisions, bucket_size: 1, time_range: 60)

      expect(series).to be_an(Array)
      expect(series.first).to have_key(:timestamp)
      expect(series.first).to have_key(:count)
      expect(series.first).to have_key(:metrics)
    end

    it "buckets metrics by time" do
      series = collector.time_series(metric_type: :decisions, bucket_size: 60, time_range: 3600)

      total_count = series.sum { |s| s[:count] }
      expect(total_count).to eq(10)
    end
  end

  describe "#clear!" do
    before do
      collector.record_decision(decision, context)
      collector.record_error(StandardError.new("Test"))
    end

    it "clears all metrics" do
      collector.clear!

      counts = collector.metrics_count
      expect(counts[:decisions]).to eq(0)
      expect(counts[:errors]).to eq(0)
    end
  end

  describe "thread safety" do
    it "handles concurrent writes safely" do
      threads = 10.times.map do
        Thread.new do
          10.times do
            collector.record_decision(decision, context)
          end
        end
      end

      threads.each(&:join)

      expect(collector.metrics_count[:decisions]).to eq(100)
    end

    it "handles concurrent reads and writes" do
      writer = Thread.new do
        50.times do
          collector.record_decision(decision, context)
          sleep 0.001
        end
      end

      reader = Thread.new do
        50.times do
          collector.statistics
          sleep 0.001
        end
      end

      expect { writer.join && reader.join }.not_to raise_error
    end
  end

  describe "metric cleanup" do
    it "removes old metrics outside window" do
      collector = described_class.new(window_size: 1)

      collector.record_decision(decision, context)
      expect(collector.metrics_count[:decisions]).to eq(1)

      sleep 1.5

      collector.record_decision(decision, context)
      # Old metric should be cleaned up
      expect(collector.metrics_count[:decisions]).to eq(1)
    end
  end
end
