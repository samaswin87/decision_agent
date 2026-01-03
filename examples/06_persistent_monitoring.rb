#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Persistent Monitoring with Database Storage
#
# This example demonstrates:
# 1. Setting up persistent database storage for metrics
# 2. Recording decisions with database persistence
# 3. Querying historical metrics from the database
# 4. Cleanup and archival strategies
# 5. Comparing memory vs database storage

require "bundler/setup"
require "active_record"
require "decision_agent"

# Setup in-memory SQLite database for demonstration
# In production, use your actual database configuration
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

# Create monitoring tables
ActiveRecord::Schema.define do
  create_table :decision_logs do |t|
    t.string :decision, null: false
    t.float :confidence
    t.integer :evaluations_count, default: 0
    t.float :duration_ms
    t.string :status
    t.text :context
    t.text :metadata
    t.timestamps
  end

  create_table :evaluation_metrics do |t|
    t.references :decision_log, foreign_key: true
    t.string :evaluator_name, null: false
    t.float :score
    t.boolean :success
    t.float :duration_ms
    t.text :details
    t.timestamps
  end

  create_table :performance_metrics do |t|
    t.string :operation, null: false
    t.float :duration_ms
    t.string :status
    t.text :metadata
    t.timestamps
  end

  create_table :error_metrics do |t|
    t.string :error_type, null: false
    t.text :message
    t.text :stack_trace
    t.string :severity
    t.text :context
    t.timestamps
  end

  add_index :decision_logs, :decision
  add_index :decision_logs, :created_at
  add_index :evaluation_metrics, :evaluator_name
  add_index :performance_metrics, :operation
  add_index :error_metrics, :error_type
end

# Define ActiveRecord models
class DecisionLog < ActiveRecord::Base
  has_many :evaluation_metrics, dependent: :destroy

  scope :recent, ->(time_range) { where("created_at >= ?", Time.now - time_range) }
  scope :successful, -> { where(status: "success") }
  scope :by_decision, ->(decision) { where(decision: decision) }

  def self.success_rate(time_range: 3600)
    total = recent(time_range).where.not(status: nil).count
    return 0.0 if total.zero?

    successful.recent(time_range).count.to_f / total
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
end

class PerformanceMetric < ActiveRecord::Base
  scope :recent, ->(time_range) { where("created_at >= ?", Time.now - time_range) }

  def self.average_duration(time_range: 3600)
    recent(time_range).average(:duration_ms).to_f
  end

  def self.p95(time_range: 3600)
    durations = recent(time_range).where.not(duration_ms: nil).order(:duration_ms).pluck(:duration_ms)
    return 0.0 if durations.empty?

    durations[(durations.length * 0.95).ceil - 1].to_f
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
end

puts "=" * 80
puts "Decision Agent - Persistent Monitoring Example"
puts "=" * 80
puts

# Example 1: Compare Storage Adapters
puts "1. Storage Adapter Comparison"
puts "-" * 80

# Memory storage
memory_collector = DecisionAgent::Monitoring::MetricsCollector.new(storage: :memory, window_size: 3600)
puts "Memory Adapter: #{memory_collector.storage_adapter.class.name}"
puts "  - Persistence: No (lost on restart)"
puts "  - Retention: 1 hour (configurable window)"
puts "  - Dependencies: None"
puts

# Database storage
db_collector = DecisionAgent::Monitoring::MetricsCollector.new(storage: :auto)
puts "Database Adapter: #{db_collector.storage_adapter.class.name}"
puts "  - Persistence: Yes (survives restarts)"
puts "  - Retention: Unlimited (with cleanup)"
puts "  - Dependencies: ActiveRecord + Database"
puts

# Example 2: Record Metrics with Database Persistence
puts "2. Recording Metrics to Database"
puts "-" * 80

