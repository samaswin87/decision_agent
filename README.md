# DecisionAgent

[![Gem Version](https://badge.fury.io/rb/decision_agent.svg)](https://badge.fury.io/rb/decision_agent)
[![CI](https://github.com/samaswin87/decision_agent/actions/workflows/ci.yml/badge.svg)](https://github.com/samaswin87/decision_agent/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%202.7.0-red.svg)](https://www.ruby-lang.org)

A production-grade, deterministic, explainable, and auditable decision engine for Ruby.

**Built for regulated domains. Deterministic by design. AI-optional.**

## Why DecisionAgent?

- ✅ **Deterministic** - Same input always produces same output
- ✅ **Explainable** - Every decision includes human-readable reasoning
- ✅ **Auditable** - Reproduce any historical decision exactly
- ✅ **Framework-agnostic** - Pure Ruby, works anywhere
- ✅ **Production-ready** - Comprehensive testing, error handling, and versioning

## Installation

```bash
gem install decision_agent
```

Or add to your Gemfile:
```ruby
gem 'decision_agent'
```

## Quick Start

```ruby
require 'decision_agent'

# Define evaluator with business rules
evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(
  rules_json: {
    version: "1.0",
    ruleset: "approval_rules",
    rules: [{
      id: "high_value",
      if: { field: "amount", op: "gt", value: 1000 },
      then: { decision: "approve", weight: 0.9, reason: "High value transaction" }
    }]
  }
)

# Create decision agent
agent = DecisionAgent::Agent.new(evaluators: [evaluator])

# Make decision
result = agent.decide(context: { amount: 1500 })

puts result.decision      # => "approve"
puts result.confidence    # => 0.9
puts result.explanations  # => ["High value transaction"]
```

## Web UI - Visual Rule Builder

The DecisionAgent Web UI provides a visual interface for building and testing rules.

### Standalone Usage

Launch the visual rule builder:

```bash
decision_agent web
```

Open [http://localhost:4567](http://localhost:4567) in your browser.

### Mount in Rails

Add to your `config/routes.rb`:

```ruby
require 'decision_agent/web/server'

Rails.application.routes.draw do
  # Mount DecisionAgent Web UI
  mount DecisionAgent::Web::Server, at: '/decision_agent'
end
```

Then visit `http://localhost:3000/decision_agent` in your browser.

**With Authentication:**

```ruby
authenticate :user, ->(user) { user.admin? } do
  mount DecisionAgent::Web::Server, at: '/decision_agent'
end
```

### Mount in Rack/Sinatra Apps

```ruby
# config.ru
require 'decision_agent/web/server'

map '/decision_agent' do
  run DecisionAgent::Web::Server
end
```

<img width="1622" height="820" alt="Screenshot" src="https://github.com/user-attachments/assets/687e9ff6-669a-40f9-be27-085c614392d4" />

See [Web UI Rails Integration Guide](docs/WEB_UI_RAILS_INTEGRATION.md) for detailed setup instructions.

## Monitoring & Analytics

Real-time monitoring, metrics, and alerting for production environments.

### Quick Start

```ruby
require 'decision_agent/monitoring/metrics_collector'
require 'decision_agent/monitoring/dashboard_server'

# Initialize metrics collection
collector = DecisionAgent::Monitoring::MetricsCollector.new(window_size: 3600)

# Start real-time dashboard
DecisionAgent::Monitoring::DashboardServer.start!(
  port: 4568,
  metrics_collector: collector
)

# Record decisions
agent = DecisionAgent::Agent.new(evaluators: [evaluator])
result = agent.decide(context: { amount: 1500 })
collector.record_decision(result, context, duration_ms: 25.5)
```

Open [http://localhost:4568](http://localhost:4568) for the monitoring dashboard.

### Features

- **Real-time Dashboard** - Live metrics with WebSocket updates
- **Prometheus Export** - Industry-standard metrics format
- **Intelligent Alerting** - Anomaly detection with customizable rules
- **Grafana Integration** - Pre-built dashboards and alert rules
- **Custom KPIs** - Track business-specific metrics
- **Thread-Safe** - Production-ready performance

### Prometheus & Grafana

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'decision_agent'
    static_configs:
      - targets: ['localhost:4568']
    metrics_path: '/metrics'
```

Import the pre-built Grafana dashboard from [grafana/decision_agent_dashboard.json](grafana/decision_agent_dashboard.json).

### Alert Management

```ruby
alert_manager = DecisionAgent::Monitoring::AlertManager.new(
  metrics_collector: collector
)

# Add alert rules
alert_manager.add_rule(
  name: 'High Error Rate',
  condition: AlertManager.high_error_rate(threshold: 0.1),
  severity: :critical
)

# Register alert handlers
alert_manager.add_handler do |alert|
  SlackNotifier.notify("🚨 #{alert[:message]}")
end

# Start monitoring
alert_manager.start_monitoring(interval: 60)
```

See [Monitoring & Analytics Guide](docs/MONITORING_AND_ANALYTICS.md) for complete documentation.


## Key Features

### Decision Making
- **Multiple Evaluators** - Combine rule-based, ML, and custom logic
- **Conflict Resolution** - Weighted average, consensus, threshold, max weight
- **Rich Context** - Nested data, dot notation, flexible operators

### Auditability
- **Complete Audit Trails** - Every decision fully logged
- **Deterministic Replay** - Reproduce historical decisions exactly
- **Compliance Ready** - HIPAA, SOX, regulatory compliance support

### Flexibility
- **Pluggable Architecture** - Custom evaluators, scoring, audit adapters
- **Framework Agnostic** - Works with Rails, Sinatra, or standalone
- **JSON Rule DSL** - Non-technical users can write rules
- **Visual Rule Builder** - Web UI for rule management

### Advanced Rule Operators
- **String Operators** - `contains`, `starts_with`, `ends_with`, `matches` (regex)
- **Numeric Operators** - `between`, `modulo` (for A/B testing, sharding)
- **Date/Time Operators** - `before_date`, `after_date`, `within_days`, `day_of_week`
- **Collection Operators** - `contains_all`, `contains_any`, `intersects`, `subset_of`
- **Geospatial Operators** - `within_radius` (Haversine), `in_polygon` (ray casting)

### Monitoring & Observability
- **Real-time Metrics** - Live dashboard with WebSocket updates (<1 second latency)
- **Prometheus Export** - Industry-standard metrics format at `/metrics` endpoint
- **Intelligent Alerting** - Anomaly detection with customizable rules and severity levels
- **Grafana Integration** - Pre-built dashboards and alert configurations in `grafana/` directory
- **Custom KPIs** - Track business-specific metrics with thread-safe operations
- **MonitoredAgent** - Drop-in replacement that auto-records all metrics
- **AlertManager** - Built-in anomaly detection (error rates, latency spikes, low confidence)

### Production Ready
- **Comprehensive Testing** - 90%+ code coverage
- **Error Handling** - Clear, actionable error messages
- **Versioning** - Full rule version control and rollback
- **Performance** - Fast, zero external dependencies
- **Thread-Safe** - Safe for multi-threaded servers and background jobs

## Examples

### Example Application

See the complete working example application: [decision_agent_example](https://github.com/samaswin87/decision_agent_example)

This example demonstrates:
- Real-world integration patterns
- Best practices for production usage
- Complete setup and configuration

### Code Examples

```ruby
# Multiple evaluators with conflict resolution
agent = DecisionAgent::Agent.new(
  evaluators: [rule_evaluator, ml_evaluator],
  scoring_strategy: DecisionAgent::Scoring::Consensus.new(minimum_agreement: 0.7),
  audit_adapter: DecisionAgent::Audit::LoggerAdapter.new
)

# Complex rules with nested conditions
rules = {
  version: "1.0",
  ruleset: "fraud_detection",
  rules: [{
    id: "suspicious_activity",
    if: {
      all: [
        { field: "amount", op: "gt", value: 10000 },
        { any: [
          { field: "user.country", op: "in", value: ["XX", "YY"] },
          { field: "velocity", op: "gt", value: 5 }
        ]}
      ]
    },
    then: { decision: "flag_for_review", weight: 0.95, reason: "Suspicious patterns detected" }
  }]
}

# Advanced operators example
advanced_rules = {
  version: "1.0",
  ruleset: "advanced_validation",
  rules: [{
    id: "valid_order",
    if: {
      all: [
        # String: Corporate email domain
        { field: "email", op: "ends_with", value: "@company.com" },
        # Numeric: Age in valid range
        { field: "age", op: "between", value: [18, 65] },
        # Date: Account created recently
        { field: "created_at", op: "within_days", value: 30 },
        # Collection: Has required permissions
        { field: "permissions", op: "contains_all", value: ["read", "write"] },
        # Geospatial: Within delivery zone
        { field: "location", op: "within_radius",
          value: { center: { lat: 40.7128, lon: -74.0060 }, radius: 25 } }
      ]
    },
    then: { decision: "approve", weight: 0.95, reason: "All validation checks passed" }
  }]
}
```

See [examples/](examples/) and [docs/ADVANCED_OPERATORS.md](docs/ADVANCED_OPERATORS.md) for complete working examples.

## Thread-Safety Guarantees

DecisionAgent is designed to be **thread-safe and FAST** for use in multi-threaded environments:

### Performance
- **10,000+ decisions/second** throughput
- **~0.1ms average latency** per decision
- **Zero performance overhead** from thread-safety
- **Linear scalability** with thread count

### Safe Concurrent Usage
- **Agent instances** can be shared across threads safely
- **Evaluators** are immutable after initialization
- **Decisions and Evaluations** are deeply frozen
- **File storage** uses mutex-protected operations

### Best Practices
```ruby
# Safe: Reuse agent instance across threads
agent = DecisionAgent::Agent.new(evaluators: [evaluator])

Thread.new { agent.decide(context: { user_id: 1 }) }
Thread.new { agent.decide(context: { user_id: 2 }) }

# Safe: Share evaluators across agent instances
evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
agent1 = DecisionAgent::Agent.new(evaluators: [evaluator])
agent2 = DecisionAgent::Agent.new(evaluators: [evaluator])
```

### What's Frozen
All data structures are deeply frozen to prevent mutation:
- Decision objects (decision, confidence, explanations, evaluations)
- Evaluation objects (decision, weight, reason, metadata)
- Context data
- Rule definitions in evaluators

This ensures safe concurrent access without race conditions.

### RFC 8785 Canonical JSON
DecisionAgent uses **RFC 8785 (JSON Canonicalization Scheme)** for deterministic audit hashing:

- **Industry Standard** - Official IETF specification for canonical JSON
- **Cryptographically Sound** - Ensures deterministic hashing of decision payloads
- **Reproducible** - Same decision always produces same audit hash
- **Interoperable** - Compatible with other systems using RFC 8785

Every decision includes a deterministic SHA-256 hash in the audit payload, enabling:
- Tamper detection in audit logs
- Exact replay verification
- Regulatory compliance documentation

Learn more: [RFC 8785 Specification](https://datatracker.ietf.org/doc/html/rfc8785)

### Performance Benchmark
Run the included benchmark to verify zero overhead:
```bash
ruby examples/thread_safe_performance.rb
```

See [THREAD_SAFETY.md](docs/THREAD_SAFETY.md) for detailed implementation guide and [PERFORMANCE_AND_THREAD_SAFETY.md](docs/PERFORMANCE_AND_THREAD_SAFETY.md) for detailed performance analysis.

## When to Use DecisionAgent

✅ **Perfect for:**
- Regulated industries (healthcare, finance, legal)
- Complex business rule engines
- Audit trail requirements
- Explainable AI systems
- Multi-step decision workflows

❌ **Not suitable for:**
- Simple if/else logic (use plain Ruby)
- Pure AI/ML with no rules
- Single-step validations

## Documentation

**Getting Started**
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Examples](examples/README.md)

**Core Features**
- [Advanced Operators](docs/ADVANCED_OPERATORS.md) - String, numeric, date/time, collection, and geospatial operators
- [Versioning System](docs/VERSIONING.md) - Version control for rules
- [A/B Testing](docs/AB_TESTING.md) - Compare rule versions with statistical analysis
- [Web UI](docs/WEB_UI.md) - Visual rule builder
- [Web UI Setup](docs/WEB_UI_SETUP.md) - Setup guide
- [Web UI Rails Integration](docs/WEB_UI_RAILS_INTEGRATION.md) - Mount in Rails/Rack apps
- [Monitoring & Analytics](docs/MONITORING_AND_ANALYTICS.md) - Real-time monitoring, metrics, and alerting
- [Monitoring Architecture](docs/MONITORING_ARCHITECTURE.md) - System architecture and design

**Performance & Thread-Safety**
- [Performance & Thread-Safety Summary](docs/PERFORMANCE_AND_THREAD_SAFETY.md) - Benchmarks and production readiness
- [Thread-Safety Implementation](docs/THREAD_SAFETY.md) - Technical implementation guide

**Reference**
- [API Contract](docs/API_CONTRACT.md) - Full API reference
- [Changelog](docs/CHANGELOG.md) - Version history

**More Resources**
- [Documentation Home](docs/README.md) - Documentation index
- [GitHub Issues](https://github.com/samaswin87/decision_agent/issues) - Report bugs or request features

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests (maintain 90%+ coverage)
4. Submit a pull request

## Support

- **Issues**: [GitHub Issues](https://github.com/samaswin87/decision_agent/issues)
- **Documentation**: [Documentation](docs/README.md)
- **Examples**: [examples/](examples/)

## License

MIT License - see [LICENSE.txt](LICENSE.txt)

---

⭐ **Star this repo** if you find it useful!
