# DecisionAgent

A production-grade, deterministic, explainable, and auditable decision engine for Ruby.

## The Problem

Enterprise applications need to make complex decisions based on business rules, but existing solutions fall short:

- **Trailblazer/dry-rb**: Excellent for data pipelines, but lack built-in conflict resolution, confidence scoring, and audit replay
- **ActiveInteraction**: Rails-dependent, no rule DSL, limited explainability
- **AI-first frameworks**: Non-deterministic, expensive, opaque, and unsuitable for regulated domains

**DecisionAgent** solves these problems by providing:

1. **Deterministic decisions** - Same input always produces same output
2. **Full explainability** - Every decision includes human-readable reasoning
3. **Audit replay** - Reproduce any historical decision exactly
4. **Conflict resolution** - Multiple evaluators with pluggable scoring strategies
5. **Framework-agnostic** - Pure Ruby, no Rails/ActiveRecord/Sidekiq dependencies
6. **AI-optional** - Rules first, AI enhancement optional

## Installation

Add to your Gemfile:

```ruby
gem 'decision_agent'
```

Or install directly:

```bash
gem install decision_agent
```

## Quick Start

```ruby
require 'decision_agent'

# Define evaluators
evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(
  decision: "approve",
  weight: 0.8,
  reason: "User meets basic criteria"
)

# Create agent
agent = DecisionAgent::Agent.new(
  evaluators: [evaluator],
  scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new,
  audit_adapter: DecisionAgent::Audit::LoggerAdapter.new
)

# Make decision
result = agent.decide(
  context: { user: "alice", priority: "high" }
)

puts result.decision       # => "approve"
puts result.confidence     # => 0.8
puts result.explanations   # => ["Decision: approve (confidence: 0.8)", ...]
puts result.audit_payload  # => Full audit trail
```

## Core Concepts

### 1. Agent

The orchestrator that coordinates evaluators, resolves conflicts, and produces decisions.

```ruby
agent = DecisionAgent::Agent.new(
  evaluators: [eval1, eval2, eval3],
  scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new,
  audit_adapter: DecisionAgent::Audit::NullAdapter.new
)
```

### 2. Evaluators

Pluggable components that evaluate context and return decisions.

#### StaticEvaluator

Always returns the same decision:

```ruby
evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(
  decision: "approve",
  weight: 0.7,
  reason: "Static approval rule"
)
```

#### JsonRuleEvaluator

Evaluates context against JSON-based business rules:

```ruby
rules = {
  version: "1.0",
  ruleset: "issue_triage",
  rules: [
    {
      id: "high_priority_rule",
      if: {
        all: [
          { field: "priority", op: "eq", value: "high" },
          { field: "hours_inactive", op: "gte", value: 4 }
        ]
      },
      then: {
        decision: "escalate",
        weight: 0.9,
        reason: "High priority issue inactive too long"
      }
    }
  ]
}

evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(
  rules_json: rules
)
```

### 3. Context

Immutable input data for decision-making:

```ruby
context = DecisionAgent::Context.new({
  user: "alice",
  priority: "high",
  hours_inactive: 5
})
```

### 4. Scoring Strategies

Resolve conflicts when multiple evaluators return different decisions.

#### WeightedAverage (Default)

Sums weights for each decision, selects winner:

```ruby
DecisionAgent::Scoring::WeightedAverage.new
```

#### MaxWeight

Selects decision with highest individual weight:

```ruby
DecisionAgent::Scoring::MaxWeight.new
```

#### Consensus

Requires minimum agreement threshold:

```ruby
DecisionAgent::Scoring::Consensus.new(minimum_agreement: 0.6)
```

#### Threshold

Requires minimum weight to accept decision:

```ruby
DecisionAgent::Scoring::Threshold.new(
  threshold: 0.8,
  fallback_decision: "manual_review"
)
```

### 5. Audit Adapters

Record decisions for compliance and debugging.

#### NullAdapter

No-op (default):

```ruby
DecisionAgent::Audit::NullAdapter.new
```

#### LoggerAdapter

