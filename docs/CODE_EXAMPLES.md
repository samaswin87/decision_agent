# Code Examples

This document contains comprehensive code examples for DecisionAgent.

## Basic Usage

### Simple Decision Making

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

## Multiple Evaluators with Conflict Resolution

```ruby
# Multiple evaluators with conflict resolution
agent = DecisionAgent::Agent.new(
  evaluators: [rule_evaluator, ml_evaluator],
  scoring_strategy: DecisionAgent::Scoring::Consensus.new(minimum_agreement: 0.7),
  audit_adapter: DecisionAgent::Audit::LoggerAdapter.new
)
```

## Complex Rules with Nested Conditions

```ruby
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

## Advanced Operators

### String Operators

```ruby
{ field: "email", op: "ends_with", value: "@company.com" }
{ field: "name", op: "starts_with", value: "Dr." }
{ field: "code", op: "matches", value: "^[A-Z]{3}-\\d{4}$" }
```

### Numeric Operators

```ruby
{ field: "age", op: "between", value: [18, 65] }
{ field: "user_id", op: "modulo", value: 10 }  # For A/B testing, sharding
```

### Mathematical Operators

#### Trigonometric Functions

```ruby
# Sine function - signal processing
{ field: "signal_phase", op: "sin", value: 0.0 }

# Cosine function - phase alignment
{ field: "waveform_phase", op: "cos", value: 1.0 }

# Inverse trigonometric - angle calculations
{ field: "sine_value", op: "asin", value: 1.5707963267948966 }  # π/2
{ field: "slope", op: "atan", value: 0.7853981633974483 }  # π/4
{ field: "point_x", op: "atan2", value: { y: 1, result: 0.7853981633974483 } }
```

#### Power and Root Functions

```ruby
# Square root - distance calculations
{ field: "squared_distance", op: "sqrt", value: 5.0 }

# Cube root - volume calculations
{ field: "cubed_volume", op: "cbrt", value: 3.0 }

# Power - exponential relationships
{ field: "base_number", op: "power", value: { exponent: 2, result: 16 } }

# Exponential function - growth models
{ field: "growth_rate", op: "exp", value: 2.718281828459045 }  # e^1
```

#### Logarithmic Functions

```ruby
# Natural logarithm (base e)
{ field: "ratio", op: "log", value: 0.0 }  # log(1) = 0

# Base 10 logarithm - order of magnitude
{ field: "magnitude", op: "log10", value: 3.0 }  # 1000 = 10^3

# Base 2 logarithm - binary calculations
{ field: "data_size", op: "log2", value: 10.0 }  # 1024 = 2^10
```

#### Rounding Functions

```ruby
# Round to nearest integer
{ field: "calculated_price", op: "round", value: 100 }

# Floor (round down)
{ field: "discounted_price", op: "floor", value: 50 }

# Ceiling (round up)
{ field: "required_capacity", op: "ceil", value: 5 }

# Truncate (remove decimal part)
{ field: "measurement", op: "truncate", value: 5 }

# Absolute value
{ field: "price_deviation", op: "abs", value: 10 }
```

#### Advanced Mathematical Functions

```ruby
# Factorial - combinatorics
{ field: "items_count", op: "factorial", value: 24 }  # 4! = 24

# Greatest Common Divisor
{ field: "number_a", op: "gcd", value: { other: 24, result: 12 } }

# Least Common Multiple
{ field: "cycle_a", op: "lcm", value: { other: 12, result: 36 } }
```

#### Hyperbolic Functions

```ruby
# Hyperbolic sine
{ field: "hyperbolic_parameter", op: "sinh", value: 0.0 }

# Hyperbolic cosine
{ field: "hyperbolic_parameter", op: "cosh", value: 1.0 }

# Hyperbolic tangent - machine learning activation
{ field: "activation_value", op: "tanh", value: 0.0 }
```

### Date/Time Operators

```ruby
{ field: "created_at", op: "within_days", value: 30 }
{ field: "expiry_date", op: "before_date", value: "2024-12-31" }
{ field: "created_at", op: "day_of_week", value: [1, 5] }  # Monday-Friday
```

### Collection Operators

```ruby
{ field: "permissions", op: "contains_all", value: ["read", "write"] }
{ field: "tags", op: "contains_any", value: ["urgent", "priority"] }
{ field: "roles", op: "intersects", value: ["admin", "moderator"] }
```

### Geospatial Operators

```ruby
{ field: "location", op: "within_radius",
  value: { center: { lat: 40.7128, lon: -74.0060 }, radius: 25 } }
```

## Complete Advanced Example

```ruby
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

## Thread-Safe Usage

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

## Monitoring Setup

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

## Alert Management

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

## Web UI Integration

### Rails

```ruby
require 'decision_agent/web/server'

Rails.application.routes.draw do
  # Mount DecisionAgent Web UI
  mount DecisionAgent::Web::Server, at: '/decision_agent'
end
```

**With Authentication:**

```ruby
authenticate :user, ->(user) { user.admin? } do
  mount DecisionAgent::Web::Server, at: '/decision_agent'
end
```

### Rack/Sinatra

```ruby
# config.ru
require 'decision_agent/web/server'

map '/decision_agent' do
  run DecisionAgent::Web::Server
end
```

## More Examples

For complete working examples, see:
- [Examples Directory](../examples/README.md) - Comprehensive examples with explanations
- [Advanced Operators Guide](ADVANCED_OPERATORS.md) - Detailed operator documentation
- [Example Application](https://github.com/samaswin/decision_agent_example) - Full Rails integration example

