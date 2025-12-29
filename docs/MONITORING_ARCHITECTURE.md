# Monitoring System Architecture

Visual guide to the DecisionAgent monitoring and analytics architecture.

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            Client Layer                                  │
│                                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │  Browser     │  │  Grafana     │  │  Prometheus  │  │  cURL/API   │ │
│  │  Dashboard   │  │  Dashboard   │  │  Scraper     │  │  Clients    │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘ │
│         │ WebSocket       │ HTTP GET        │ HTTP GET        │ HTTP   │
└─────────┼─────────────────┼─────────────────┼─────────────────┼────────┘
          │                 │                 │                 │
          │                 │                 │                 │
┌─────────▼─────────────────▼─────────────────▼─────────────────▼────────┐
│                       Dashboard Server (Sinatra)                        │
│                                                                          │
│  HTTP Endpoints:                 WebSocket:                             │
│  • GET  /                        • /ws (real-time)                      │
│  • GET  /api/stats               • Broadcasts events                    │
│  • GET  /api/timeseries/:type    • Maintains connections                │
│  • GET  /metrics (Prometheus)                                           │
│  • GET  /api/alerts                                                     │
│  • POST /api/kpi                                                        │
│  • POST /api/alerts/:id/acknowledge                                     │
│                                                                          │
└──────────────────┬───────────────────────┬──────────────────────────────┘
                   │                       │
        ┌──────────▼──────────┐ ┌─────────▼──────────┐
        │ PrometheusExporter  │ │  AlertManager      │
        │                     │ │                    │
        │ • Format metrics    │ │ • Evaluate rules   │
        │ • Export text       │ │ • Trigger alerts   │
        │ • Export JSON       │ │ • Manage lifecycle │
        │ • Register KPIs     │ │ • Notify handlers  │
        └──────────┬──────────┘ └─────────┬──────────┘
                   │                       │
                   └───────┬───────────────┘
                           │
                  ┌────────▼────────┐
                  │ MetricsCollector│
                  │                 │
                  │ Core Engine:    │
                  │ • Store metrics │
                  │ • Compute stats │
                  │ • Time buckets  │
                  │ • Notify obs.   │
                  │ • Cleanup old   │
                  └────────┬────────┘
                           │
                           │ Records metrics
                           │
                  ┌────────▼────────┐
                  │ MonitoredAgent  │
                  │                 │
                  │ • Wraps Agent   │
                  │ • Auto-record   │
                  │ • Error track   │
                  └────────┬────────┘
                           │
                           │ Delegates
                           │
                  ┌────────▼────────┐
                  │ Decision Agent  │
                  │                 │
                  │ • Evaluators    │
                  │ • Make decisions│
                  └─────────────────┘
```

## Data Flow

### 1. Decision Recording Flow

```
User Code
   │
   │ decide(context)
   ▼
MonitoredAgent
   │
   ├─► Start timer
   │
   ├─► Agent.decide(context) ──► Decision Result
   │
   ├─► Calculate duration
   │
   ├─► MetricsCollector.record_decision(result, context, duration)
   │   │
   │   ├─► Store in @metrics[:decisions]
   │   ├─► Cleanup old metrics
   │   └─► Notify observers ──┐
   │                          │
   ├─► MetricsCollector.record_evaluation(eval) for each evaluation
   │                          │
   └─► MetricsCollector.record_performance(...)
                              │
                              │ Observer notification
                              ▼
                        DashboardServer
                              │
                              ├─► Broadcast via WebSocket
                              │        │
                              │        ▼
                              │   Browser clients
                              │   (Real-time update)
                              │
                              └─► AlertManager.check_rules()
                                       │
                                       ├─► Evaluate conditions
                                       ├─► Trigger if matched
                                       └─► Notify handlers
                                            (Slack, email, etc.)
```

### 2. Prometheus Scrape Flow

```
Prometheus
   │
   │ HTTP GET /metrics (every 15s)
   ▼
DashboardServer
   │
   │ calls PrometheusExporter.export()
   ▼
PrometheusExporter
   │
   ├─► MetricsCollector.statistics()
   │        │
   │        └─► Compute aggregations
   │             • Sum, avg, min, max
   │             • Percentiles (P95, P99)
   │             • Distributions
   │
   ├─► Format as Prometheus text
   │    # HELP metric_name Description
   │    # TYPE metric_name type
   │    metric_name{labels} value
   │
   └─► Return text/plain
         │
         ▼
    Prometheus
         │
         └─► Store in TSDB
              │
              └─► Grafana queries
```

### 3. Alert Processing Flow

```
Background Thread (every 60s)
   │
   │ AlertManager.check_rules()
   ▼
