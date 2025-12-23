#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Monitoring and Analytics
#
# This example demonstrates the complete monitoring and analytics system including:
# - Real-time metrics collection
# - Prometheus export
# - Alert management
# - Dashboard server

require "bundler/setup"
require "decision_agent"
require "decision_agent/monitoring/metrics_collector"
require "decision_agent/monitoring/prometheus_exporter"
require "decision_agent/monitoring/alert_manager"
require "decision_agent/monitoring/dashboard_server"

puts "=" * 80
puts "DecisionAgent Monitoring and Analytics Example"
puts "=" * 80
puts

# 1. Initialize Monitoring Components
puts "1. Initializing monitoring components..."

collector = DecisionAgent::Monitoring::MetricsCollector.new(
  window_size: 3600  # Keep 1 hour of metrics
)

prometheus_exporter = DecisionAgent::Monitoring::PrometheusExporter.new(
  metrics_collector: collector,
  namespace: "example_app"
)

alert_manager = DecisionAgent::Monitoring::AlertManager.new(
  metrics_collector: collector
)

puts "   ✓ Metrics collector initialized"
puts "   ✓ Prometheus exporter initialized"
puts "   ✓ Alert manager initialized"
puts

# 2. Configure Alerts
puts "2. Configuring alert rules..."

alert_manager.add_rule(
  name: "High Error Rate",
  condition: DecisionAgent::Monitoring::AlertManager.high_error_rate(threshold: 0.1),
  severity: :critical,
  message: "Error rate exceeded 10%",
  cooldown: 60
)

alert_manager.add_rule(
  name: "Low Confidence",
  condition: DecisionAgent::Monitoring::AlertManager.low_confidence(threshold: 0.6),
  severity: :warning,
  message: "Average decision confidence is below 60%"
)

alert_manager.add_rule(
  name: "High Latency",
  condition: DecisionAgent::Monitoring::AlertManager.high_latency(threshold_ms: 100),
  severity: :warning,
  message: "P95 latency exceeded 100ms"
)

# Add alert handler
alert_manager.add_handler do |alert|
  puts "   🚨 ALERT [#{alert[:severity].upcase}]: #{alert[:message]}"
  puts "      Triggered at: #{alert[:triggered_at]}"
  puts "      Rule: #{alert[:rule_name]}"
  puts
end

puts "   ✓ Configured 3 alert rules"
puts "   ✓ Added alert handler"
puts

# 3. Set up Real-time Observer
puts "3. Setting up real-time observers..."

collector.add_observer do |event_type, metric|
  case event_type
  when :decision
    puts "   📊 Decision recorded: #{metric[:decision]} (confidence: #{metric[:confidence]})"
  when :error
    puts "   ❌ Error recorded: #{metric[:error_class]}"
  end
end

puts "   ✓ Real-time observers configured"
puts

# 4. Create Decision Agent
puts "4. Creating decision agent..."

rules = {
  version: "1.0",
  ruleset: "approval_rules",
  rules: [
    {
      id: "high_value_approve",
      if: { field: "amount", op: "gte", value: 1000 },
      then: { decision: "approve", weight: 0.9, reason: "High value transaction" }
    },
    {
      id: "low_value_approve",
      if: { field: "amount", op: "lt", value: 1000 },
      then: { decision: "approve", weight: 0.7, reason: "Standard transaction" }
    },
    {
      id: "suspicious_reject",
      if: { field: "risk_score", op: "gt", value: 0.8 },
      then: { decision: "reject", weight: 0.95, reason: "High risk score" }
    }
  ]
}

evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
agent = DecisionAgent::Agent.new(evaluators: [evaluator])

puts "   ✓ Agent created with approval rules"
puts

# 5. Simulate Decision Traffic
puts "5. Simulating decision traffic..."
puts

contexts = [
  { amount: 500, risk_score: 0.2 },
  { amount: 1500, risk_score: 0.3 },
  { amount: 800, risk_score: 0.1 },
  { amount: 2000, risk_score: 0.5 },
  { amount: 300, risk_score: 0.9 },  # Will be rejected (high risk)
  { amount: 1200, risk_score: 0.4 },
  { amount: 5000, risk_score: 0.85 }, # Will be rejected (high risk)
  { amount: 750, risk_score: 0.3 },
  { amount: 1800, risk_score: 0.2 },
  { amount: 400, risk_score: 0.1 }
]

decisions_made = 0
contexts.each do |ctx|
  context = DecisionAgent::Context.new(ctx)

  # Measure decision time
  start_time = Time.now
  begin
    result = agent.decide(context: context)
    duration_ms = (Time.now - start_time) * 1000

    # Record decision metrics
    collector.record_decision(result, context, duration_ms: duration_ms)

    # Record performance metrics
    collector.record_performance(
      operation: "decide",
      duration_ms: duration_ms,
      success: true,
      metadata: { evaluators: result.evaluations.size }
    )

    decisions_made += 1

    # Small delay to simulate real traffic
    sleep 0.1
  rescue => e
    # Record error
    collector.record_error(e, context: ctx)

    # Record failed performance
    duration_ms = (Time.now - start_time) * 1000
    collector.record_performance(
      operation: "decide",
      duration_ms: duration_ms,
      success: false
    )
  end