Logs to any Ruby logger:

```ruby
DecisionAgent::Audit::LoggerAdapter.new(
  logger: Rails.logger,
  level: Logger::INFO
)
```

## JSON Rule DSL

### Supported Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `eq` | Equal | `{ field: "status", op: "eq", value: "active" }` |
| `neq` | Not equal | `{ field: "status", op: "neq", value: "closed" }` |
| `gt` | Greater than | `{ field: "score", op: "gt", value: 80 }` |
| `gte` | Greater than or equal | `{ field: "hours", op: "gte", value: 4 }` |
| `lt` | Less than | `{ field: "temp", op: "lt", value: 32 }` |
| `lte` | Less than or equal | `{ field: "temp", op: "lte", value: 32 }` |
| `in` | Array membership | `{ field: "status", op: "in", value: ["open", "pending"] }` |
| `present` | Field exists and not empty | `{ field: "assignee", op: "present" }` |
| `blank` | Field missing, nil, or empty | `{ field: "description", op: "blank" }` |

### Condition Combinators

#### all

All sub-conditions must be true:

```json
{
  "all": [
    { "field": "priority", "op": "eq", "value": "high" },
    { "field": "hours", "op": "gte", "value": 4 }
  ]
}
```

#### any

At least one sub-condition must be true:

```json
{
  "any": [
    { "field": "escalated", "op": "eq", "value": true },
    { "field": "complaints", "op": "gte", "value": 3 }
  ]
}
```

### Nested Fields

Use dot notation to access nested data:

```json
{
  "field": "user.role",
  "op": "eq",
  "value": "admin"
}
```

```ruby
context = DecisionAgent::Context.new({
  user: { role: "admin" }
})
```

### Complete Example

```json
{
  "version": "1.0",
  "ruleset": "redmine_triage",
  "rules": [
    {
      "id": "critical_escalation",
      "if": {
        "all": [
          { "field": "priority", "op": "eq", "value": "critical" },
          {
            "any": [
              { "field": "hours_inactive", "op": "gte", "value": 2 },
              { "field": "customer_escalated", "op": "eq", "value": true }
            ]
          }
        ]
      },
      "then": {
        "decision": "escalate_immediately",
        "weight": 1.0,
        "reason": "Critical issue requires immediate attention"
      }
    },
    {
      "id": "auto_assign",
      "if": {
        "all": [
          { "field": "assignee", "op": "blank" },
          { "field": "priority", "op": "in", "value": ["high", "critical"] }
        ]
      },
      "then": {
        "decision": "assign_to_team_lead",
        "weight": 0.85,
        "reason": "High priority issue needs assignment"
      }
    }
  ]
}
```

## Decision Replay

Critical for compliance and debugging - replay any historical decision exactly.

### Strict Mode

Fails if replayed decision differs from original:

```ruby
original_result = agent.decide(context: { user: "alice" })

# Later, replay the exact decision
replayed_result = DecisionAgent::Replay.run(
  original_result.audit_payload,
  strict: true
)

# Raises ReplayMismatchError if decision changed
```

### Non-Strict Mode

Logs differences but allows evolution:

```ruby
replayed_result = DecisionAgent::Replay.run(
  original_result.audit_payload,
  strict: false  # Logs differences but doesn't fail
)
```

### Audit Payload Structure

```ruby
{
  timestamp: "2025-01-15T10:30:45.123456Z",
  context: { user: "alice", priority: "high" },
  feedback: {},
  evaluations: [
    {
      decision: "approve",
      weight: 0.8,
      reason: "Rule matched",
      evaluator_name: "JsonRuleEvaluator",
      metadata: { rule_id: "high_priority_rule" }
    }
  ],
  decision: "approve",
  confidence: 0.8,
  scoring_strategy: "DecisionAgent::Scoring::WeightedAverage",
  agent_version: "0.1.0",
  deterministic_hash: "a3f2b9c..."
}
```

## Advanced Usage

### Multiple Evaluators with Conflict Resolution

