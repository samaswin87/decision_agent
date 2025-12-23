# Grafana Dashboards for DecisionAgent

This directory contains pre-built Grafana dashboards and Prometheus configurations for monitoring DecisionAgent.

## Contents

- `decision_agent_dashboard.json` - Main monitoring dashboard
- `prometheus.yml` - Prometheus configuration
- `alert_rules.yml` - Prometheus alert rules

## Quick Start

### 1. Start Prometheus

```bash
# Using the included configuration
prometheus --config.file=grafana/prometheus.yml

# Or with Docker
docker run -d \
  --name prometheus \
  -p 9090:9090 \
  -v $(pwd)/grafana/prometheus.yml:/etc/prometheus/prometheus.yml \
  -v $(pwd)/grafana/alert_rules.yml:/etc/prometheus/alert_rules.yml \
  prom/prometheus \
  --config.file=/etc/prometheus/prometheus.yml
```

### 2. Start Grafana

```bash
# With Docker
docker run -d \
  --name grafana \
  -p 3000:3000 \
  -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
  grafana/grafana

# Or install locally
brew install grafana  # macOS
# or
apt-get install grafana  # Ubuntu/Debian
```

### 3. Configure Prometheus Datasource

1. Open Grafana at http://localhost:3000
2. Login with admin/admin
3. Go to Configuration → Data Sources
4. Add Prometheus datasource
5. Set URL to `http://localhost:9090`
6. Click "Save & Test"

### 4. Import Dashboard

1. Go to Dashboards → Import
2. Upload `decision_agent_dashboard.json`
3. Select your Prometheus datasource
4. Click Import

## Dashboard Panels

### Summary Stats (Top Row)
- **Total Decisions** - Counter of all decisions made
- **Average Confidence** - Mean confidence score (with thresholds)
- **Success Rate** - Percentage of successful operations
- **P95 Latency** - 95th percentile latency in ms

### Time Series Charts
- **Decision Throughput** - Decisions per second over time
- **Decision Distribution** - Pie chart showing decision types
- **Performance Metrics** - P95, P99, and average latency
- **Error Rate** - Errors per second
- **Decision Confidence** - Confidence trend over time

## Alert Rules

All alert rules are defined in `alert_rules.yml`:

### Critical Alerts
- **HighErrorRate** - Error rate > 10% for 1 minute
- **CriticalLatency** - P99 latency > 5000ms for 1 minute
- **CriticalSuccessRate** - Success rate < 50% for 1 minute
- **ErrorSpike** - Sudden 4x increase in errors

### Warning Alerts
- **LowDecisionConfidence** - Avg confidence < 50% for 5 minutes
- **HighLatency** - P95 latency > 1000ms for 2 minutes
- **LowSuccessRate** - Success rate < 90% for 3 minutes
- **DecisionThroughputAnomaly** - Throughput deviates from normal
- **NoRecentDecisions** - No decisions for 10 minutes
- **HighMetricsStorage** - Too many metrics in memory

## Customization

### Modify Dashboard

1. Open the dashboard in Grafana
2. Click the panel title → Edit
3. Modify queries, thresholds, or visualizations
4. Save changes
5. Export JSON via Dashboard settings → JSON Model
6. Replace `decision_agent_dashboard.json` with updated version

### Add Custom Panels

Example: Add a panel for custom KPI

```json
{
  "datasource": "Prometheus",
  "targets": [
    {
      "expr": "your_app_custom_kpi_name",
      "legendFormat": "Custom KPI",
      "refId": "A"
    }
  ],
  "title": "Custom Business Metric",
  "type": "graph"
}
```

### Modify Alert Thresholds

Edit `alert_rules.yml`:

```yaml
- alert: HighErrorRate
  expr: rate(decision_agent_errors_total[5m]) > 0.05  # Change threshold
  for: 2m  # Change duration
  labels:
    severity: warning  # Change severity
```

## Prometheus Queries

Useful queries for creating custom panels:

```promql
# Decision rate (decisions per second)
rate(decision_agent_decisions_total[5m])

# Error percentage
rate(decision_agent_errors_total[5m]) / rate(decision_agent_decisions_total[5m])

# Average confidence
decision_agent_decision_confidence_avg

# Latency percentiles
decision_agent_operation_duration_ms{quantile="0.95"}
decision_agent_operation_duration_ms{quantile="0.99"}

# Success rate
decision_agent_success_rate

# Decisions by type
decision_agent_decisions_by_type{decision="approve"}

# Errors by type
decision_agent_errors_by_type{error="StandardError"}

# Operations per second by success
rate(decision_agent_operation_duration_ms_count[5m])

# Average duration
decision_agent_operation_duration_ms_sum / decision_agent_operation_duration_ms_count
```

## Integration with Alertmanager

### 1. Install Alertmanager

```bash
docker run -d \
  --name alertmanager \
  -p 9093:9093 \
  -v $(pwd)/grafana/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
  prom/alertmanager
```

### 2. Configure Notifications

Create `alertmanager.yml`:

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: 'default'
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h

receivers:
  - name: 'default'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

    email_configs:
      - to: 'ops@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.example.com:587'
        auth_username: 'alerts'
        auth_password: 'password'

    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'
```

## Docker Compose Setup

Complete monitoring stack:

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./grafana/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./grafana/alert_rules.yml:/etc/prometheus/alert_rules.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/decision_agent_dashboard.json:/etc/grafana/provisioning/dashboards/decision_agent.json
    depends_on:
      - prometheus

  alertmanager:
    image: prom/alertmanager:latest
    ports:
      - "9093:9093"
    volumes:
      - ./grafana/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager-data:/alertmanager

volumes:
  prometheus-data:
  grafana-data:
  alertmanager-data:
```

Start the stack:

```bash
docker-compose up -d
```

## Troubleshooting

### Dashboard shows "No Data"

1. Verify Prometheus is scraping metrics:
   - Open http://localhost:9090/targets
   - Check `decision_agent` target status

2. Verify metrics endpoint is accessible:
   ```bash
   curl http://localhost:4568/metrics
   ```

3. Check Grafana datasource:
   - Configuration → Data Sources → Prometheus
   - Click "Test" button

### Alerts not firing

1. Check Prometheus rules:
   ```bash
   curl http://localhost:9090/api/v1/rules
   ```

2. Verify alert conditions in `alert_rules.yml`

3. Check Prometheus logs:
   ```bash
   docker logs prometheus
   ```

### High memory usage

Reduce Prometheus retention:

```yaml
# prometheus.yml
global:
  scrape_interval: 30s  # Increase interval

# Add to command
--storage.tsdb.retention.time=7d  # Reduce retention
```

## Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Alerting](https://grafana.com/docs/grafana/latest/alerting/)

## Support

For issues specific to DecisionAgent monitoring:
- [GitHub Issues](https://github.com/samaswin87/decision_agent/issues)
- [Monitoring Documentation](../wiki/MONITORING_AND_ANALYTICS.md)