# Create custom evaluators
class FraudDetectionEvaluator < DecisionAgent::Evaluators::Base
  def evaluate(context, feedback: {})
    amount = context[:amount] || context["amount"]
    return nil unless amount

    confidence = amount > 10_000 ? 0.3 : 0.9
    DecisionAgent::Evaluation.new(
      decision: amount > 10_000 ? "review" : "approve",
      weight: confidence,
      reason: "Fraud detection: amount #{amount > 10_000 ? 'exceeds' : 'within'} threshold",
      evaluator_name: "FraudDetection"
    )
  end
end

class CreditScoreEvaluator < DecisionAgent::Evaluators::Base
  def evaluate(context, feedback: {})
    credit_score = context[:credit_score] || context["credit_score"]
    return nil unless credit_score

    confidence = credit_score >= 700 ? 0.8 : 0.4
    DecisionAgent::Evaluation.new(
      decision: credit_score >= 700 ? "approve" : "review",
      weight: confidence,
      reason: "Credit score: #{credit_score}",
      evaluator_name: "CreditScore"
    )
  end
end

fraud_evaluator = FraudDetectionEvaluator.new
credit_evaluator = CreditScoreEvaluator.new

agent = DecisionAgent::Agent.new(evaluators: [fraud_evaluator, credit_evaluator])

# Monitor the agent
monitored_agent = DecisionAgent::Monitoring::MonitoredAgent.new(
  agent: agent,
  metrics_collector: db_collector
)

# Simulate some transactions
transactions = [
  { user_id: 1, amount: 5000, credit_score: 750 },
  { user_id: 2, amount: 15_000, credit_score: 720 },
  { user_id: 3, amount: 3000, credit_score: 650 },
  { user_id: 4, amount: 8000, credit_score: 800 },
  { user_id: 5, amount: 20_000, credit_score: 680 }
]

puts "Processing #{transactions.size} transactions..."
transactions.each_with_index do |transaction, i|
  result = monitored_agent.decide(context: transaction)
  decision = result.decision

  puts "  Transaction #{i + 1}: #{decision} (confidence: #{result.confidence.round(3)})"

  # Record performance metric
  db_collector.record_performance(
    operation: "process_transaction",
    duration_ms: rand(50..200),
    success: true,
    metadata: { user_id: transaction[:user_id] }
  )
end
puts

# Example 3: Query Database Directly
puts "3. Querying Database Records"
puts "-" * 80

puts "Total decisions in database: #{DecisionLog.count}"
puts "Total evaluations in database: #{EvaluationMetric.count}"
puts "Total performance metrics: #{PerformanceMetric.count}"
puts

puts "Decisions by type:"
DecisionLog.group(:decision).count.each do |decision, count|
  puts "  #{decision}: #{count}"
end
puts

puts "Evaluations by evaluator:"
EvaluationMetric.group(:evaluator_name).count.each do |evaluator, count|
  puts "  #{evaluator}: #{count}"
end
puts

# Example 4: Statistics from Database
puts "4. Statistics from Persistent Storage"
puts "-" * 80

stats = db_collector.statistics(time_range: 3600)

puts "Decision Statistics:"
puts "  Total: #{stats[:decisions][:total]}"
puts "  Average Confidence: #{stats[:decisions][:average_confidence].round(3)}"
puts "  Success Rate: #{(stats[:decisions][:success_rate] * 100).round(1)}%"
puts

puts "Performance Statistics:"
puts "  Total Operations: #{stats[:performance][:total]}"
puts "  Average Duration: #{stats[:performance][:average_duration_ms].round(2)} ms"
puts "  P95 Latency: #{stats[:performance][:p95].round(2)} ms"
puts "  Success Rate: #{(stats[:performance][:success_rate] * 100).round(1)}%"
puts

# Example 5: Historical Analysis
puts "5. Historical Data Analysis"
puts "-" * 80

# Simulate passage of time by creating backdated records
old_time = Time.now - (2 * 24 * 3600) # 2 days ago

DecisionLog.create!(
  decision: "approve",
  confidence: 0.75,
  status: "success",
  context: { note: "Historical record" }.to_json,
  created_at: old_time
)

puts "Records from last hour: #{DecisionLog.recent(3600).count}"
puts "Records from last 24 hours: #{DecisionLog.recent(86_400).count}"
puts "All records: #{DecisionLog.count}"
puts