For each enabled rule:
   │
   ├─► Get current statistics from MetricsCollector
   │
   ├─► Evaluate condition (Proc or Hash)
   │    Examples:
   │    • ->(stats) { stats.dig(:errors, :total) > 10 }
   │    • { metric: "errors.total", op: "gt", value: 10 }
   │
   ├─► Condition TRUE?
   │    │
   │    ├─► YES: Check cooldown
   │    │    │
   │    │    ├─► In cooldown? Skip
   │    │    │
   │    │    └─► Not in cooldown?
   │    │         │
   │    │         ├─► Create alert
   │    │         ├─► Store in @alerts
   │    │         ├─► Update last_triggered
   │    │         └─► Notify handlers
   │    │              │
   │    │              └─► For each handler:
   │    │                   • Slack notification
   │    │                   • Email alert
   │    │                   • PagerDuty incident
   │    │                   • Log to file
   │    │
   │    └─► NO: Continue
   │
   └─► Next rule
```

### 4. WebSocket Real-Time Updates

```
Browser connects
   │
   │ WebSocket connect to ws://host/ws
   ▼
DashboardServer
   │
   ├─► Add client to @websocket_clients
   │
   ├─► Send initial state
   │    { type: "connected", message: "..." }
   │
   └─► Listen for events

When metric recorded:
   │
   │ MetricsCollector.record_*()
   ▼
Observer callback
   │
   │ notify_observers(event_type, metric)
   ▼
DashboardServer.broadcast_to_clients()
   │
   ├─► For each connected client
   │    │
   │    └─► ws.send({
   │         type: "metric_update",
   │         event: "decision",
   │         data: metric
   │       })
   │
   └─► Clients update UI in real-time
         • Update summary cards
         • Append to charts
         • Show toast notification
```

## Component Interactions

### MetricsCollector (Core)

```
┌──────────────────────────────────────────────┐
│          MetricsCollector                    │
├──────────────────────────────────────────────┤
│ State:                                       │
│  @metrics = {                                │
│    decisions: [...]    # Array of decision   │
│    evaluations: [...]  # Array of evals      │
│    performance: [...]  # Array of perf       │
│    errors: [...]       # Array of errors     │
│  }                                           │
│  @observers = [...]    # Callbacks           │
│  @window_size = 3600   # Retention (1 hour)  │
├──────────────────────────────────────────────┤
│ Operations:                                  │
│  1. record_*() → Store metric + Notify       │
│  2. cleanup_old_metrics!() → Remove expired  │
│  3. statistics() → Compute aggregations      │
│  4. time_series() → Bucket by time           │
│  5. notify_observers() → Call callbacks      │
├──────────────────────────────────────────────┤
│ Thread Safety: Monitor mixin (synchronize)   │
└──────────────────────────────────────────────┘
```

### PrometheusExporter

```
┌──────────────────────────────────────────────┐
│         PrometheusExporter                   │
├──────────────────────────────────────────────┤
│ Inputs:                                      │
│  • MetricsCollector (reads stats)            │
│  • Custom KPIs (@custom_metrics)             │
├──────────────────────────────────────────────┤
│ Outputs:                                     │
│  • Text format (Prometheus 0.0.4)            │
│    # HELP namespace_metric_name Description  │
│    # TYPE namespace_metric_name counter      │
│    namespace_metric_name{labels} value       │
│                                              │
│  • JSON format (for APIs)                    │
│    { metric_name: { type, value } }          │
├──────────────────────────────────────────────┤
│ Operations:                                  │
│  1. export() → Generate Prometheus text      │
│  2. metrics_hash() → Generate JSON           │
│  3. register_kpi() → Add custom metric       │
│  4. sanitize_name() → Clean metric names     │
└──────────────────────────────────────────────┘
```

### AlertManager

```
┌──────────────────────────────────────────────┐
│           AlertManager                       │
├──────────────────────────────────────────────┤
│ State:                                       │
│  @rules = [                                  │
│    { id, name, condition, severity,          │
│      threshold, message, cooldown,           │
│      last_triggered, enabled }               │
│  ]                                           │
│  @alerts = [                                 │
│    { id, rule_id, severity, message,         │
│      triggered_at, status, context }         │
│  ]                                           │
│  @alert_handlers = [callback_functions]      │
│  @monitoring_thread = Thread                 │
├──────────────────────────────────────────────┤
│ Alert Lifecycle:                             │
│  :active → :acknowledged → :resolved          │
├──────────────────────────────────────────────┤
│ Operations:                                  │
│  1. check_rules() → Eval all enabled rules   │
│  2. evaluate_condition() → Run condition     │
│  3. trigger_alert() → Create & notify        │
│  4. in_cooldown?() → Check last trigger      │
│  5. notify_handlers() → Call callbacks       │
└──────────────────────────────────────────────┘
```

## Memory Management

```
Metric Storage Strategy:

Time ─────────────────────────────────────►
      │◄────── window_size (e.g., 3600s) ──►│
      │                                     │
      Old metrics                      Current time
      (deleted)                        (kept in memory)