end

puts "   ✓ Processed #{decisions_made} decisions"
puts

# 6. Check Alerts
puts "6. Checking alert rules..."
alert_manager.check_rules

active_alerts = alert_manager.active_alerts
if active_alerts.empty?
  puts "   ✓ No alerts triggered"
else
  puts "   ⚠️  #{active_alerts.size} active alert(s)"
end
puts

# 7. Display Statistics
puts "7. Current statistics:"
puts

stats = collector.statistics

puts "   Summary:"
puts "   - Total Decisions: #{stats[:summary][:total_decisions]}"
puts "   - Total Errors: #{stats[:summary][:total_errors]}"
puts

if stats[:decisions] && stats[:decisions][:total] > 0
  puts "   Decision Metrics:"
  puts "   - Average Confidence: #{stats[:decisions][:avg_confidence].round(3)}"
  puts "   - Min Confidence: #{stats[:decisions][:min_confidence].round(3)}"
  puts "   - Max Confidence: #{stats[:decisions][:max_confidence].round(3)}"

  if stats[:decisions][:avg_duration_ms]
    puts "   - Average Duration: #{stats[:decisions][:avg_duration_ms].round(2)}ms"
  end

  if stats[:decisions][:decision_distribution]
    puts "   - Decision Distribution:"
    stats[:decisions][:decision_distribution].each do |decision, count|
      percentage = (count.to_f / stats[:decisions][:total] * 100).round(1)
      puts "     * #{decision}: #{count} (#{percentage}%)"
    end
  end
  puts
end

if stats[:performance] && stats[:performance][:total_operations] > 0
  puts "   Performance Metrics:"
  puts "   - Total Operations: #{stats[:performance][:total_operations]}"
  puts "   - Success Rate: #{(stats[:performance][:success_rate] * 100).round(1)}%"
  puts "   - Avg Duration: #{stats[:performance][:avg_duration_ms].round(2)}ms"
  puts "   - Min Duration: #{stats[:performance][:min_duration_ms].round(2)}ms"
  puts "   - Max Duration: #{stats[:performance][:max_duration_ms].round(2)}ms"
  puts "   - P95 Duration: #{stats[:performance][:p95_duration_ms].round(2)}ms"
  puts "   - P99 Duration: #{stats[:performance][:p99_duration_ms].round(2)}ms"
  puts
end

# 8. Register Custom KPIs
puts "8. Registering custom KPIs..."

prometheus_exporter.register_kpi(
  name: "business_revenue",
  value: 125000.50,
  labels: { currency: "USD", region: "US" },
  help: "Total business revenue from decisions"
)

prometheus_exporter.register_kpi(
  name: "approval_rate",
  value: stats[:decisions][:decision_distribution]["approve"].to_f /
         stats[:decisions][:total],
  help: "Percentage of approved decisions"
)

puts "   ✓ Registered 2 custom KPIs"
puts

# 9. Export Prometheus Metrics
puts "9. Prometheus metrics export (sample):"
puts

prometheus_output = prometheus_exporter.export
sample_lines = prometheus_output.split("\n").select { |line| line.start_with?("example_app_") }.first(10)
sample_lines.each { |line| puts "   #{line}" }
puts "   ... (#{prometheus_output.split("\n").size} total lines)"
puts

# 10. Time Series Data
puts "10. Time series data:"
puts

series = collector.time_series(
  metric_type: :decisions,
  bucket_size: 60,
  time_range: 3600
)

if series.any?
  puts "   Decision time series (last hour, 1-minute buckets):"
  series.last(5).each do |bucket|
    puts "   - #{bucket[:timestamp].strftime('%H:%M:%S')}: #{bucket[:count]} decisions"
  end
  puts "   ... (#{series.size} total buckets)"
else
  puts "   No time series data available yet"
end
puts

# 11. Start Dashboard Server (in background)
puts "11. Starting monitoring dashboard..."
puts

puts "   🚀 Dashboard server starting on http://localhost:4568"
puts
puts "   Available endpoints:"
puts "   - Dashboard UI:        http://localhost:4568/"
puts "   - Prometheus metrics:  http://localhost:4568/metrics"
puts "   - API statistics:      http://localhost:4568/api/stats"
puts "   - Health check:        http://localhost:4568/health"
puts
puts "   Press Ctrl+C to stop the server"
puts

# Configure and start dashboard
DecisionAgent::Monitoring::DashboardServer.configure_monitoring(
  metrics_collector: collector,
  prometheus_exporter: prometheus_exporter,
  alert_manager: alert_manager
)

# Start background monitoring
alert_manager.start_monitoring(interval: 30)

# Start dashboard server
begin
  DecisionAgent::Monitoring::DashboardServer.start!(
    port: 4568,
    metrics_collector: collector,
    prometheus_exporter: prometheus_exporter,
    alert_manager: alert_manager
  )
rescue Interrupt
  puts "\n\n   Shutting down gracefully..."
  alert_manager.stop_monitoring
  puts "   ✓ Server stopped"
end