```ruby
rule_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(
  rules_json: File.read("rules/triage.json")
)

ml_evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(
  decision: "review_manually",
  weight: 0.6,
  reason: "ML model suggests manual review"
)

agent = DecisionAgent::Agent.new(
  evaluators: [rule_evaluator, ml_evaluator],
  scoring_strategy: DecisionAgent::Scoring::Consensus.new(minimum_agreement: 0.7)
)

result = agent.decide(
  context: { priority: "high", complexity: "high" }
)

# Explanations show how conflict was resolved
puts result.explanations
```

### Custom Evaluator

```ruby
class CustomBusinessLogicEvaluator < DecisionAgent::Evaluators::Base
  def evaluate(context, feedback: {})
    # Your custom logic here
    if context[:revenue] > 100_000 && context[:customer_tier] == "enterprise"
      DecisionAgent::Evaluation.new(
        decision: "approve_immediately",
        weight: 0.95,
        reason: "High-value enterprise customer",
        evaluator_name: "EnterpriseCustomerEvaluator",
        metadata: { tier: "enterprise" }
      )
    else
      nil  # No decision
    end
  end
end
```

### Custom Scoring Strategy

```ruby
class VetoScoring < DecisionAgent::Scoring::Base
  def score(evaluations)
    # If any evaluator says "reject", veto everything
    if evaluations.any? { |e| e.decision == "reject" }
      return { decision: "reject", confidence: 1.0 }
    end

    # Otherwise, use max weight
    max_eval = evaluations.max_by(&:weight)
    {
      decision: max_eval.decision,
      confidence: normalize_confidence(max_eval.weight)
    }
  end
end

agent = DecisionAgent::Agent.new(
  evaluators: [...],
  scoring_strategy: VetoScoring.new
)
```

### Custom Audit Adapter

```ruby
class DatabaseAuditAdapter < DecisionAgent::Audit::Adapter
  def record(decision, context)
    AuditLog.create!(
      decision: decision.decision,
      confidence: decision.confidence,
      context_json: context.to_h.to_json,
      audit_payload: decision.audit_payload.to_json,
      deterministic_hash: decision.audit_payload[:deterministic_hash]
    )
  end
end
```

### Feedback Loop

```ruby
# Initial decision
result = agent.decide(
  context: { issue_id: 123 },
  feedback: { source: "automated" }
)

# User provides feedback
user_feedback = {
  correct: false,
  actual_decision: "escalate",
  user_id: "manager_bob"
}

# Use feedback to improve (e.g., log for training, adjust weights)
# DecisionAgent is deterministic, so feedback doesn't change rules
# Use it for analysis and future rule adjustments
```

## Integration Examples

### Rails Integration

```ruby
# app/services/issue_decision_service.rb
class IssueDecisionService
  def self.decide_action(issue)
    agent = build_agent

    result = agent.decide(
      context: {
        priority: issue.priority,
        hours_inactive: (Time.now - issue.updated_at) / 3600,
        assignee: issue.assignee&.login,
        status: issue.status
      }
    )

    result
  end

  private

  def self.build_agent
    rules = JSON.parse(File.read(Rails.root.join("config/rules/issue_triage.json")))

    DecisionAgent::Agent.new(
      evaluators: [
        DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      ],
      scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new,
      audit_adapter: DecisionAgent::Audit::LoggerAdapter.new(logger: Rails.logger)
    )
  end
end
```

### Redmine Plugin Integration

```ruby
# plugins/redmine_smart_triage/lib/decision_engine.rb
module RedmineSmartTriage
  class DecisionEngine
    def self.evaluate_issue(issue)
      agent = build_agent

      context = {
        "priority" => issue.priority.name.downcase,
        "status" => issue.status.name.downcase,
        "hours_inactive" => hours_since_update(issue),
        "assignee" => issue.assigned_to&.login,
        "tracker" => issue.tracker.name.downcase
      }

      agent.decide(context: context)
    end

    private

    def self.build_agent
      rules_path = File.join(File.dirname(__FILE__), "../config/triage_rules.json")
      rules = JSON.parse(File.read(rules_path))

      DecisionAgent::Agent.new(
        evaluators: [
          DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        ],
        audit_adapter: RedmineAuditAdapter.new
      )
    end

    def self.hours_since_update(issue)
      ((Time.now - issue.updated_on) / 3600).round
    end
  end

  class RedmineAuditAdapter < DecisionAgent::Audit::Adapter
    def record(decision, context)
      # Store in Redmine custom field or separate table
      Rails.logger.info "[DecisionAgent] #{decision.decision} (confidence: #{decision.confidence})"
    end
  end
end
```

