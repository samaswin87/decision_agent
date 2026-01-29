# DecisionAgent

[![Gem Version](https://badge.fury.io/rb/decision_agent.svg)](https://badge.fury.io/rb/decision_agent)
[![CI](https://github.com/samaswin/decision_agent/actions/workflows/ci.yml/badge.svg)](https://github.com/samaswin/decision_agent/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0.0-red.svg)](https://www.ruby-lang.org)

A production-grade, deterministic, explainable, and auditable decision engine for Ruby.

**Built for regulated domains. Deterministic by design. AI-optional.**

## Why DecisionAgent?

DecisionAgent is designed for applications that require **deterministic, explainable, and auditable** decision-making:

- ✅ **Deterministic** - Same input always produces same output
- ✅ **Explainable** - Every decision includes human-readable reasoning and machine-readable condition traces
- ✅ **Auditable** - Reproduce any historical decision exactly with complete explainability
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

puts result.decision           # => "approve"
puts result.confidence         # => 0.9
puts result.explanations       # => ["High value transaction"]
puts result.because            # => ["amount > 1000"]
puts result.failed_conditions  # => []
puts result.explainability     # => { decision: "approve", because: [...], failed_conditions: [] }
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
- **Explainability Layer** - Machine-readable condition traces for every decision
  - `result.because` - Conditions that led to the decision
  - `result.failed_conditions` - Conditions that failed
  - `result.explainability` - Complete machine-readable explainability data
- **Deterministic Replay** - Reproduce historical decisions exactly
- **RFC 8785 Canonical JSON** - Industry-standard deterministic hashing
- **Compliance Ready** - HIPAA, SOX, regulatory compliance support

### Testing & Simulation
- **Simulation & What-If Analysis** - Test rule changes before deployment
  - **Historical Replay / Backtesting** - Replay past decisions with new rules (CSV, JSON, database import)
  - **What-If Analysis** - Simulate scenarios and sensitivity analysis with decision boundary visualization
  - **Impact Analysis** - Quantify rule change effects (decision distribution, confidence shifts, performance impact)
  - **Shadow Testing** - Compare new rules against production without affecting outcomes
  - **Monte Carlo Simulation** - Model probabilistic inputs and understand decision outcome probabilities
- **Batch Testing** - Test rules against large datasets with CSV/Excel import, coverage analysis, and resume capability
- **A/B Testing** - Champion/Challenger testing with statistical significance analysis

### Security & Access Control
- **Role-Based Access Control (RBAC)** - Enterprise-grade authentication and authorization
  - Built-in user/role system with bcrypt password hashing
  - Configurable adapters for Devise, CanCanCan, Pundit, or custom auth systems
  - 5 default roles (Admin, Editor, Viewer, Auditor, Approver) with 7 permissions
  - Password reset functionality with secure token management
  - Comprehensive access audit logging for compliance
  - Web UI integration with login and user management pages

### Developer Experience
- **Pluggable Architecture** - Custom evaluators, scoring, audit adapters
- **Framework Agnostic** - Works with Rails, Rack, or standalone
- **JSON Rule DSL** - Non-technical users can write rules
- **DMN 1.3 Support** - Industry-standard Decision Model and Notation with full FEEL expression language
- **Visual Rule Builder** - Web UI for rule management and DMN modeler
- **CLI Tools** - Command-line interface for DMN import/export and web server

### Production Features
- **Real-time Monitoring** - Live dashboard with WebSocket updates
- **Persistent Monitoring** - Database storage for long-term analytics (PostgreSQL, MySQL, SQLite)
- **Prometheus Export** - Industry-standard metrics format
- **Intelligent Alerting** - Anomaly detection with customizable rules
- **Grafana Integration** - Pre-built dashboards and alert rules
- **Version Control** - Full rule version control, rollback, and history ([Versioning Guide](docs/VERSIONING.md))
- **Thread-Safe** - Safe for multi-threaded servers and background jobs
- **High Performance** - 10,000+ decisions/second, ~0.1ms latency

## Web UI - Visual Rule Builder

Launch the visual rule builder:

```bash
decision_agent web
```

Open [http://localhost:4567](http://localhost:4567) in your browser.

> **Coming Soon:** Decision tree builder - Visual interface for building and managing decision trees.

### Integration

**Rails:**
```ruby
require 'decision_agent/web/server'
Rails.application.routes.draw do
  mount DecisionAgent::Web::Server, at: '/decision_agent'
end
```

**Rack:**
```ruby
require 'decision_agent/web/server'
map '/decision_agent' do
  run DecisionAgent::Web::Server
end
```

See [Web UI Integration Guide](docs/WEB_UI_INTEGRATION.md) for detailed setup with Rails, Sinatra, Hanami, and other frameworks.

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
- **Persistent Storage** - Database storage for long-term analytics (PostgreSQL, MySQL, SQLite)
- Prometheus metrics export
- Intelligent alerting with anomaly detection
- Grafana integration with pre-built dashboards

See [Monitoring & Analytics Guide](docs/MONITORING_AND_ANALYTICS.md) and [Persistent Monitoring Guide](docs/PERSISTENT_MONITORING.md) for complete documentation.

## Simulation & What-If Analysis

DecisionAgent provides comprehensive simulation capabilities to test rule changes before deployment:

```ruby
require 'decision_agent/simulation/replay_engine'

# Replay historical decisions with new rules
replay_engine = DecisionAgent::Simulation::ReplayEngine.new(
  agent: agent,
  version_manager: version_manager
)

results = replay_engine.replay(historical_data: "decisions.csv")

# What-if analysis
whatif = DecisionAgent::Simulation::WhatIfAnalyzer.new(agent: agent)
analysis = whatif.analyze(
  base_context: { credit_score: 700, amount: 50000 },
  scenarios: [
    { credit_score: 750 },
    { credit_score: 650 }
  ]
)

# Impact analysis
impact = DecisionAgent::Simulation::ImpactAnalyzer.new
comparison = impact.compare(
  baseline: baseline_evaluator,
  proposed: proposed_evaluator,
  contexts: test_contexts
)
```

**Features:**
- **Historical Replay** - Replay past decisions with CSV/JSON/database import
- **What-If Analysis** - Scenario simulation with decision boundary visualization
- **Impact Analysis** - Quantify rule change effects (decisions, confidence, performance)
- **Shadow Testing** - Test new rules in production without affecting outcomes
- **Monte Carlo Simulation** - Probabilistic decision modeling
- **Web UI** - Complete simulation dashboard at `/simulation`

See [Simulation Guide](docs/SIMULATION.md) for complete documentation and [Simulation Example](examples/simulation_example.rb) for working examples.

## Role-Based Access Control (RBAC)

Enterprise-grade authentication and authorization system:

```ruby
require 'decision_agent'

# Configure RBAC (works with any auth system)
DecisionAgent.configure_rbac(:devise_cancan, ability_class: Ability)

# Or use built-in RBAC
authenticator = DecisionAgent::Auth::Authenticator.new
admin = authenticator.create_user(
  email: "admin@example.com",
  password: "secure_password",
  roles: [:admin]
)

session = authenticator.login("admin@example.com", "secure_password")

# Permission checks
checker = DecisionAgent.permission_checker
checker.can?(admin, :write)  # => true
checker.can?(admin, :approve)  # => true
```

**Features:**
- **Built-in User System** - User management with bcrypt password hashing
- **5 Default Roles** - Admin, Editor, Viewer, Auditor, Approver
- **Configurable Adapters** - Devise, CanCanCan, Pundit, or custom
- **Password Reset** - Secure token-based password reset
- **Access Audit Logging** - Comprehensive audit trail for compliance
- **Web UI Integration** - Login page and user management interface

See [RBAC Configuration Guide](docs/RBAC_CONFIGURATION.md) for complete documentation and [RBAC Examples](examples/rbac_configuration_examples.rb) for integration examples.

## Batch Testing

Test rules against large datasets with comprehensive analysis:

```ruby
require 'decision_agent/testing/batch_test_runner'

runner = DecisionAgent::Testing::BatchTestRunner.new(agent: agent)

# Import from CSV or Excel
importer = DecisionAgent::Testing::BatchTestImporter.new
scenarios = importer.import_csv("test_data.csv", {
  context_fields: ["credit_score", "amount"],
  expected_fields: ["expected_decision"]
})

# Run batch test
results = runner.run(scenarios: scenarios)

puts "Total: #{results[:total]}"
puts "Passed: #{results[:passed]}"
puts "Failed: #{results[:failed]}"
puts "Coverage: #{results[:coverage]}"
```

**Features:**
- **CSV/Excel Import** - Import test scenarios from files
- **Database Import** - Load test data from databases
- **Coverage Analysis** - Identify untested rule combinations
- **Resume Capability** - Continue interrupted tests from checkpoint
- **Progress Tracking** - Real-time progress updates for large imports
- **Web UI** - Complete batch testing interface with file upload

See [Batch Testing Guide](docs/BATCH_TESTING.md) for complete documentation.

## A/B Testing

Compare rule versions with statistical analysis:

```ruby
require 'decision_agent/testing/ab_test_manager'

ab_manager = DecisionAgent::Testing::AbTestManager.new(version_manager: version_manager)

test = ab_manager.create_test(
  name: "loan_approval_v2",
  champion_version: champion_version_id,
  challenger_version: challenger_version_id,
  traffic_split: 0.5
)

results = ab_manager.run_test(test_id: test.id, contexts: test_contexts)
ab_manager.analyze_results(test_id: test.id)
```

**Features:**
- **Champion/Challenger Testing** - Compare baseline vs proposed rules
- **Statistical Significance** - P-value calculation and confidence intervals
- **Traffic Splitting** - Configurable split ratios
- **Decision Distribution Comparison** - Visualize differences in outcomes

See [A/B Testing Guide](docs/AB_TESTING.md) for complete documentation.

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
- [Explainability Layer](docs/EXPLAINABILITY.md) - Machine-readable decision explanations with condition-level tracing
- [Advanced Operators](docs/ADVANCED_OPERATORS.md) - String, numeric, date/time, collection, and geospatial operators
- [DMN Guide](docs/DMN_GUIDE.md) - Complete DMN 1.3 support guide
- [DMN API Reference](docs/DMN_API.md) - DMN API documentation
- [FEEL Reference](docs/FEEL_REFERENCE.md) - FEEL expression language reference
- [DMN Migration Guide](docs/DMN_MIGRATION_GUIDE.md) - Migrating from JSON to DMN
- [DMN Best Practices](docs/DMN_BEST_PRACTICES.md) - DMN modeling best practices
- [Versioning System](docs/VERSIONING.md) - Version control for rules
- [Simulation & What-If Analysis](docs/SIMULATION.md) - Historical replay, what-if analysis, impact analysis, and shadow testing
- [A/B Testing](docs/AB_TESTING.md) - Compare rule versions with statistical analysis
- [Batch Testing](docs/BATCH_TESTING.md) - Test rules against large datasets with CSV/Excel import
- [RBAC Configuration](docs/RBAC_CONFIGURATION.md) - Role-based access control setup and integration
- [RBAC Quick Reference](docs/RBAC_QUICK_REFERENCE.md) - Quick reference for RBAC configuration
- [Web UI](docs/WEB_UI.md) - Visual rule builder
- [Web UI Setup](docs/WEB_UI_SETUP.md) - Setup guide
- [Web UI Integration](docs/WEB_UI_INTEGRATION.md) - Mount in Rails, Sinatra, Hanami, and other Rack frameworks
- [Monitoring & Analytics](docs/MONITORING_AND_ANALYTICS.md) - Real-time monitoring, metrics, and alerting
- [Monitoring Architecture](docs/MONITORING_ARCHITECTURE.md) - System architecture and design
- [Persistent Monitoring](docs/PERSISTENT_MONITORING.md) - Database storage for long-term analytics

### Performance & Thread-Safety
- [Performance & Thread-Safety Summary](docs/PERFORMANCE_AND_THREAD_SAFETY.md) - Benchmarks and production readiness
- [Thread-Safety Implementation](docs/THREAD_SAFETY.md) - Technical implementation guide
- [Benchmarks](benchmarks/README.md) - Comprehensive benchmark suite and performance testing

### Development
- [Development Setup](docs/DEVELOPMENT_SETUP.md) - Development environment setup, testing, and tools

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

**Run Benchmarks:**
```bash
# Run all benchmarks (single Ruby version)
rake benchmark:all

# Run specific benchmarks
rake benchmark:basic      # Basic decision performance
rake benchmark:threads    # Thread-safety and scalability
rake benchmark:regression # Compare against baseline

# Run benchmarks across all Ruby versions (3.0.7, 3.1.6, 3.2.5, 3.3.5)
./scripts/benchmark_all_ruby_versions.sh

# See [Benchmarks Guide](benchmarks/README.md) for complete documentation
```

### Latest Benchmark Results

**Last Updated:** 2026-01-06T04:03:29Z

#### Performance Comparison

| Metric | Latest (2026-01-06) | Previous (2026-01-06) | Change |
|--------|--------------------------------------------------|------------------------------------------------------|--------|
| Basic Throughput | 8966.04 decisions/sec | 9751.42 decisions/sec | ↓ 8.05% (degraded) |
| Basic Latency | 0.1115 ms | 0.1025 ms | ↑ 8.78% (degraded) |
| Multi-threaded (50 threads) Throughput | 8560.69 decisions/sec | 8849.86 decisions/sec | ↓ 3.27% (degraded) |
| Multi-threaded (50 threads) Latency | 0.1168 ms | 0.113 ms | ↑ 3.36% (degraded) |

**Environment:**
- Ruby Version: 3.3.5
- Hardware: x86_64
- OS: Darwin
- Git Commit: `aba46af5`

> 💡 **Note:** Run `rake benchmark:regression` to generate new benchmark results. This section is automatically updated with the last 2 benchmark runs.
## Contributing

1. Fork the repository
2. Create a feature branch
3. Set up development environment (see [Development Setup](docs/DEVELOPMENT_SETUP.md))
4. Add tests (maintain 90%+ coverage)
5. Run tests across all Ruby versions: `./scripts/test_all_ruby_versions.sh`
6. Run benchmarks across all Ruby versions: `./scripts/benchmark_all_ruby_versions.sh`
6. Submit a pull request

See [Development Setup Guide](docs/DEVELOPMENT_SETUP.md) for detailed setup instructions, testing workflows, and development best practices.

## Support

- **Issues**: [GitHub Issues](https://github.com/samaswin/decision_agent/issues)
- **Documentation**: [Documentation](docs/README.md)
- **Examples**: [Examples Directory](examples/README.md)

## License

MIT License - see [LICENSE.txt](LICENSE.txt)

---

⭐ **Star this repo** if you find it useful!
