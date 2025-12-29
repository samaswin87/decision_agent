# frozen_string_literal: true

require "spec_helper"
require "active_record"
require "decision_agent/monitoring/storage/activerecord_adapter"

RSpec.describe DecisionAgent::Monitoring::Storage::ActiveRecordAdapter do
  # Setup in-memory SQLite database for testing
  before(:all) do
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: ":memory:"
    )

    # Create tables
    ActiveRecord::Schema.define do
      create_table :decision_logs, force: true do |t|
        t.string :decision, null: false
        t.float :confidence
        t.integer :evaluations_count, default: 0
        t.float :duration_ms
        t.string :status
        t.text :context
        t.text :metadata
        t.timestamps
      end

      create_table :evaluation_metrics, force: true do |t|
        t.references :decision_log, foreign_key: true
        t.string :evaluator_name, null: false
        t.float :score
        t.boolean :success
        t.float :duration_ms
        t.text :details
        t.timestamps
      end

      create_table :performance_metrics, force: true do |t|
        t.string :operation, null: false
        t.float :duration_ms
        t.string :status
        t.text :metadata
        t.timestamps
      end

      create_table :error_metrics, force: true do |t|
        t.string :error_type, null: false
        t.text :message
        t.text :stack_trace
        t.string :severity
        t.text :context
        t.timestamps
      end
    end

    # Define models
    # rubocop:disable Lint/ConstantDefinitionInBlock
    class DecisionLog < ActiveRecord::Base
      has_many :evaluation_metrics, dependent: :destroy

      scope :recent, ->(time_range) { where("created_at >= ?", Time.now - time_range) }

      def self.success_rate(time_range: 3600)
        total = recent(time_range).where.not(status: nil).count
        return 0.0 if total.zero?

        recent(time_range).where(status: "success").count.to_f / total
      end

      def parsed_context
        JSON.parse(context, symbolize_names: true)
      rescue StandardError
        {}
      end
    end

    class EvaluationMetric < ActiveRecord::Base
      belongs_to :decision_log, optional: true

      scope :recent, ->(time_range) { where("created_at >= ?", Time.now - time_range) }
      scope :successful, -> { where(success: true) }

      def parsed_details
        JSON.parse(details, symbolize_names: true)
      rescue StandardError
        {}
      end
    end

    class PerformanceMetric < ActiveRecord::Base
      scope :recent, ->(time_range) { where("created_at >= ?", Time.now - time_range) }

      def self.average_duration(time_range: 3600)
        recent(time_range).average(:duration_ms).to_f
      end

      def self.p50(time_range: 3600)
        percentile(0.50, time_range: time_range)
      end

      def self.p95(time_range: 3600)
        percentile(0.95, time_range: time_range)
      end

      def self.p99(time_range: 3600)
        percentile(0.99, time_range: time_range)
      end

      def self.percentile(pct, time_range: 3600)
        durations = recent(time_range).where.not(duration_ms: nil).order(:duration_ms).pluck(:duration_ms)
        return 0.0 if durations.empty?

        durations[(durations.length * pct).ceil - 1].to_f
      end

      def self.success_rate(time_range: 3600)
        total = recent(time_range).where.not(status: nil).count
        return 0.0 if total.zero?

        recent(time_range).where(status: "success").count.to_f / total
      end
    end

    class ErrorMetric < ActiveRecord::Base
      scope :recent, ->(time_range) { where("created_at >= ?", Time.now - time_range) }
      scope :critical, -> { where(severity: "critical") }

      def parsed_context
        JSON.parse(context, symbolize_names: true)
      rescue StandardError
        {}
      end
    end
    # rubocop:enable Lint/ConstantDefinitionInBlock
  end

  before do
    DecisionLog.delete_all
    EvaluationMetric.delete_all
    PerformanceMetric.delete_all
    ErrorMetric.delete_all
  end

  let(:adapter) { described_class.new }

  describe ".available?" do
    it "returns true when ActiveRecord and models are defined" do
      expect(described_class.available?).to be_truthy
    end
  end

  describe "#record_decision" do
    it "creates a decision log record" do
      expect do
        adapter.record_decision(
          "approve_payment",
          { user_id: 123, amount: 500 },
          confidence: 0.85,
          evaluations_count: 3,
          duration_ms: 45.5,
          status: "success"
        )
      end.to change(DecisionLog, :count).by(1)

      log = DecisionLog.last
      expect(log.decision).to eq("approve_payment")
      expect(log.confidence).to eq(0.85)
      expect(log.evaluations_count).to eq(3)
      expect(log.duration_ms).to eq(45.5)
      expect(log.status).to eq("success")
      expect(log.parsed_context).to eq(user_id: 123, amount: 500)
    end

    it "handles database errors gracefully" do
      allow(::DecisionLog).to receive(:create!).and_raise(StandardError.new("DB error"))
      expect do
        adapter.record_decision("test", {})
      end.not_to raise_error
    end
  end

  describe "#record_evaluation" do
    it "creates an evaluation metric record" do
      expect do
        adapter.record_evaluation(
          "FraudDetector",
          score: 0.92,
          success: true,
          duration_ms: 12.3,
          details: { risk_level: "low" }
        )
      end.to change(EvaluationMetric, :count).by(1)

      metric = EvaluationMetric.last
      expect(metric.evaluator_name).to eq("FraudDetector")
      expect(metric.score).to eq(0.92)
      expect(metric.success).to be true
      expect(metric.duration_ms).to eq(12.3)
      expect(metric.parsed_details).to eq(risk_level: "low")
    end

    it "handles database errors gracefully" do
      allow(::EvaluationMetric).to receive(:create!).and_raise(StandardError.new("DB error"))
      expect do
        adapter.record_evaluation("test")
      end.not_to raise_error
    end
  end

  describe "#record_performance" do
    it "creates a performance metric record" do
      expect do
        adapter.record_performance(
          "api_call",
          duration_ms: 250.5,
          status: "success",
          metadata: { endpoint: "/api/v1/users" }
        )
      end.to change(PerformanceMetric, :count).by(1)

      metric = PerformanceMetric.last
      expect(metric.operation).to eq("api_call")
      expect(metric.duration_ms).to eq(250.5)
      expect(metric.status).to eq("success")
    end

    it "handles database errors gracefully" do
      allow(::PerformanceMetric).to receive(:create!).and_raise(StandardError.new("DB error"))
      expect do
        adapter.record_performance("test")
      end.not_to raise_error
    end
  end

  describe "#record_error" do
    it "creates an error metric record" do
      expect do
        adapter.record_error(
          "RuntimeError",
          message: "Something went wrong",
          stack_trace: ["line 1", "line 2"],
          severity: "critical",
          context: { user_id: 456 }
        )
      end.to change(ErrorMetric, :count).by(1)

      error = ErrorMetric.last
      expect(error.error_type).to eq("RuntimeError")
      expect(error.message).to eq("Something went wrong")
      expect(error.severity).to eq("critical")
      expect(error.parsed_context).to eq(user_id: 456)
    end

    it "handles nil stack_trace" do
      adapter.record_error("TestError", stack_trace: nil)
      error = ErrorMetric.last
      expect(error.stack_trace).to be_nil
    end

    it "handles database errors gracefully" do
      allow(::ErrorMetric).to receive(:create!).and_raise(StandardError.new("DB error"))
      expect do
        adapter.record_error("test")
      end.not_to raise_error
    end
  end

  describe "#statistics" do
    before do
      # Create test data
      3.times do |i|
        adapter.record_decision(
          "decision_#{i}",
          { index: i },
          confidence: 0.5 + (i * 0.1),
          evaluations_count: 2,
          duration_ms: 100 + (i * 10),
          status: "success"
        )
      end

      2.times do |i|
        adapter.record_evaluation(
          "Evaluator#{i}",
          score: 0.8,
          success: true,
          duration_ms: 50
        )
      end

      4.times do |i|
        adapter.record_performance(
          "operation_#{i}",
          duration_ms: 100 + (i * 50),
          status: i.even? ? "success" : "failure"
        )
      end

      adapter.record_error("TestError", severity: "critical")
    end

    it "returns comprehensive statistics" do
      stats = adapter.statistics(time_range: 3600)

      expect(stats[:decisions][:total]).to eq(3)
      expect(stats[:decisions][:average_confidence]).to be_within(0.01).of(0.6)
      expect(stats[:evaluations][:total]).to eq(2)
      expect(stats[:performance][:total]).to eq(4)
      expect(stats[:errors][:total]).to eq(1)
      expect(stats[:errors][:critical_count]).to eq(1)
    end

    it "handles empty statistics" do
      DecisionLog.delete_all
      EvaluationMetric.delete_all
      PerformanceMetric.delete_all
      ErrorMetric.delete_all

      stats = adapter.statistics(time_range: 3600)

      expect(stats[:decisions][:total]).to eq(0)
      expect(stats[:decisions][:average_confidence]).to eq(0.0)
      expect(stats[:evaluations][:total]).to eq(0)
      expect(stats[:performance][:total]).to eq(0)
      expect(stats[:errors][:total]).to eq(0)
    end

    it "handles decisions without confidence" do
      DecisionLog.delete_all
      adapter.record_decision("test", {}, confidence: nil)

      stats = adapter.statistics(time_range: 3600)
      expect(stats[:decisions][:average_confidence]).to eq(0.0)
    end

    it "handles database errors gracefully" do
      allow(::DecisionLog).to receive(:recent).and_raise(StandardError.new("DB error"))
      stats = adapter.statistics(time_range: 3600)

      expect(stats[:decisions][:total]).to eq(0)
      expect(stats[:evaluations][:total]).to eq(0)
    end
  end

  describe "#time_series" do
    before do
      # Create metrics at different times
      [10, 70, 130].each do |seconds_ago|
        travel_back = Time.now - seconds_ago
        DecisionLog.create!(
          decision: "test",
          confidence: 0.8,
          created_at: travel_back
        )
      end
    end

    it "returns time series data grouped by buckets for decisions" do
      series = adapter.time_series(:decisions, bucket_size: 60, time_range: 200)

      expect(series[:timestamps]).to be_an(Array)
      expect(series[:data]).to be_an(Array)
      expect(series[:data].sum).to eq(3)
    end

    it "returns time series data for evaluations" do
      [10, 70].each do |seconds_ago|
        travel_back = Time.now - seconds_ago
        EvaluationMetric.create!(
          evaluator_name: "test",
          score: 0.8,
          created_at: travel_back
        )
      end

      series = adapter.time_series(:evaluations, bucket_size: 60, time_range: 200)

      expect(series[:timestamps]).to be_an(Array)
      expect(series[:data]).to be_an(Array)
      expect(series[:data].sum).to eq(2)
    end

    it "returns time series data for performance" do
      [10, 70].each do |seconds_ago|
        travel_back = Time.now - seconds_ago
        PerformanceMetric.create!(
          operation: "test",
          duration_ms: 100,
          created_at: travel_back
        )
      end

      series = adapter.time_series(:performance, bucket_size: 60, time_range: 200)

      expect(series[:timestamps]).to be_an(Array)
      expect(series[:data]).to be_an(Array)
    end

    it "returns time series data for errors" do
      [10, 70].each do |seconds_ago|
        travel_back = Time.now - seconds_ago
        ErrorMetric.create!(
          error_type: "TestError",
          created_at: travel_back
        )
      end

      series = adapter.time_series(:errors, bucket_size: 60, time_range: 200)

      expect(series[:timestamps]).to be_an(Array)
      expect(series[:data]).to be_an(Array)
      expect(series[:data].sum).to eq(2)
    end

    it "returns empty data for unknown metric type" do
      series = adapter.time_series(:unknown, bucket_size: 60, time_range: 200)

      expect(series[:timestamps]).to eq([])
      expect(series[:data]).to eq([])
    end

    it "handles database errors gracefully" do
      allow(::DecisionLog).to receive(:recent).and_raise(StandardError.new("DB error"))
      series = adapter.time_series(:decisions, bucket_size: 60, time_range: 200)

      expect(series[:timestamps]).to eq([])
      expect(series[:data]).to eq([])
    end
  end

  describe "#metrics_count" do
    before do
      adapter.record_decision("test", {}, confidence: 0.8)
      adapter.record_evaluation("TestEval", score: 0.9)
      adapter.record_performance("test_op", duration_ms: 100)
      adapter.record_error("TestError")
    end

    it "returns count of all metric types" do
      counts = adapter.metrics_count

      expect(counts[:decisions]).to eq(1)
      expect(counts[:evaluations]).to eq(1)
      expect(counts[:performance]).to eq(1)
      expect(counts[:errors]).to eq(1)
    end

    it "handles database errors gracefully" do
      allow(::DecisionLog).to receive(:count).and_raise(StandardError.new("DB error"))
      counts = adapter.metrics_count

      expect(counts[:decisions]).to eq(0)
      expect(counts[:evaluations]).to eq(0)
      expect(counts[:performance]).to eq(0)
      expect(counts[:errors]).to eq(0)
    end
  end

  describe "#cleanup" do
    before do
      # Create old metrics
      old_time = Time.now - 8.days
      DecisionLog.create!(decision: "old", confidence: 0.8, created_at: old_time)
      EvaluationMetric.create!(evaluator_name: "old", created_at: old_time)
      PerformanceMetric.create!(operation: "old", created_at: old_time)
      ErrorMetric.create!(error_type: "old", created_at: old_time)

      # Create recent metrics
      adapter.record_decision("recent", {}, confidence: 0.8)
      adapter.record_evaluation("recent", score: 0.9)
      adapter.record_performance("recent", duration_ms: 100)
      adapter.record_error("recent")
    end

    it "removes old metrics and keeps recent ones" do
      count = adapter.cleanup(older_than: 7.days.to_i)

      expect(count).to eq(4) # 4 old metrics removed
      expect(DecisionLog.count).to eq(1)
      expect(EvaluationMetric.count).to eq(1)
      expect(PerformanceMetric.count).to eq(1)
      expect(ErrorMetric.count).to eq(1)
    end

    it "handles database errors gracefully" do
      allow(::DecisionLog).to receive(:where).and_raise(StandardError.new("DB error"))
      count = adapter.cleanup(older_than: 7.days.to_i)

      expect(count).to eq(0)
    end
  end

  describe "#initialize" do
    it "validates required models exist" do
      expect { described_class.new }.not_to raise_error
    end
  end
end
