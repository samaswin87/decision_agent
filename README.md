# DecisionAgent

[![Gem Version](https://badge.fury.io/rb/decision_agent.svg)](https://badge.fury.io/rb/decision_agent)
[![CI](https://github.com/samaswin/decision_agent/actions/workflows/ci.yml/badge.svg)](https://github.com/samaswin/decision_agent/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%202.7.0-red.svg)](https://www.ruby-lang.org)

A production-grade, deterministic, explainable, and auditable decision engine for Ruby.

**Built for regulated domains. Deterministic by design. AI-optional.**

## Why DecisionAgent?

DecisionAgent is designed for applications that require **deterministic, explainable, and auditable** decision-making:

- ✅ **Deterministic** - Same input always produces same output
- ✅ **Explainable** - Every decision includes human-readable reasoning
- ✅ **Auditable** - Reproduce any historical decision exactly
- ✅ **Framework-agnostic** - Pure Ruby, works anywhere
- ✅ **Production-ready** - Comprehensive testing ([Coverage Report](coverage.md)), error handling, and versioning

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

See [Code Examples](docs/CODE_EXAMPLES.md) for more comprehensive examples.

## Key Features

### Decision Making
- **Multiple Evaluators** - Combine rule-based, ML, and custom logic
- **Conflict Resolution** - Weighted average, consensus, threshold, max weight
- **Rich Context** - Nested data, dot notation, flexible operators
- **Advanced Operators** - String, numeric, date/time, collection, and geospatial operators

### Auditability & Compliance
- **Complete Audit Trails** - Every decision fully logged
- **Deterministic Replay** - Reproduce historical decisions exactly
- **RFC 8785 Canonical JSON** - Industry-standard deterministic hashing
- **Compliance Ready** - HIPAA, SOX, regulatory compliance support

### Developer Experience
- **Pluggable Architecture** - Custom evaluators, scoring, audit adapters
- **Framework Agnostic** - Works with Rails, Sinatra, or standalone
- **JSON Rule DSL** - Non-technical users can write rules
- **DMN 1.3 Support** - Industry-standard Decision Model and Notation with full FEEL expression language
- **Visual Rule Builder** - Web UI for rule management and DMN modeler

### Production Features
- **Real-time Monitoring** - Live dashboard with WebSocket updates
- **Prometheus Export** - Industry-standard metrics format
- **Intelligent Alerting** - Anomaly detection with customizable rules
- **Grafana Integration** - Pre-built dashboards and alert rules
- **Version Control** - Full rule version control and rollback
- **Thread-Safe** - Safe for multi-threaded servers and background jobs
- **High Performance** - 10,000+ decisions/second, ~0.1ms latency

## Web UI - Visual Rule Builder

Launch the visual rule builder:

```bash
decision_agent web
```

Open [http://localhost:4567](http://localhost:4567) in your browser.

### Integration

**Rails:**
```ruby
require 'decision_agent/web/server'
Rails.application.routes.draw do
  mount DecisionAgent::Web::Server, at: '/decision_agent'
end
```

**Rack/Sinatra:**
```ruby
require 'decision_agent/web/server'
map '/decision_agent' do
  run DecisionAgent::Web::Server
end
```

See [Web UI Integration Guide](docs/WEB_UI_RAILS_INTEGRATION.md) for detailed setup.

## DMN (Decision Model and Notation) Support

DecisionAgent includes full support for **DMN 1.3**, the industry standard for decision modeling:

```ruby
require 'decision_agent'
require 'decision_agent/dmn/importer'
require 'decision_agent/evaluators/dmn_evaluator'

# Import DMN XML file
importer = DecisionAgent::Dmn::Importer.new
result = importer.import('path/to/model.dmn', created_by: 'user@example.com')

# Create DMN evaluator
evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: result[:model],
  decision_id: 'loan_approval'
)

# Use with Agent
agent = DecisionAgent::Agent.new(evaluators: [evaluator])
result = agent.decide(context: { amount: 50000, credit_score: 750 })
```

**Features:**
- **DMN 1.3 Standard** - Full OMG DMN 1.3 compliance
- **FEEL Expressions** - Complete FEEL 1.3 language support (arithmetic, logical, functions)
- **All Hit Policies** - UNIQUE, FIRST, PRIORITY, ANY, COLLECT
- **Import/Export** - Round-trip conversion with other DMN tools (Camunda, Drools, IBM ODM)
- **Visual Modeler** - Web-based DMN editor at `/dmn/editor`
- **CLI Commands** - `decision_agent dmn import` and `decision_agent dmn export`

See [DMN Guide](docs/DMN_GUIDE.md) for complete documentation and [DMN Examples](examples/dmn/README.md) for working examples.

## Monitoring & Analytics

Real-time monitoring, metrics, and alerting for production environments.

```ruby
require 'decision_agent/monitoring/metrics_collector'
require 'decision_agent/monitoring/dashboard_server'

collector = DecisionAgent::Monitoring::MetricsCollector.new(window_size: 3600)
DecisionAgent::Monitoring::DashboardServer.start!(
  port: 4568,
  metrics_collector: collector
)
```

Open [http://localhost:4568](http://localhost:4568) for the monitoring dashboard.

**Features:**
- Real-time dashboard with WebSocket updates
- Prometheus metrics export
- Intelligent alerting with anomaly detection
- Grafana integration with pre-built dashboards

See [Monitoring & Analytics Guide](docs/MONITORING_AND_ANALYTICS.md) for complete documentation.

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

### Getting Started
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Code Examples](docs/CODE_EXAMPLES.md) - Comprehensive code snippets
- [Examples Directory](examples/README.md) - Working examples with explanations

### Core Features
- [Advanced Operators](docs/ADVANCED_OPERATORS.md) - String, numeric, date/time, collection, and geospatial operators
- [DMN Guide](docs/DMN_GUIDE.md) - Complete DMN 1.3 support guide
- [DMN API Reference](docs/DMN_API.md) - DMN API documentation
- [FEEL Reference](docs/FEEL_REFERENCE.md) - FEEL expression language reference
- [DMN Migration Guide](docs/DMN_MIGRATION_GUIDE.md) - Migrating from JSON to DMN
- [DMN Best Practices](docs/DMN_BEST_PRACTICES.md) - DMN modeling best practices
- [Versioning System](docs/VERSIONING.md) - Version control for rules
- [A/B Testing](docs/AB_TESTING.md) - Compare rule versions with statistical analysis
- [Web UI](docs/WEB_UI.md) - Visual rule builder
- [Web UI Setup](docs/WEB_UI_SETUP.md) - Setup guide
- [Web UI Rails Integration](docs/WEB_UI_RAILS_INTEGRATION.md) - Mount in Rails/Rack apps
- [Monitoring & Analytics](docs/MONITORING_AND_ANALYTICS.md) - Real-time monitoring, metrics, and alerting
- [Monitoring Architecture](docs/MONITORING_ARCHITECTURE.md) - System architecture and design

### Performance & Thread-Safety
- [Performance & Thread-Safety Summary](docs/PERFORMANCE_AND_THREAD_SAFETY.md) - Benchmarks and production readiness
- [Thread-Safety Implementation](docs/THREAD_SAFETY.md) - Technical implementation guide

### Reference
- [API Contract](docs/API_CONTRACT.md) - Full API reference
- [Changelog](docs/CHANGELOG.md) - Version history
- [Code Coverage Report](coverage.md) - Test coverage statistics

### More Resources
- [Documentation Home](docs/README.md) - Documentation index
- [GitHub Issues](https://github.com/samaswin/decision_agent/issues) - Report bugs or request features

## Thread-Safety & Performance

DecisionAgent is designed to be **thread-safe and FAST** for use in multi-threaded environments:

- **10,000+ decisions/second** throughput
- **~0.1ms average latency** per decision
- **Zero performance overhead** from thread-safety
- **Linear scalability** with thread count

All data structures are deeply frozen to prevent mutation, ensuring safe concurrent access without race conditions.

See [Thread-Safety Guide](docs/THREAD_SAFETY.md) and [Performance Analysis](docs/PERFORMANCE_AND_THREAD_SAFETY.md) for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests (maintain 90%+ coverage)
4. Submit a pull request

## Support

- **Issues**: [GitHub Issues](https://github.com/samaswin/decision_agent/issues)
- **Documentation**: [Documentation](docs/README.md)
- **Examples**: [Examples Directory](examples/README.md)

## License

MIT License - see [LICENSE.txt](LICENSE.txt)

---

⭐ **Star this repo** if you find it useful!
