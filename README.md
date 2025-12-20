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

Launch the visual rule builder for non-technical users:

```bash
decision_agent web
```

Open [http://localhost:4567](http://localhost:4567) in your browser.

<img width="1602" alt="DecisionAgent Web UI" src="https://github.com/user-attachments/assets/6ee6859c-f9f2-4f93-8bff-923986ccb1bc" />

## Documentation

```
📚 DecisionAgent Documentation
│
├── 🚀 Getting Started
│   ├── Installation (above)
│   ├── Quick Start (above)
│   └── Examples → examples/README.md
│
├── 📖 Core Documentation
│   ├── Core Concepts → wiki/CORE_CONCEPTS.md
│   ├── JSON Rule DSL → wiki/JSON_RULE_DSL.md
│   ├── API Reference → wiki/API_CONTRACT.md
│   └── Error Handling → wiki/ERROR_HANDLING.md
│
├── 🎯 Advanced Features
│   ├── Versioning System → wiki/VERSIONING.md
│   ├── Decision Replay → wiki/REPLAY.md
│   ├── Advanced Usage → wiki/ADVANCED_USAGE.md
│   └── Custom Components → wiki/ADVANCED_USAGE.md#custom-components
│
├── 🔌 Integration Guides
│   ├── Rails Integration → wiki/INTEGRATION.md#rails
│   ├── Redmine Plugin → wiki/INTEGRATION.md#redmine
│   ├── Standalone Service → wiki/INTEGRATION.md#standalone
│   └── Testing Guide → wiki/TESTING.md
│
├── 🎨 Web UI
│   ├── User Guide → wiki/WEB_UI.md
│   └── Setup Guide → wiki/WEB_UI_SETUP.md
│
└── 📝 Reference
    ├── Changelog → wiki/CHANGELOG.md
    └── Full Wiki Index → wiki/README.md
```

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

### Production Ready
- **Comprehensive Testing** - 90%+ code coverage
- **Error Handling** - Clear, actionable error messages
- **Versioning** - Full rule version control and rollback
- **Performance** - Fast, zero external dependencies

## Examples

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
```

See [examples/](examples/) for complete working examples.

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

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests (maintain 90%+ coverage)
4. Submit a pull request

## Support

- **Issues**: [GitHub Issues](https://github.com/samaswin87/decision_agent/issues)
- **Documentation**: [Wiki](wiki/README.md)
- **Examples**: [examples/](examples/)

## License

MIT License - see [LICENSE.txt](LICENSE.txt)

---

⭐ **Star this repo** if you find it useful!
