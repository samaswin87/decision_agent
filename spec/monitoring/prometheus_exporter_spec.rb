require "spec_helper"
require "decision_agent/monitoring/metrics_collector"
require "decision_agent/monitoring/prometheus_exporter"

RSpec.describe DecisionAgent::Monitoring::PrometheusExporter do
  let(:collector) { DecisionAgent::Monitoring::MetricsCollector.new }
  let(:exporter) { described_class.new(metrics_collector: collector, namespace: "test") }

  let(:decision) do
    double(
      "Decision",
      decision: "approve",
      confidence: 0.85,
      evaluations: [double("Evaluation", evaluator_name: "test_evaluator")]
    )
  end
  let(:context) { double("Context", to_h: { user: "test" }) }

  describe "#initialize" do
    it "initializes with metrics collector" do
      expect(exporter).to be_a(described_class)
    end

    it "uses default namespace" do
      exporter = described_class.new(metrics_collector: collector)
      output = exporter.export
      expect(output).to include("decision_agent_")
    end

    it "uses custom namespace" do
      output = exporter.export
      expect(output).to include("test_")
    end
  end

  describe "#export" do
    before do
      # Record some metrics
      3.times { collector.record_decision(decision, context, duration_ms: 10.0) }
      collector.record_performance(operation: "decide", duration_ms: 15.0, success: true)
      collector.record_error(StandardError.new("Test error"))
    end

    it "exports in Prometheus text format" do
      output = exporter.export

      expect(output).to be_a(String)
      expect(output).to include("# DecisionAgent Metrics Export")
    end

    it "includes decision metrics" do
      output = exporter.export

      expect(output).to include("# HELP test_decisions_total")
      expect(output).to include("# TYPE test_decisions_total counter")
      expect(output).to include("test_decisions_total 3")
    end

    it "includes confidence metrics" do
      output = exporter.export

      expect(output).to include("# HELP test_decision_confidence_avg")
      expect(output).to include("# TYPE test_decision_confidence_avg gauge")
      expect(output).to include("test_decision_confidence_avg 0.85")
    end

    it "includes performance metrics" do
      output = exporter.export

      expect(output).to include("# HELP test_success_rate")
      expect(output).to include("# TYPE test_success_rate gauge")
    end

    it "includes error metrics" do
      output = exporter.export

      expect(output).to include("# HELP test_errors_total")
      expect(output).to include("# TYPE test_errors_total counter")
      expect(output).to include("test_errors_total 1")
    end

    it "includes system info" do
      output = exporter.export

      expect(output).to include("# HELP test_info")
      expect(output).to include("# TYPE test_info gauge")
      expect(output).to include("version=\"#{DecisionAgent::VERSION}\"")
    end

    it "includes decision distribution" do
      output = exporter.export

      expect(output).to include("# HELP test_decisions_by_type")
      expect(output).to include("test_decisions_by_type{decision=\"approve\"} 3")
    end

    it "includes error distribution by type" do
      output = exporter.export

      expect(output).to include("# HELP test_errors_by_type")
      expect(output).to include("test_errors_by_type{error=\"StandardError\"} 1")
    end

    it "includes metrics count" do
      output = exporter.export

      expect(output).to include("# HELP test_metrics_stored")
      expect(output).to include("test_metrics_stored{type=\"decisions\"} 3")
      expect(output).to include("test_metrics_stored{type=\"errors\"} 1")
    end
  end

  describe "#register_kpi" do
    it "registers a custom KPI" do
      exporter.register_kpi(
        name: "custom_metric",
        value: 42.5,
        help: "A custom metric"
      )

      output = exporter.export
      expect(output).to include("# HELP test_custom_metric A custom metric")
      expect(output).to include("# TYPE test_custom_metric gauge")
      expect(output).to include("test_custom_metric 42.5")
    end

    it "registers KPI with labels" do
      exporter.register_kpi(
        name: "requests",
        value: 100,
        labels: { endpoint: "/api/v1", method: "GET" }
      )

      output = exporter.export
      expect(output).to include("test_requests{endpoint=\"/api/v1\",method=\"GET\"} 100")
    end

    it "sanitizes metric names" do
      exporter.register_kpi(name: "my-custom.metric!", value: 10)

      output = exporter.export
      expect(output).to include("test_my_custom_metric_")
    end

    it "escapes label values" do
      exporter.register_kpi(
        name: "metric",
        value: 1,
        labels: { message: 'Contains "quotes"' }
      )

      output = exporter.export
      expect(output).to include('message=\"Contains \\"quotes\\"\"')
    end
  end

  describe "#metrics_hash" do
    before do
      collector.record_decision(decision, context, duration_ms: 10.0)
    end

    it "returns metrics as hash" do
      metrics = exporter.metrics_hash

      expect(metrics).to be_a(Hash)
      expect(metrics).to have_key(:decisions)
      expect(metrics).to have_key(:performance)
      expect(metrics).to have_key(:errors)
      expect(metrics).to have_key(:system)
    end

    it "includes metric types" do
      metrics = exporter.metrics_hash

      expect(metrics[:decisions][:total][:type]).to eq("counter")
      expect(metrics[:decisions][:avg_confidence][:type]).to eq("gauge")
    end

    it "includes metric values" do
      metrics = exporter.metrics_hash

      expect(metrics[:decisions][:total][:value]).to eq(1)
      expect(metrics[:decisions][:avg_confidence][:value]).to eq(0.85)
    end
  end

  describe "thread safety" do
    it "handles concurrent KPI registration" do
      threads = 10.times.map do |i|
        Thread.new do
          10.times do |j|
            exporter.register_kpi(
              name: "metric_#{i}_#{j}",
              value: i * 10 + j
            )
          end
        end
      end

      expect { threads.each(&:join) }.not_to raise_error
    end

    it "handles concurrent exports" do
      threads = 5.times.map do
        Thread.new do
          10.times { exporter.export }
        end
      end

      expect { threads.each(&:join) }.not_to raise_error
    end
  end

  describe "performance metrics export" do
    before do
      5.times do |i|
        collector.record_performance(
          operation: "decide",
          duration_ms: (i + 1) * 10.0,
          success: true
        )
      end
    end

    it "exports summary metrics" do
      output = exporter.export

      expect(output).to include("# TYPE test_operation_duration_ms summary")
      expect(output).to include("test_operation_duration_ms{quantile=\"0.5\"}")
      expect(output).to include("test_operation_duration_ms{quantile=\"0.95\"}")
      expect(output).to include("test_operation_duration_ms{quantile=\"0.99\"}")
      expect(output).to include("test_operation_duration_ms_sum")
      expect(output).to include("test_operation_duration_ms_count")
    end
  end

  describe "content type" do
    it "defines Prometheus content type" do
      expect(described_class::CONTENT_TYPE).to eq("text/plain; version=0.0.4")
    end
  end
end
