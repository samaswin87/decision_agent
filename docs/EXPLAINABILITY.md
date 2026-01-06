# Explainability Layer

The DecisionAgent explainability layer provides machine-readable explanations for every decision, enabling audits, compliance, and trust.

## Overview

Every decision includes a complete trace of:
- **Which conditions passed** - The conditions that led to the decision
- **Which conditions failed** - Conditions that were evaluated but didn't match
- **Rule trace** - Which rules were evaluated and which matched
- **Condition evaluation tree** - Full evaluation details with actual values

## Quick Start

```ruby
require "decision_agent"

rules = {
  version: "1.0",
  ruleset: "loan_approval",
  rules: [
    {
      id: "rule1",
      if: {
        all: [
          { field: "risk_score", op: "lt", value: 0.7 },
          { field: "account_age", op: "gt", value: 180 }
        ]
      },
      then: {
        decision: "approved",
        weight: 0.9,
        reason: "Low risk, established account"
      }
    }
  ]
}

evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
agent = DecisionAgent::Agent.new(
  evaluators: [evaluator],
  scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new
)

result = agent.decide(context: {
  risk_score: 0.5,
  account_age: 200,
  credit_hold: false
})

# Get passed conditions
result.because
# => ["risk_score < 0.7", "account_age > 180"]

# Get failed conditions
result.failed_conditions
# => ["credit_hold = true"]

# Get full explainability data
result.explainability
# => {
#   decision: "approved",
#   because: ["risk_score < 0.7", "account_age > 180"],
#   failed_conditions: ["credit_hold = true"]
# }
```

## API Reference

### Decision#because

Returns an array of condition descriptions that led to the decision.

```ruby
result.because(verbose: false)
# => ["risk_score < 0.7", "account_age > 180"]
```

**Parameters:**
- `verbose` (Boolean, optional): If `true`, returns detailed condition information. Default: `false`

**Returns:** `Array<String>` - Array of condition descriptions

### Decision#failed_conditions

Returns an array of condition descriptions that failed during evaluation.

```ruby
result.failed_conditions(verbose: false)
# => ["credit_hold = true"]
```

**Parameters:**
- `verbose` (Boolean, optional): If `true`, returns detailed condition information with actual/expected values. Default: `false`

**Returns:** `Array<String>` or `Array<Hash>` - Array of failed condition descriptions (or detailed hashes in verbose mode)

### Decision#explainability

Returns machine-readable explainability data.

```ruby
result.explainability(verbose: false)
# => {
#   decision: "approved",
#   because: ["risk_score < 0.7", "account_age > 180"],
#   failed_conditions: ["credit_hold = true"],
#   rule_traces: nil  # Only in verbose mode
# }
```

**Parameters:**
- `verbose` (Boolean, optional): If `true`, includes detailed rule traces. Default: `false`

**Returns:** `Hash` - Explainability data structure

### Decision#to_h

The `to_h` method now includes explainability data:

```ruby
result.to_h
# => {
#   decision: "approved",
#   confidence: 0.9,
#   explanations: [...],
#   evaluations: [...],
#   audit_payload: {...},
#   explainability: {
#     decision: "approved",
#     because: ["risk_score < 0.7", "account_age > 180"],
#     failed_conditions: []
#   }
# }
```

## Condition Descriptions

Condition descriptions are automatically generated from the condition evaluation:

| Operator | Description Format | Example |
|----------|------------------|---------|
| `eq` | `field = value` | `risk_score = 0.5` |
| `neq` | `field != value` | `status != "active"` |
| `gt` | `field > value` | `account_age > 180` |
| `gte` | `field >= value` | `amount >= 1000` |
| `lt` | `field < value` | `risk_score < 0.7` |
| `lte` | `field <= value` | `age <= 65` |
| `in` | `field in [values]` | `status in ["active", "pending"]` |
| `contains` | `field contains value` | `tags contains "premium"` |
| `present` | `field is present` | `email is present` |
| `blank` | `field is blank` | `notes is blank` |

## Verbose Mode

Verbose mode provides detailed condition information:

```ruby
result.failed_conditions(verbose: true)
# => [
#   {
#     field: "credit_hold",
#     operator: "eq",
#     expected_value: true,
#     actual_value: false,
#     result: false,
#     description: "credit_hold = true"
#   }
# ]
```

## Rule Trace

Each rule evaluation includes:
- Rule ID
- Whether the rule matched
- All condition traces (passed and failed)
- Decision, weight, and reason from the rule

## Supported Evaluators

### JsonRuleEvaluator

Full explainability support with condition-level tracing.

```ruby
evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
result = evaluator.evaluate(context: { ... })

# Explainability is automatically included in metadata
result.metadata[:explainability]
# => {
#   evaluator_name: "JsonRuleEvaluator(loan_approval)",
#   rule_traces: [...],
#   because: [...],
#   failed_conditions: [...]
# }
```

### DmnEvaluator

Full explainability support for DMN decision models.

```ruby
evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: dmn_model,
  decision_id: "loan_approval"
)
result = evaluator.evaluate(context: { ... })

# Explainability is automatically included in metadata
result.metadata[:explainability]
# => {
#   evaluator_name: "DmnEvaluator(loan_approval)",
#   rule_traces: [...],
#   because: [...],
#   failed_conditions: [...]
# }
```

## Use Cases

### Audit and Compliance

```ruby
result = agent.decide(context: loan_application)

# Store for audit trail
audit_record = {
  decision: result.decision,
  timestamp: Time.now,
  explainability: result.explainability,
  because: result.because,
  failed_conditions: result.failed_conditions
}
```

### Debugging and Troubleshooting

```ruby
result = agent.decide(context: context)

if result.decision != expected_decision
  puts "Expected: #{expected_decision}, Got: #{result.decision}"
  puts "Because: #{result.because.join(', ')}"
  puts "Failed: #{result.failed_conditions.join(', ')}"
end
```

### User-Facing Explanations

```ruby
result = agent.decide(context: user_request)

explanation = "Your request was #{result.decision} because: " +
              result.because.join(" and ")

if result.failed_conditions.any?
  explanation += ". However, #{result.failed_conditions.first} was not met."
end
```

## Best Practices

1. **Always include explainability in audit logs** - Store `result.explainability` for compliance
2. **Use verbose mode for debugging** - Detailed condition traces help identify issues
3. **Present explanations to users** - Use `because` and `failed_conditions` for user-facing messages
4. **Monitor failed conditions** - Track which conditions fail most often to improve rules

## Performance Considerations

- Explainability tracking adds minimal overhead (~5-10% in benchmarks)
- Condition traces are only collected when needed
- Verbose mode includes more data but has similar performance
- All explainability data is frozen for thread-safety

## Thread Safety

All explainability data structures are:
- Immutable (frozen)
- Thread-safe
- Safe for concurrent access

## Examples

See the [explainability spec](../spec/explainability_spec.rb) for comprehensive examples.