### Standalone Service

```ruby
#!/usr/bin/env ruby
require 'decision_agent'
require 'json'

# Load rules
rules = JSON.parse(File.read("config/rules.json"))

# Build agent
agent = DecisionAgent::Agent.new(
  evaluators: [
    DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
  ],
  scoring_strategy: DecisionAgent::Scoring::Threshold.new(
    threshold: 0.75,
    fallback_decision: "manual_review"
  ),
  audit_adapter: DecisionAgent::Audit::LoggerAdapter.new
)

# Read context from stdin
context = JSON.parse(STDIN.read)

# Decide
result = agent.decide(context: context)

# Output decision
output = {
  decision: result.decision,
  confidence: result.confidence,
  explanations: result.explanations
}

puts JSON.pretty_generate(output)
```

## Design Philosophy

### Why Deterministic > AI

1. **Regulatory Compliance**: Healthcare (HIPAA), finance (SOX), and government require auditable, explainable decisions
2. **Cost**: Rules are free to evaluate; LLM calls cost money and add latency
3. **Reliability**: Same input must produce same output for testing and legal defensibility
4. **Transparency**: Business rules are explicit and reviewable by domain experts
5. **AI Enhancement**: AI can suggest rule adjustments, but rules make final decisions

### When to Use DecisionAgent

- **Regulated domains**: Healthcare, finance, legal, government
- **Business rule engines**: Complex decision trees with multiple evaluators
- **Compliance requirements**: Need full audit trails and decision replay
- **Explainability required**: Humans must understand why decisions were made
- **Deterministic systems**: Same input must always produce same output

### When NOT to Use

- Simple if/else logic (just use Ruby)
- Purely AI-driven decisions with no rules
- Single-step validations (use dry-validation)

## Testing

```ruby
# spec/my_decision_spec.rb
RSpec.describe "My Decision Logic" do
  it "escalates critical issues" do
    rules = { ... }
    evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
    agent = DecisionAgent::Agent.new(evaluators: [evaluator])

    result = agent.decide(
      context: { priority: "critical", hours_inactive: 3 }
    )

    expect(result.decision).to eq("escalate")
    expect(result.confidence).to be > 0.8
  end
end
```

## Error Handling

All errors are namespaced under `DecisionAgent`:

```ruby
begin
  agent.decide(context: {})
rescue DecisionAgent::NoEvaluationsError
  # No evaluator returned a decision
rescue DecisionAgent::InvalidRuleDslError => e
  # JSON rule DSL is malformed
  puts e.message
rescue DecisionAgent::ReplayMismatchError => e
  # Replay produced different result
  puts "Expected: #{e.expected}"
  puts "Actual: #{e.actual}"
  puts "Differences: #{e.differences}"
end
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests (maintain 90%+ coverage)
4. Ensure all tests pass: `rspec`
5. Submit a pull request

## License

MIT License. See [LICENSE.txt](LICENSE.txt).

## Roadmap

- [ ] Performance benchmarks
- [ ] Rule validation CLI
- [ ] Web UI for rule editing
- [ ] Prometheus metrics adapter
- [ ] Additional scoring strategies (Bayesian, etc.)
- [ ] AI evaluator adapter (optional, non-deterministic mode)

## Support

- GitHub Issues: [https://github.com/decision-agent/decision_agent/issues](https://github.com/decision-agent/decision_agent/issues)
- Documentation: [https://decision-agent.dev](https://decision-agent.dev)

---

**Built for regulated domains. Deterministic by design. AI-optional.**