Cleanup Process:
1. On every record_*() call
2. Calculate: cutoff = Time.now - window_size
3. Delete metrics where timestamp < cutoff
4. Happens automatically, no manual intervention

Memory Usage:
• ~1KB per decision metric
• ~500B per evaluation metric
• ~800B per performance metric
• For 10,000 decisions/hour: ~10MB memory
• Configurable via window_size parameter
```

## Scalability Considerations

### Vertical Scaling (Single Instance)

```
┌─────────────────────────────────────────┐
│   Optimization Strategies                │
├─────────────────────────────────────────┤
│ 1. Reduce window_size                    │
│    • Default: 3600s (1 hour)             │
│    • High traffic: 1800s (30 min)        │
│    • Very high: 900s (15 min)            │
│                                          │
│ 2. Increase check_interval               │
│    • Default: 60s                        │
│    • Low priority: 300s (5 min)          │
│                                          │
│ 3. Selective metric recording            │
│    • Sample: record 1 in N decisions     │
│    • Filter: only record if confidence   │
│               below threshold            │
│                                          │
│ 4. Offload to external storage           │
│    • Export to Prometheus (scrapes)      │
│    • Push to time-series DB              │
│    • Stream to data warehouse            │
└─────────────────────────────────────────┘
```

### Horizontal Scaling (Multiple Instances)

```
┌──────────────────────────────────────────────┐
│        Load Balancer                          │
└────┬─────────────┬─────────────┬──────────────┘
     │             │             │
┌────▼────┐   ┌────▼────┐   ┌────▼────┐
│ App 1   │   │ App 2   │   │ App 3   │
│ +       │   │ +       │   │ +       │
│ Monitor │   │ Monitor │   │ Monitor │
└────┬────┘   └────┬────┘   └────┬────┘
     │             │             │
     │ /metrics    │ /metrics    │ /metrics
     │             │             │
     └─────────────┴─────────────┴───────►
                   │
              ┌────▼─────┐
              │Prometheus│
              │(scrapes  │
              │ all)     │
              └────┬─────┘
                   │
              ┌────▼─────┐
              │ Grafana  │
              │(aggreg-  │
              │ ates)    │
              └──────────┘

Each instance:
• Has own MetricsCollector
• Exports own metrics
• Prometheus aggregates across all
• Grafana shows combined view
```

## Integration Patterns

### Pattern 1: Automatic (Wrapper)

```ruby
collector = MetricsCollector.new
monitored_agent = MonitoredAgent.new(agent: agent, metrics_collector: collector)

# Metrics recorded automatically
result = monitored_agent.decide(context: ctx)
```

### Pattern 2: Manual (Explicit)

```ruby
collector = MetricsCollector.new
agent = Agent.new(evaluators: [evaluator])

start = Time.now
result = agent.decide(context: ctx)
duration = (Time.now - start) * 1000

# Manual recording
collector.record_decision(result, ctx, duration_ms: duration)
```

### Pattern 3: Observer (Callback)

```ruby
collector = MetricsCollector.new

collector.add_observer do |event_type, metric|
  case event_type
  when :decision
    MyAnalytics.track('decision_made', metric)
  when :error
    Bugsnag.notify(metric)
  end
end
```

## Security Considerations

```
┌─────────────────────────────────────────────┐
│          Security Layers                     │
├─────────────────────────────────────────────┤
│ 1. Dashboard Authentication                  │
│    • Rails: use authenticate helper          │
│    • Sinatra: basic auth middleware          │
│                                              │
│ 2. Metrics Endpoint Protection               │
│    • IP whitelist for /metrics               │
│    • API key requirement                     │
│                                              │
│ 3. WebSocket Security                        │
│    • Origin validation                       │
│    • Authentication tokens                   │
│                                              │
│ 4. Data Sanitization                         │
│    • Escape HTML in dashboard                │
│    • Validate metric names                   │
│    • Sanitize label values                   │
└─────────────────────────────────────────────┘
```

## Performance Characteristics

| Operation | Time Complexity | Space Complexity |
|-----------|----------------|------------------|
| record_decision() | O(1) amortized | O(1) |
| record_evaluation() | O(1) amortized | O(1) |
| record_performance() | O(1) amortized | O(1) |
| statistics() | O(n) | O(1) |
| time_series() | O(n + b) | O(b) |
| export() | O(1) | O(1) |
| check_rules() | O(r) | O(1) |

Where:
- n = number of metrics in window
- b = number of time buckets
- r = number of alert rules

## Next Steps

- [Implementation Guide](MONITORING_AND_ANALYTICS.md)
- [Quick Start](../MONITORING_QUICK_START.md)
- [Example Code](../examples/05_monitoring_and_analytics.rb)
- [API Reference](MONITORING_AND_ANALYTICS.md#api-reference)
