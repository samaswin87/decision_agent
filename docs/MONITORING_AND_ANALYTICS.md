# Monitoring and Analytics

Complete guide to monitoring, analytics, and alerting for DecisionAgent.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Components](#components)
- [Real-Time Dashboard](#real-time-dashboard)
- [Prometheus Integration](#prometheus-integration)
- [Grafana Setup](#grafana-setup)
- [Alert Management](#alert-management)
- [Custom KPIs](#custom-kpis)
- [API Reference](#api-reference)
- [Production Deployment](#production-deployment)

## Overview

DecisionAgent provides a comprehensive monitoring and analytics system that includes:

- **Real-time metrics collection** - Track every decision with < 1 second latency
- **Interactive dashboard** - WebSocket-powered live monitoring UI
- **Prometheus export** - Industry-standard metrics format
- **Intelligent alerting** - Anomaly detection with customizable rules
- **Grafana integration** - Pre-built dashboards for visualization
- **Custom KPIs** - Track your own business metrics

### Performance

- Dashboard updates in real-time (<1 second delay)
- Metrics exported in Prometheus format
- Alerts triggered within 1 minute of anomaly detection
- Thread-safe and production-ready

## Quick Start

### 1. Install Dependencies

```ruby
# Gemfile
gem 'decision_agent'
gem 'faye-websocket'  # For real-time dashboard
gem 'puma'            # WebSocket support
```

### 2. Basic Setup

```ruby
require 'decision_agent'
require 'decision_agent/monitoring/metrics_collector'
require 'decision_agent/monitoring/prometheus_exporter'
require 'decision_agent/monitoring/alert_manager'
require 'decision_agent/monitoring/dashboard_server'

# Initialize components
collector = DecisionAgent::Monitoring::MetricsCollector.new(
  window_size: 3600  # Keep 1 hour of metrics in memory
)

prometheus = DecisionAgent::Monitoring::PrometheusExporter.new(
  metrics_collector: collector,
  namespace: 'decision_agent'
)

alert_manager = DecisionAgent::Monitoring::AlertManager.new(
  metrics_collector: collector
)

# Start real-time dashboard
DecisionAgent::Monitoring::DashboardServer.start!(
  port: 4568,
  metrics_collector: collector,
  prometheus_exporter: prometheus,
  alert_manager: alert_manager
)
```

### 3. Integrate with Decision Agent

```ruby
# Create agent
agent = DecisionAgent::Agent.new(evaluators: [evaluator])

# Make decision and record metrics
start_time = Time.now
result = agent.decide(context: { amount: 1500 })
duration_ms = (Time.now - start_time) * 1000

# Record decision
collector.record_decision(result, context, duration_ms: duration_ms)
```

### 4. Access Dashboard

Open [http://localhost:4568](http://localhost:4568) in your browser.

## Components

### MetricsCollector

Thread-safe metrics collection and aggregation.

```ruby
collector = DecisionAgent::Monitoring::MetricsCollector.new(
  window_size: 3600  # Metrics retention window in seconds
)

# Record decision
collector.record_decision(decision, context, duration_ms: 25.5)

# Record performance
collector.record_performance(
  operation: 'decide',
  duration_ms: 10.5,
  success: true,
  metadata: { evaluators: 2 }
)

# Record error
collector.record_error(error, context: { user_id: 123 })

# Get statistics
stats = collector.statistics(time_range: 300)  # Last 5 minutes

# Get time series data
series = collector.time_series(
  metric_type: :decisions,
  bucket_size: 60,     # 1 minute buckets
  time_range: 3600     # Last hour
)

# Real-time updates
collector.add_observer do |event_type, metric|
  puts "New #{event_type}: #{metric}"
end
```

### PrometheusExporter

Export metrics in Prometheus format.

```ruby
exporter = DecisionAgent::Monitoring::PrometheusExporter.new(
  metrics_collector: collector,
  namespace: 'my_app'
)

# Export metrics (text format)
puts exporter.export

# Get metrics as hash
metrics = exporter.metrics_hash

# Register custom KPI
exporter.register_kpi(
  name: 'business_revenue',
  value: 50000.00,
  labels: { region: 'us-east', product: 'premium' },
  help: 'Total business revenue'
)
```

### AlertManager

Intelligent anomaly detection and alerting.

```ruby
alert_manager = DecisionAgent::Monitoring::AlertManager.new(
  metrics_collector: collector
)

# Add alert rule with built-in condition
alert_manager.add_rule(
  name: 'High Error Rate',
  condition: AlertManager.high_error_rate(threshold: 0.1),
  severity: :critical,
  message: 'Error rate exceeded 10%',
  cooldown: 300  # 5 minutes between alerts
)

# Add custom alert rule
alert_manager.add_rule(
  name: 'Low Confidence',
  condition: ->(stats) {
    avg = stats.dig(:decisions, :avg_confidence)
    avg && avg < 0.5
  },
  severity: :warning
)

# Hash-based condition (simple)
alert_manager.add_rule(
  name: 'Error Threshold',
  condition: { metric: 'errors.total', op: 'gt', value: 100 },
  severity: :critical
)

# Register alert handler
alert_manager.add_handler do |alert|
  # Send to Slack, PagerDuty, email, etc.
  puts "ALERT: #{alert[:message]}"
  SlackNotifier.notify(alert)
end

# Start background monitoring
alert_manager.start_monitoring(interval: 60)

# Manual check
alert_manager.check_rules

# Get active alerts
active = alert_manager.active_alerts

# Acknowledge alert
alert_manager.acknowledge_alert(alert_id, acknowledged_by: 'admin')

# Resolve alert
alert_manager.resolve_alert(alert_id, resolved_by: 'system')
```

### Built-in Alert Conditions

```ruby
# High error rate (default: 10%)
AlertManager.high_error_rate(threshold: 0.1)

# Low confidence (default: 50%)
AlertManager.low_confidence(threshold: 0.5)

# High latency (default: 1000ms)
AlertManager.high_latency(threshold_ms: 1000)

# Error spike (default: 10 errors)
AlertManager.error_spike(threshold: 10, time_window: 300)

# Decision anomaly (rate-based)
AlertManager.decision_anomaly(expected_rate: 100, variance: 0.3)
```

## Real-Time Dashboard

### Features

- **Live Updates** - WebSocket-powered real-time metrics
- **Interactive Charts** - Decision throughput, performance, error rates
- **Alert Management** - View, acknowledge, and resolve alerts
- **Custom KPIs** - Register and track business metrics
- **System Health** - Monitor component status

### Dashboard Sections

1. **Summary Cards** - Total decisions, confidence, success rate, latency, errors
2. **Time Series Charts** - Throughput, performance (P95/P99), error rate
3. **Distribution Charts** - Decision types, evaluator usage
4. **Alerts Table** - Active alerts with acknowledge/resolve actions
5. **System Metrics** - Version, connections, memory usage

### API Endpoints

```bash
# Get current statistics
GET /api/stats?time_range=300

# Get time series data
GET /api/timeseries/decisions?bucket_size=60&time_range=3600

# Prometheus metrics (text)
GET /metrics

# Prometheus metrics (JSON)
GET /api/metrics

# Active alerts
GET /api/alerts

# All alerts (with history)
GET /api/alerts/all?limit=100

# Create alert rule
POST /api/alerts/rules
{
  "name": "High Latency",
  "condition_type": "high_latency",
  "condition": { "threshold_ms": 500 },
  "severity": "warning"
}

# Acknowledge alert
POST /api/alerts/:alert_id/acknowledge
{ "acknowledged_by": "admin" }

# Resolve alert
POST /api/alerts/:alert_id/resolve
{ "resolved_by": "admin" }

# Register custom KPI
POST /api/kpi
{
  "name": "user_signups",
  "value": 150,
  "labels": { "source": "web" },
  "help": "Total user signups"
}

# Health check
GET /health
```

## Prometheus Integration

### 1. Configure Prometheus

Create `prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'decision_agent'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:4568']
    metrics_path: '/metrics'
```

### 2. Start Prometheus

```bash
prometheus --config.file=prometheus.yml
```

### 3. Available Metrics

```
# Counters
decision_agent_decisions_total
decision_agent_decisions_by_type{decision="approve"}
decision_agent_errors_total
decision_agent_errors_by_type{error="StandardError"}

# Gauges
decision_agent_decision_confidence_avg
decision_agent_success_rate
decision_agent_operation_duration_ms_avg
decision_agent_operation_duration_ms_p95
decision_agent_operation_duration_ms_p99

# Summary
decision_agent_operation_duration_ms{quantile="0.5"}
decision_agent_operation_duration_ms{quantile="0.95"}
decision_agent_operation_duration_ms{quantile="0.99"}
decision_agent_operation_duration_ms_sum
decision_agent_operation_duration_ms_count

# Info
decision_agent_info{version="0.2.0"}
decision_agent_metrics_stored{type="decisions"}
```

## Grafana Setup

### 1. Import Dashboard

The project includes a pre-built Grafana dashboard at `grafana/decision_agent_dashboard.json`.

**Import Steps:**
1. Open Grafana
2. Go to Dashboards → Import
3. Upload `decision_agent_dashboard.json`
4. Select your Prometheus datasource
5. Click Import

### 2. Dashboard Panels

- Total Decisions (Stat)
- Average Confidence (Stat with thresholds)
- Success Rate (Stat with thresholds)
- P95 Latency (Stat with thresholds)
- Decision Throughput (Time series)
- Decision Distribution (Pie chart)
- Performance Metrics (Time series: P95, P99, Average)
- Error Rate (Bar chart)
- Decision Confidence Over Time (Time series)

### 3. Alert Rules

The dashboard includes pre-configured alert rules:

- High Error Rate (>10% error rate for 1 minute)
- Low Decision Confidence (<50% for 5 minutes)
- High Latency (P95 >1000ms for 2 minutes)
- Critical Latency (P99 >5000ms for 1 minute)
- Low Success Rate (<90% for 3 minutes)
- Decision Throughput Anomaly
- No Recent Decisions (10 minutes)
- Error Spike

## Alert Management

### Creating Custom Alerts

```ruby
# Ruby DSL
alert_manager.add_rule(
  name: 'Business Metric Alert',
  condition: ->(stats) {
    # Complex logic
    decisions = stats.dig(:decisions, :total).to_i
    errors = stats.dig(:errors, :total).to_i

    decisions > 100 && (errors.to_f / decisions) > 0.05
  },
  severity: :warning,
  message: 'Error rate is above 5% with significant traffic',
  cooldown: 600  # 10 minutes
)

# Simple hash condition
alert_manager.add_rule(
  name: 'Latency Warning',
  condition: {
    metric: 'performance.p95_duration_ms',
    op: 'gt',
    value: 500
  },
  severity: :warning
)
```

### Alert Handlers

```ruby
# Slack integration
alert_manager.add_handler do |alert|
  Slack::Notifier.new(webhook_url).ping(
    "🚨 #{alert[:severity].upcase}: #{alert[:message]}",
    channel: '#alerts',
    username: 'DecisionAgent'
  )
end

# PagerDuty integration
alert_manager.add_handler do |alert|
  next unless alert[:severity] == :critical

  PagerDuty.trigger(
    service_key: ENV['PAGERDUTY_KEY'],
    description: alert[:message],
    details: alert[:context]
  )
end

# Email notification
alert_manager.add_handler do |alert|
  AlertMailer.critical_alert(alert).deliver_now
end

# Logging
alert_manager.add_handler do |alert|
  Rails.logger.error("Alert triggered: #{alert.to_json}")
end
```

## Custom KPIs

Track business-specific metrics alongside decision metrics.

```ruby
# Revenue tracking
exporter.register_kpi(
  name: 'revenue_per_decision',
  value: 45.50,
  labels: { currency: 'USD', region: 'US' },
  help: 'Average revenue per decision'
)

# User engagement
exporter.register_kpi(
  name: 'user_satisfaction_score',
  value: 4.5,
  labels: { product: 'premium' },
  help: 'User satisfaction score (1-5)'
)

# Business outcomes
exporter.register_kpi(
  name: 'approval_conversion_rate',
  value: 0.85,
  help: 'Percentage of approvals that convert'
)

# Via Dashboard API
curl -X POST http://localhost:4568/api/kpi \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "daily_active_users",
    "value": 10000,
    "labels": { "platform": "web" }
  }'
```

## API Reference

### MetricsCollector API

```ruby
# Initialize
collector = MetricsCollector.new(window_size: 3600)

# Record metrics
collector.record_decision(decision, context, duration_ms: 25.0)
collector.record_evaluation(evaluation)
collector.record_performance(operation:, duration_ms:, success:, metadata:)
collector.record_error(error, context:)

# Retrieve data
collector.statistics(time_range: nil)
collector.time_series(metric_type:, bucket_size:, time_range:)
collector.metrics_count

# Observers
collector.add_observer { |event_type, metric| }

# Management
collector.clear!
```

### PrometheusExporter API

```ruby
# Initialize
exporter = PrometheusExporter.new(metrics_collector:, namespace:)

# Export
exporter.export                    # Text format
exporter.metrics_hash              # Hash format

# Custom KPIs
exporter.register_kpi(name:, value:, labels:, help:)
```

### AlertManager API

```ruby
# Initialize
manager = AlertManager.new(metrics_collector:)

# Rules
manager.add_rule(name:, condition:, severity:, threshold:, message:, cooldown:)
manager.remove_rule(rule_id)
manager.toggle_rule(rule_id, enabled)

# Monitoring
manager.start_monitoring(interval: 60)
manager.stop_monitoring
manager.check_rules

# Alerts
manager.active_alerts
manager.all_alerts(limit: 100)
manager.acknowledge_alert(alert_id, acknowledged_by:)
manager.resolve_alert(alert_id, resolved_by:)
manager.clear_old_alerts(older_than: 86400)

# Handlers
manager.add_handler { |alert| }
```

## Production Deployment

### Rails Integration

```ruby
# config/initializers/decision_agent_monitoring.rb
require 'decision_agent/monitoring/metrics_collector'
require 'decision_agent/monitoring/prometheus_exporter'
require 'decision_agent/monitoring/alert_manager'

# Initialize components
$metrics_collector = DecisionAgent::Monitoring::MetricsCollector.new(
  window_size: 7200  # 2 hours
)

$prometheus_exporter = DecisionAgent::Monitoring::PrometheusExporter.new(
  metrics_collector: $metrics_collector,
  namespace: Rails.application.class.module_parent_name.underscore
)

$alert_manager = DecisionAgent::Monitoring::AlertManager.new(
  metrics_collector: $metrics_collector
)

# Configure alerts
$alert_manager.add_rule(
  name: 'Production Error Rate',
  condition: AlertManager.high_error_rate(threshold: 0.05),
  severity: :critical
)

$alert_manager.add_handler do |alert|
  Slack::Notifier.new(ENV['SLACK_WEBHOOK']).ping(
    "🚨 #{alert[:message]}",
    channel: '#production-alerts'
  )
end

# Start monitoring
$alert_manager.start_monitoring(interval: 30)

# Mount dashboard
# config/routes.rb
require 'decision_agent/monitoring/dashboard_server'

DecisionAgent::Monitoring::DashboardServer.configure_monitoring(
  metrics_collector: $metrics_collector,
  prometheus_exporter: $prometheus_exporter,
  alert_manager: $alert_manager
)

authenticate :user, ->(user) { user.admin? } do
  mount DecisionAgent::Monitoring::DashboardServer, at: '/monitoring'
end
```

### Docker Deployment

```yaml
# docker-compose.yml
version: '3.8'

services:
  decision_agent:
    build: .
    ports:
      - "3000:3000"
      - "4568:4568"  # Monitoring dashboard
    environment:
      - RAILS_ENV=production

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./grafana/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./grafana/alert_rules.yml:/etc/prometheus/alert_rules.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./grafana/decision_agent_dashboard.json:/var/lib/grafana/dashboards/decision_agent.json

volumes:
  grafana-storage:
```

### Environment Variables

```bash
# Dashboard configuration
DASHBOARD_PORT=4568
DASHBOARD_HOST=0.0.0.0

# Metrics retention
METRICS_WINDOW_SIZE=7200  # 2 hours

# Alert configuration
ALERT_CHECK_INTERVAL=30
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
PAGERDUTY_SERVICE_KEY=xxx
```

### Performance Tuning

```ruby
# Adjust window size based on traffic
collector = MetricsCollector.new(
  window_size: 3600  # Lower for high traffic
)

# Monitor memory usage
total_metrics = collector.metrics_count.values.sum
puts "Metrics in memory: #{total_metrics}"

# Clear old metrics manually if needed
collector.clear! if total_metrics > 100_000
```

### Security

```ruby
# Protect dashboard with authentication
# config/routes.rb
authenticate :user, ->(user) { user.admin? } do
  mount DecisionAgent::Monitoring::DashboardServer, at: '/monitoring'
end

# IP whitelist for Prometheus
# In dashboard_server.rb or reverse proxy
before '/metrics' do
  allowed_ips = ['10.0.0.0/8', '172.16.0.0/12']
  halt 403 unless allowed_ips.any? { |ip| IPAddr.new(ip).include?(request.ip) }
end
```

## Best Practices

1. **Set appropriate window_size** - Balance memory usage vs data retention
2. **Use alert cooldowns** - Prevent alert fatigue
3. **Monitor the monitors** - Track metrics storage and dashboard health
4. **Export to external systems** - Don't rely solely on in-memory metrics
5. **Test alert handlers** - Ensure notifications work before incidents
6. **Use Grafana for long-term storage** - In-memory metrics are temporary
7. **Secure the dashboard** - Require authentication in production
8. **Set up alert escalation** - Critical alerts should page on-call

## Troubleshooting

### Dashboard not updating

- Check WebSocket connection in browser console
- Verify dashboard server is running
- Check firewall/proxy WebSocket support

### High memory usage

- Reduce `window_size`
- Clear old metrics: `collector.clear!`
- Monitor with: `collector.metrics_count`

### Alerts not triggering

- Verify rule conditions
- Check if rule is enabled
- Verify monitoring thread is running: `alert_manager.start_monitoring`

### Prometheus scraping fails

- Verify `/metrics` endpoint is accessible
- Check Prometheus logs
- Verify port 4568 is open

## Support

- [GitHub Issues](https://github.com/samaswin/decision_agent/issues)
- [Documentation](README.md)
- [Examples](examples/)

---

**Next Steps:**
- [Web UI Integration](WEB_UI_INTEGRATION.md)
- [API Contract](API_CONTRACT.md)
- [Performance Guide](PERFORMANCE_AND_THREAD_SAFETY.md)