# Example 6: Cleanup Old Metrics
puts "6. Cleanup Old Metrics"
puts "-" * 80

# Create some old records
5.times do |i|
  DecisionLog.create!(
    decision: "old_decision_#{i}",
    confidence: 0.5,
    status: "success",
    context: {}.to_json,
    created_at: Time.now - (8 * 24 * 3600) # 8 days ago
  )
end

puts "Before cleanup:"
puts "  Total decisions: #{DecisionLog.count}"
puts "  Recent (7 days): #{DecisionLog.recent(7 * 24 * 3600).count}"
puts

# Cleanup metrics older than 7 days
removed = db_collector.cleanup_old_metrics_from_storage(older_than: 7 * 24 * 3600)

puts "After cleanup (removed #{removed} old records):"
puts "  Total decisions: #{DecisionLog.count}"
puts "  Recent (7 days): #{DecisionLog.recent(7 * 24 * 3600).count}"
puts

# Example 7: Error Tracking
puts "7. Error Tracking with Severity"
puts "-" * 80

# Simulate some errors
begin
  raise ArgumentError, "Invalid payment amount"
rescue StandardError => e
  db_collector.record_error(e, context: { user_id: 123 })
end

begin
  raise StandardError, "Database connection timeout"
rescue StandardError => e
  db_collector.record_error(e, context: { database: "primary" })
end

puts "Total errors tracked: #{ErrorMetric.count}"
puts "Errors by type:"
ErrorMetric.group(:error_type).count.each do |type, count|
  puts "  #{type}: #{count}"
end
puts "Critical errors: #{ErrorMetric.critical.count}"
puts

# Example 8: Metrics Count
puts "8. Metrics Storage Summary"
puts "-" * 80

counts = db_collector.metrics_count

puts "Metrics stored in database:"
counts.each do |type, count|
  puts "  #{type}: #{count}"
end
puts

total = counts.values.sum
estimated_size = total * 500 # Rough estimate: 500 bytes per metric
puts "Estimated storage: ~#{(estimated_size / 1024.0).round(2)} KB"
puts

# Example 9: Compare with Memory Storage
puts "9. Memory vs Database Storage"
puts "-" * 80

# Record same data to memory storage
transactions.each do |transaction|
  agent.decide(context: transaction)
  memory_collector.record_performance(
    operation: "process_transaction",
    duration_ms: rand(50..200),
    success: true
  )
end

puts "Memory Storage:"
puts "  Decisions: #{memory_collector.metrics_count[:decisions]}"
puts "  Performance: #{memory_collector.metrics_count[:performance]}"
puts "  Persistence: No (in-memory only)"
puts

puts "Database Storage:"
puts "  Decisions: #{db_collector.metrics_count[:decisions]}"
puts "  Performance: #{db_collector.metrics_count[:performance]}"
puts "  Persistence: Yes (survives restart)"
puts

# Example 10: Custom Queries
puts "10. Custom ActiveRecord Queries"
puts "-" * 80

# High confidence decisions
high_confidence = DecisionLog.where("confidence >= ?", 0.8)
puts "High confidence decisions (>= 0.8): #{high_confidence.count}"

# Recent successful decisions
recent_success = DecisionLog.successful.recent(3600)
puts "Recent successful decisions: #{recent_success.count}"

# Performance metrics for specific operation
transaction_metrics = PerformanceMetric.where(operation: "process_transaction")
avg_duration = transaction_metrics.average(:duration_ms)
puts "Average transaction duration: #{avg_duration.round(2)} ms"
puts

puts "=" * 80
puts "Example completed!"
puts "=" * 80
puts
puts "Key Takeaways:"
puts "1. Database storage provides persistence across restarts"
puts "2. ActiveRecord models enable powerful querying capabilities"
puts "3. Cleanup strategies prevent unbounded database growth"
puts "4. Both storage options can coexist (memory for real-time, DB for history)"
puts "5. Statistics automatically query from database when available"
