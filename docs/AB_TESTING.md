# A/B Testing Guide

**A/B Testing** allows you to compare different rule versions (champion vs challenger) with live traffic to determine which performs better. This guide covers setup, usage, and best practices for running A/B tests with decision_agent.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Configuration](#configuration)
- [Traffic Splitting](#traffic-splitting)
- [Statistical Analysis](#statistical-analysis)
- [Rails Integration](#rails-integration)
- [API Reference](#api-reference)
- [Best Practices](#best-practices)
- [Examples](#examples)

---

## Overview

A/B testing in decision_agent enables you to:

- **Compare rule versions**: Test a new rule version against the current production version
- **Control traffic distribution**: Split traffic between champion (current) and challenger (new) versions
- **Track performance**: Automatically log decisions and confidence scores for each variant
- **Statistical analysis**: Get confidence intervals and significance testing for results
- **Safe rollouts**: Gradually increase traffic to new versions based on performance

---

## Quick Start

### 1. Basic Setup (In-Memory)

```ruby
require "decision_agent"

# Create version manager
version_manager = DecisionAgent::Versioning::VersionManager.new

# Create two rule versions
champion = version_manager.save_version(
  rule_id: "approval_rules",
  rule_content: { rules: [...] },
  created_by: "system"
)

challenger = version_manager.save_version(
  rule_id: "approval_rules",
  rule_content: { rules: [...] },  # Different rules
  created_by: "system"
)

# Create A/B test manager
ab_test_manager = DecisionAgent::ABTesting::ABTestManager.new(
  version_manager: version_manager
)

# Create an A/B test
test = ab_test_manager.create_test(
  name: "Approval Threshold Test",
  champion_version_id: champion[:id],
  challenger_version_id: challenger[:id],
  traffic_split: { champion: 90, challenger: 10 }  # 90/10 split
)

# Start the test
ab_test_manager.start_test(test.id)
```

### 2. Make Decisions with A/B Testing

```ruby
# Create A/B testing agent
ab_agent = DecisionAgent::ABTesting::ABTestingAgent.new(
  ab_test_manager: ab_test_manager,
  version_manager: version_manager
)

# Make a decision with A/B test
result = ab_agent.decide(
  context: { amount: 1000, user_type: "premium" },
  ab_test_id: test.id,
  user_id: "user_123"  # Same user always gets same variant
)

puts result[:decision]           # => "approve"
puts result[:confidence]         # => 0.95
puts result[:ab_test][:variant]  # => :champion or :challenger
```

### 3. Analyze Results

```ruby
results = ab_test_manager.get_results(test.id)

puts "Champion avg confidence: #{results[:champion][:avg_confidence]}"
puts "Challenger avg confidence: #{results[:challenger][:avg_confidence]}"
puts "Improvement: #{results[:comparison][:improvement_percentage]}%"
puts "Winner: #{results[:comparison][:winner]}"
puts "Recommendation: #{results[:comparison][:recommendation]}"
```

---

## Core Concepts

### ABTest

Represents an A/B test configuration:

```ruby
class ABTest
  attr_reader :id, :name, :champion_version_id, :challenger_version_id,
              :traffic_split, :start_date, :end_date, :status
end
```

**Attributes:**
- `name`: Human-readable test name
- `champion_version_id`: ID of the current/production version
- `challenger_version_id`: ID of the new/test version
- `traffic_split`: Hash with percentage split (e.g., `{ champion: 90, challenger: 10 }`)
- `start_date`: When the test starts
- `end_date`: When the test ends (optional)
- `status`: `scheduled`, `running`, `completed`, or `cancelled`

### ABTestAssignment

Tracks individual variant assignments:

```ruby
class ABTestAssignment
  attr_reader :id, :ab_test_id, :user_id, :variant, :version_id,
              :decision_result, :confidence, :context
end
```

Each time a decision is made with an A/B test, an assignment is created to track:
- Which variant was used (`:champion` or `:challenger`)
- Which version ID was actually executed
- The decision result and confidence score
- Additional context for analysis

### ABTestManager

Orchestrates A/B test lifecycle:

```ruby
manager = DecisionAgent::ABTesting::ABTestManager.new(
  storage_adapter: storage_adapter,    # Where to persist tests
  version_manager: version_manager     # For accessing rule versions
)
```

**Key Methods:**
- `create_test(...)` - Create a new test
- `start_test(test_id)` - Start a scheduled test
- `complete_test(test_id)` - Complete a running test
- `assign_variant(test_id:, user_id:)` - Assign a variant
- `get_results(test_id)` - Get statistical results

### ABTestingAgent

Agent wrapper that handles A/B testing automatically:

```ruby
ab_agent = DecisionAgent::ABTesting::ABTestingAgent.new(
  ab_test_manager: manager,
  version_manager: version_manager,
  evaluators: base_evaluators  # Optional fallback evaluators
)
```

---

## Configuration

### Traffic Split

Control the percentage of traffic sent to each variant:

```ruby
# Conservative: 90% champion, 10% challenger
traffic_split: { champion: 90, challenger: 10 }

# Balanced: 50/50 split
traffic_split: { champion: 50, challenger: 50 }

# Aggressive: 70% challenger (when confident)
traffic_split: { champion: 30, challenger: 70 }

# Array format also supported
traffic_split: [90, 10]  # champion, challenger
```

**Best Practice:** Start with conservative splits (95/5 or 90/10) and increase challenger traffic as confidence grows.

### Test Duration

```ruby
# Start immediately, no end date
test = manager.create_test(
  name: "Test",
  champion_version_id: v1,
  challenger_version_id: v2,
  start_date: Time.now.utc
)

# Schedule for future
test = manager.create_test(
  name: "Scheduled Test",
  champion_version_id: v1,
  challenger_version_id: v2,
  start_date: Time.now.utc + 86400,  # Tomorrow
  end_date: Time.now.utc + 604800    # 7 days
)
```

### Storage Options

#### In-Memory (Development/Testing)

```ruby
storage = DecisionAgent::ABTesting::Storage::MemoryAdapter.new
manager = DecisionAgent::ABTesting::ABTestManager.new(storage_adapter: storage)
```

#### ActiveRecord (Production)

```ruby
# Run generator to create models
rails generate decision_agent:install

# Use ActiveRecord adapter
storage = DecisionAgent::ABTesting::Storage::ActiveRecordAdapter.new
manager = DecisionAgent::ABTesting::ABTestManager.new(storage_adapter: storage)
```

---

## Traffic Splitting

### Random Assignment

Without a `user_id`, each request is randomly assigned:

```ruby
result = ab_agent.decide(
  context: { amount: 100 },
  ab_test_id: test.id
  # No user_id = random assignment
)
```

### Consistent Assignment (Recommended)

Provide a `user_id` to ensure the same user always gets the same variant:

```ruby
result = ab_agent.decide(
  context: { amount: 100 },
  ab_test_id: test.id,
  user_id: current_user.id  # Consistent assignment
)
```

**How it works:** Uses SHA256 hash of `"test_id:user_id"` to deterministically assign variants.

**Why it matters:**
- Prevents user confusion from seeing different behaviors
- Enables proper user-level analysis
- Required for meaningful statistical comparison

---

## Statistical Analysis

### Results Structure

```ruby
results = manager.get_results(test.id)

{
  test: { id:, name:, status:, ... },
  champion: {
    label: "Champion",
    total_assignments: 900,
    decisions_recorded: 850,
    avg_confidence: 0.85,
    min_confidence: 0.45,
    max_confidence: 0.99,
    decision_distribution: { "approve" => 600, "reject" => 250 }
  },
  challenger: {
    label: "Challenger",
    total_assignments: 100,
    decisions_recorded: 95,
    avg_confidence: 0.92,
    ...
  },
  comparison: {
    champion_avg_confidence: 0.85,
    challenger_avg_confidence: 0.92,
    improvement_percentage: 8.24,
    winner: "challenger",
    statistical_significance: "significant",  # or "not_significant"
    confidence_level: 0.95,                   # 95% confidence
    recommendation: "Strong evidence to promote challenger"
  },
  total_assignments: 1000
}
```

### Statistical Significance

Uses **Welch's t-test** to determine if the difference is statistically significant:

```ruby
comparison = results[:comparison]

if comparison[:statistical_significance] == "significant"
  puts "Winner: #{comparison[:winner]} (#{comparison[:confidence_level] * 100}% confidence)"
  puts comparison[:recommendation]
else
  puts "Not enough data for statistical significance"
end
```

**Confidence Levels:**
- `0.90` (90%) - Marginal significance
- `0.95` (95%) - Standard threshold
- `0.99` (99%) - High confidence

**Minimum Sample Size:** Requires at least 30 decisions per variant for statistical testing.

### Recommendations

The system provides actionable recommendations:

| Improvement | Significance | Recommendation |
|------------|--------------|----------------|
| > 5% | Significant | "Strong evidence to promote challenger" |
| 0-5% | Significant | "Moderate evidence to promote challenger" |
| -5% to 0% | Significant | "Results are similar - consider other factors" |
| < -5% | Significant | "Keep champion - challenger performs worse" |
| Any | Not significant | "Continue testing - not enough data" |

---

## Rails Integration

### 1. Installation

```bash
rails generate decision_agent:install
```

This creates:
- `db/migrate/*_create_decision_agent_ab_testing_tables.rb`
- `app/models/ab_test_model.rb`
- `app/models/ab_test_assignment_model.rb`
- `lib/tasks/ab_testing_tasks.rake`

### 2. Run Migration

```bash
rails db:migrate
```

### 3. Use in Controllers

```ruby
class DecisionsController < ApplicationController
  def create
    ab_agent = DecisionAgent::ABTesting::ABTestingAgent.new(
      ab_test_manager: ab_test_manager,
      version_manager: version_manager
    )

    result = ab_agent.decide(
      context: decision_params,
      ab_test_id: params[:ab_test_id],
      user_id: current_user.id
    )

    render json: {
      decision: result[:decision],
      confidence: result[:confidence],
      variant: result[:ab_test][:variant]
    }
  end

  private

  def ab_test_manager
    @ab_test_manager ||= DecisionAgent::ABTesting::ABTestManager.new(
      storage_adapter: DecisionAgent::ABTesting::Storage::ActiveRecordAdapter.new,
      version_manager: version_manager
    )
  end
end
```

### 4. Rake Tasks

```bash
# List all tests
rake decision_agent:ab_testing:list

# Create a test
rake decision_agent:ab_testing:create["My Test",1,2,"90,10"]

# Start a test
rake decision_agent:ab_testing:start[123]

# View results
rake decision_agent:ab_testing:results[123]

# Complete a test
rake decision_agent:ab_testing:complete[123]

# Show active tests
rake decision_agent:ab_testing:active
```

### 5. Admin Interface

Query tests and results using ActiveRecord:

```ruby
# Get all active tests
active_tests = ABTestModel.active

# Get test statistics
test = ABTestModel.find(params[:id])
stats = test.statistics

# Get assignments
champion_assignments = test.champion_assignments.with_decisions
challenger_assignments = test.challenger_assignments.with_decisions

# Query by user
user_assignments = ABTestAssignmentModel.for_user(current_user.id)
```

---

## API Reference

### ABTestManager

#### `create_test`

```ruby
test = manager.create_test(
  name: String,
  champion_version_id: String|Integer,
  challenger_version_id: String|Integer,
  traffic_split: Hash,           # Optional, default: { champion: 90, challenger: 10 }
  start_date: Time,              # Optional, default: Time.now.utc
  end_date: Time                 # Optional, default: nil
)
# => ABTest
```

#### `assign_variant`

```ruby
assignment = manager.assign_variant(
  test_id: Integer,
  user_id: String                # Optional, for consistent assignment
)
# => { test_id:, variant:, version_id:, assignment_id: }
```

#### `get_results`

```ruby
results = manager.get_results(test_id)
# => Hash with :test, :champion, :challenger, :comparison, :total_assignments
```

#### `start_test`, `complete_test`, `cancel_test`

```ruby
manager.start_test(test_id)
manager.complete_test(test_id)
manager.cancel_test(test_id)
```

### ABTestingAgent

#### `decide`

```ruby
result = ab_agent.decide(
  context: Hash|Context,
  feedback: Hash,                # Optional
  ab_test_id: Integer,           # Optional
  user_id: String                # Optional
)
# => {
#   decision:,
#   confidence:,
#   explanations:,
#   evaluations:,
#   ab_test: { test_id:, variant:, version_id:, assignment_id: }
# }
```

---

## Best Practices

### 1. Start Conservative

Begin with a **90/10** or **95/5** split:

```ruby
traffic_split: { champion: 90, challenger: 10 }
```

### 2. Use Consistent Assignment

Always provide `user_id` for consistent user experience:

```ruby
ab_agent.decide(context: ctx, ab_test_id: test.id, user_id: user.id)
```

### 3. Define Clear Success Metrics

Know what you're optimizing for:
- Average confidence score
- Decision distribution (approve vs reject)
- Specific business metrics

### 4. Wait for Statistical Significance

Don't make decisions until you have:
- At least **30 decisions per variant** (minimum)
- **100+ decisions per variant** (recommended)
- Statistical significance at **95% confidence**

### 5. Monitor Both Variants

Check for:
- Performance degradation
- Error rates
- Edge cases

### 6. Gradual Rollout

```ruby
# Week 1: 95/5 split
# Week 2: If positive, 90/10
# Week 3: If still positive, 70/30
# Week 4: If successful, promote challenger to 100%
```

### 7. Document Test Hypotheses

```ruby
test = manager.create_test(
  name: "Hypothesis: Lowering approval threshold increases confidence",
  champion_version_id: v1,
  challenger_version_id: v2
)
```

### 8. Set Time Limits

```ruby
test = manager.create_test(
  name: "Test",
  champion_version_id: v1,
  challenger_version_id: v2,
  end_date: Time.now.utc + 14.days  # Auto-end after 2 weeks
)
```

---

## Examples

This section provides 14 comprehensive examples covering all A/B testing features:

| Example | Feature Covered | Description |
|---------|----------------|-------------|
| [Example 1](#example-1-simple-approval-rules-test) | Basic Test Setup | Create and run a simple A/B test |
| [Example 2](#example-2-multi-evaluator-test) | Multi-Evaluator Rules | Test rules with multiple evaluators |
| [Example 3](#example-3-progressive-rollout) | Progressive Rollout | Gradually increase traffic to challenger |
| [Example 4](#example-4-scheduled-tests-with-time-limits) | Scheduled Tests | Schedule tests with start/end dates |
| [Example 5](#example-5-random-vs-consistent-assignment) | User Assignment | Random vs consistent variant assignment |
| [Example 6](#example-6-listing-and-filtering-tests) | Test Queries | List and filter tests by status |
| [Example 7](#example-7-test-lifecycle-management) | Lifecycle Management | Start, complete, and cancel tests |
| [Example 8](#example-8-rails-controller-integration) | Rails Integration | Use A/B testing in Rails controllers |
| [Example 9](#example-9-activerecord-queries-and-scopes) | ActiveRecord Queries | Query tests and assignments with ActiveRecord |
| [Example 10](#example-10-monitoring-integration) | Monitoring | Integrate with Prometheus, Datadog, etc. |
| [Example 11](#example-11-decision-distribution-analysis) | Decision Analysis | Analyze decision distribution and rates |
| [Example 12](#example-12-rake-tasks-usage) | Rake Tasks | Manage tests using rake commands |
| [Example 13](#example-13-traffic-split-variations) | Traffic Splits | Different traffic split configurations |
| [Example 14](#example-14-in-memory-vs-activerecord-storage) | Storage Options | Memory vs ActiveRecord storage |

### Example 1: Simple Approval Rules Test

```ruby
# Create versions
champion = version_manager.save_version(
  rule_id: "approval",
  rule_content: {
    rules: [
      { condition: { field: "amount", operator: "gt", value: 1000 },
        decision: "approve", weight: 1.0 }
    ]
  }
)

challenger = version_manager.save_version(
  rule_id: "approval",
  rule_content: {
    rules: [
      { condition: { field: "amount", operator: "gt", value: 500 },
        decision: "approve", weight: 1.0 }
    ]
  }
)

# Create test
test = manager.create_test(
  name: "Lower Approval Threshold Test",
  champion_version_id: champion[:id],
  challenger_version_id: challenger[:id],
  traffic_split: { champion: 90, challenger: 10 }
)

manager.start_test(test.id)

# Run for a week, then check results
results = manager.get_results(test.id)
```

### Example 2: Multi-Evaluator Test

```ruby
champion = version_manager.save_version(
  rule_id: "risk",
  rule_content: {
    evaluators: [
      { type: "json_rule", rules: [...], weight: 1.0 },
      { type: "static", decision: "review", weight: 0.5 }
    ]
  }
)

challenger = version_manager.save_version(
  rule_id: "risk",
  rule_content: {
    evaluators: [
      { type: "json_rule", rules: [...], weight: 1.5 },
      { type: "static", decision: "approve", weight: 0.3 }
    ]
  }
)
```

### Example 3: Progressive Rollout

```ruby
# Start conservative
test = manager.create_test(
  name: "Progressive Rollout",
  champion_version_id: v1,
  challenger_version_id: v2,
  traffic_split: { champion: 95, challenger: 5 }
)
manager.start_test(test.id)

# After 1000 decisions, check results
results = manager.get_results(test.id)

if results[:comparison][:winner] == "challenger" &&
   results[:comparison][:statistical_significance] == "significant"

  # Increase challenger traffic
  manager.complete_test(test.id)

  new_test = manager.create_test(
    name: "Progressive Rollout - Phase 2",
    champion_version_id: v1,
    challenger_version_id: v2,
    traffic_split: { champion: 70, challenger: 30 }
  )
  manager.start_test(new_test.id)
end
```

### Example 4: Scheduled Tests with Time Limits

```ruby
# Schedule a test to start tomorrow and run for 7 days
test = manager.create_test(
  name: "Weekly Approval Threshold Test",
  champion_version_id: champion_version[:id],
  challenger_version_id: challenger_version[:id],
  traffic_split: { champion: 80, challenger: 20 },
  start_date: Time.now.utc + 86400,      # Start tomorrow
  end_date: Time.now.utc + (7 * 86400)   # End in 7 days
)

puts "Test Status: #{test.status}"  # => "scheduled"

# Manually start if needed (before scheduled time)
manager.start_test(test.id)
puts "Test Status: #{manager.get_test(test.id).status}"  # => "running"

# The test will auto-complete after end_date
# Or manually complete it
manager.complete_test(test.id)
```

### Example 5: Random vs Consistent Assignment

```ruby
# Random assignment - different variant each time
result1 = ab_agent.decide(
  context: { amount: 1000 },
  ab_test_id: test.id
  # No user_id provided
)

result2 = ab_agent.decide(
  context: { amount: 1000 },
  ab_test_id: test.id
  # No user_id provided
)

puts result1[:ab_test][:variant]  # Could be :champion or :challenger
puts result2[:ab_test][:variant]  # Could be different from result1

# Consistent assignment - same user always gets same variant
user_id = "user_123"

result3 = ab_agent.decide(
  context: { amount: 1000 },
  ab_test_id: test.id,
  user_id: user_id
)

result4 = ab_agent.decide(
  context: { amount: 1000 },
  ab_test_id: test.id,
  user_id: user_id
)

puts result3[:ab_test][:variant]  # e.g., :champion
puts result4[:ab_test][:variant]  # Always :champion (same as result3)
```

### Example 6: Listing and Filtering Tests

```ruby
# List all tests
all_tests = manager.list_tests
puts "Total tests: #{all_tests.size}"

# List only running tests
running_tests = manager.list_tests(status: "running")
puts "Running tests: #{running_tests.size}"

# List completed tests
completed_tests = manager.list_tests(status: "completed")
puts "Completed tests: #{completed_tests.size}"

# List with limit
recent_tests = manager.list_tests(limit: 10)
puts "Recent 10 tests: #{recent_tests.size}"

# Get active tests (running only, with caching)
active = manager.active_tests
active.each do |test|
  puts "Active: #{test.name} (ID: #{test.id})"
end
```

### Example 7: Test Lifecycle Management

```ruby
# Create a scheduled test
test = manager.create_test(
  name: "Lifecycle Demo",
  champion_version_id: v1,
  challenger_version_id: v2,
  start_date: Time.now.utc + 3600  # Start in 1 hour
)

puts test.status  # => "scheduled"

# Start the test manually
manager.start_test(test.id)
test = manager.get_test(test.id)
puts test.status  # => "running"

# Run some decisions...
100.times do |i|
  ab_agent.decide(
    context: { amount: 1000 },
    ab_test_id: test.id,
    user_id: "user_#{i}"
  )
end

# Check if we should complete based on results
results = manager.get_results(test.id)
if results[:comparison][:statistical_significance] == "significant"
  # Complete the test
  manager.complete_test(test.id)
  test = manager.get_test(test.id)
  puts test.status  # => "completed"
  puts "End date: #{test.end_date}"
else
  # Cancel if results are not good
  manager.cancel_test(test.id)
  test = manager.get_test(test.id)
  puts test.status  # => "cancelled"
end
```

### Example 8: Rails Controller Integration

```ruby
# app/controllers/decisions_controller.rb
class DecisionsController < ApplicationController
  before_action :setup_ab_testing

  def create
    result = @ab_agent.decide(
      context: {
        amount: params[:amount].to_f,
        user_type: current_user.user_type,
        risk_score: params[:risk_score].to_f
      },
      ab_test_id: params[:ab_test_id],
      user_id: current_user.id
    )

    render json: {
      decision: result[:decision],
      confidence: result[:confidence],
      ab_test: {
        variant: result[:ab_test][:variant],
        version_id: result[:ab_test][:version_id]
      },
      explanations: result[:explanations]
    }
  end

  def ab_test_stats
    test_id = params[:id]
    results = @ab_test_manager.get_results(test_id)

    render json: results
  end

  private

  def setup_ab_testing
    @version_manager = DecisionAgent::Versioning::VersionManager.new(
      adapter: DecisionAgent::Versioning::ActiveRecordAdapter.new
    )

    @ab_test_manager = DecisionAgent::ABTesting::ABTestManager.new(
      storage_adapter: DecisionAgent::ABTesting::Storage::ActiveRecordAdapter.new,
      version_manager: @version_manager
    )

    @ab_agent = DecisionAgent::ABTesting::ABTestingAgent.new(
      ab_test_manager: @ab_test_manager,
      version_manager: @version_manager
    )
  end
end
```

### Example 9: ActiveRecord Queries and Scopes

```ruby
# Using the ActiveRecord models directly

# Get all active tests
active_tests = ABTestModel.active
active_tests.each do |test|
  puts "#{test.name}: #{test.status}"
end

# Get completed tests
completed = ABTestModel.completed
puts "Completed tests: #{completed.count}"

# Get test with statistics
test = ABTestModel.find(params[:id])
stats = test.statistics

# Get champion assignments with decisions
champion_assignments = test.champion_assignments.with_decisions
puts "Champion decisions: #{champion_assignments.count}"

# Get challenger assignments with decisions
challenger_assignments = test.challenger_assignments.with_decisions
puts "Challenger decisions: #{challenger_assignments.count}"

# Query assignments by user
user_assignments = ABTestAssignmentModel.for_user("user_123")
user_assignments.each do |assignment|
  puts "User was assigned to: #{assignment.variant}"
  puts "Decision: #{assignment.decision_result}"
  puts "Confidence: #{assignment.confidence}"
end

# Get all assignments for a specific variant
champion_only = ABTestAssignmentModel.for_variant(:champion)
challenger_only = ABTestAssignmentModel.for_variant(:challenger)

# Get recent assignments
recent = ABTestAssignmentModel.recent(limit: 100)
recent.each do |assignment|
  puts "Recent: Test #{assignment.ab_test_id}, Variant: #{assignment.variant}"
end
```

### Example 10: Monitoring Integration

```ruby
# Integration with monitoring systems (Prometheus, Datadog, etc.)

class ABTestMonitor
  def initialize(ab_test_manager, metrics_client)
    @manager = ab_test_manager
    @metrics = metrics_client
  end

  def report_metrics
    active_tests = @manager.active_tests

    active_tests.each do |test|
      results = @manager.get_results(test.id)

      # Report champion metrics
      @metrics.gauge(
        "ab_test.champion.avg_confidence",
        results[:champion][:avg_confidence] || 0,
        tags: ["test_id:#{test.id}", "test_name:#{test.name}"]
      )

      @metrics.gauge(
        "ab_test.champion.total_assignments",
        results[:champion][:total_assignments],
        tags: ["test_id:#{test.id}", "test_name:#{test.name}"]
      )

      # Report challenger metrics
      @metrics.gauge(
        "ab_test.challenger.avg_confidence",
        results[:challenger][:avg_confidence] || 0,
        tags: ["test_id:#{test.id}", "test_name:#{test.name}"]
      )

      @metrics.gauge(
        "ab_test.challenger.total_assignments",
        results[:challenger][:total_assignments],
        tags: ["test_id:#{test.id}", "test_name:#{test.name}"]
      )

      # Report comparison metrics
      if results[:comparison][:statistical_significance] != "insufficient_data"
        @metrics.gauge(
          "ab_test.improvement_percentage",
          results[:comparison][:improvement_percentage],
          tags: ["test_id:#{test.id}", "test_name:#{test.name}"]
        )

        @metrics.gauge(
          "ab_test.confidence_level",
          results[:comparison][:confidence_level],
          tags: ["test_id:#{test.id}", "test_name:#{test.name}"]
        )
      end
    end
  end
end

# Use in a background job or scheduled task
monitor = ABTestMonitor.new(ab_test_manager, metrics_client)
monitor.report_metrics
```

### Example 11: Decision Distribution Analysis

```ruby
# Analyze decision distribution for each variant
results = manager.get_results(test.id)

puts "Champion Decision Distribution:"
results[:champion][:decision_distribution].each do |decision, count|
  percentage = (count.to_f / results[:champion][:decisions_recorded] * 100).round(2)
  puts "  #{decision}: #{count} (#{percentage}%)"
end

puts "\nChallenger Decision Distribution:"
results[:challenger][:decision_distribution].each do |decision, count|
  percentage = (count.to_f / results[:challenger][:decisions_recorded] * 100).round(2)
  puts "  #{decision}: #{count} (#{percentage}%)"
end

# Compare specific decision rates
champion_approvals = results[:champion][:decision_distribution]["approve"] || 0
champion_total = results[:champion][:decisions_recorded]
champion_approval_rate = (champion_approvals.to_f / champion_total * 100).round(2)

challenger_approvals = results[:challenger][:decision_distribution]["approve"] || 0
challenger_total = results[:challenger][:decisions_recorded]
challenger_approval_rate = (challenger_approvals.to_f / challenger_total * 100).round(2)

puts "\nApproval Rate Comparison:"
puts "  Champion: #{champion_approval_rate}%"
puts "  Challenger: #{challenger_approval_rate}%"
puts "  Difference: #{(challenger_approval_rate - champion_approval_rate).round(2)}%"
```

### Example 12: Rake Tasks Usage

```bash
# List all A/B tests
rake decision_agent:ab_testing:list

# Output:
# ID  | Name                    | Status    | Traffic Split      | Start Date
# 1   | Approval Threshold Test | running   | 90% / 10%         | 2025-01-15
# 2   | Risk Assessment Test    | completed | 80% / 20%         | 2025-01-10

# Create a new test
rake decision_agent:ab_testing:create["My Test Name",1,2,"90,10"]

# Start a scheduled test
rake decision_agent:ab_testing:start[1]

# View detailed results
rake decision_agent:ab_testing:results[1]

# Output:
# Test: Approval Threshold Test (ID: 1)
# Status: running
#
# Champion (Version 1):
#   Assignments: 900
#   Avg Confidence: 0.85
#   Decisions: approve: 600, reject: 300
#
# Challenger (Version 2):
#   Assignments: 100
#   Avg Confidence: 0.92
#   Decisions: approve: 70, reject: 30
#
# Comparison:
#   Winner: challenger
#   Improvement: 8.24%
#   Recommendation: Strong evidence to promote challenger

# Complete a test
rake decision_agent:ab_testing:complete[1]

# Show only active tests
rake decision_agent:ab_testing:active

# Cancel a test
rake decision_agent:ab_testing:cancel[1]
```

### Example 13: Traffic Split Variations

```ruby
# Conservative split - 95/5
test1 = manager.create_test(
  name: "Conservative Test",
  champion_version_id: v1,
  challenger_version_id: v2,
  traffic_split: { champion: 95, challenger: 5 }
)

# Balanced split - 50/50
test2 = manager.create_test(
  name: "Balanced Test",
  champion_version_id: v1,
  challenger_version_id: v2,
  traffic_split: { champion: 50, challenger: 50 }
)

# Aggressive split - 70/30
test3 = manager.create_test(
  name: "Aggressive Test",
  champion_version_id: v1,
  challenger_version_id: v2,
  traffic_split: { champion: 30, challenger: 70 }
)

# Array format (also supported)
test4 = manager.create_test(
  name: "Array Format Test",
  champion_version_id: v1,
  challenger_version_id: v2,
  traffic_split: [80, 20]  # champion, challenger
)
```

### Example 14: In-Memory vs ActiveRecord Storage

```ruby
# In-Memory Storage (for development/testing)
memory_storage = DecisionAgent::ABTesting::Storage::MemoryAdapter.new
memory_manager = DecisionAgent::ABTesting::ABTestManager.new(
  storage_adapter: memory_storage,
  version_manager: version_manager
)

# Data is lost when process ends
test = memory_manager.create_test(
  name: "Memory Test",
  champion_version_id: v1,
  challenger_version_id: v2
)

# ActiveRecord Storage (for production)
# First, run the generator and migration
# rails generate decision_agent:install
# rails db:migrate

ar_storage = DecisionAgent::ABTesting::Storage::ActiveRecordAdapter.new
ar_manager = DecisionAgent::ABTesting::ABTestManager.new(
  storage_adapter: ar_storage,
  version_manager: version_manager
)

# Data persists in database
test = ar_manager.create_test(
  name: "Persistent Test",
  champion_version_id: v1,
  challenger_version_id: v2
)

# Query directly using ActiveRecord
ABTestModel.where(status: "running").each do |test|
  puts "Persistent test: #{test.name}"
end
```

---

## Dashboard & Monitoring

### Real-time Monitoring

```ruby
# Get live statistics
active_tests = manager.active_tests

active_tests.each do |test|
  results = manager.get_results(test.id)

  puts "Test: #{test.name}"
  puts "  Assignments: #{results[:total_assignments]}"
  puts "  Champion Confidence: #{results[:champion][:avg_confidence]}"
  puts "  Challenger Confidence: #{results[:challenger][:avg_confidence]}"
  puts "  Current Winner: #{results[:comparison][:winner]}"
end
```

### Integration with Monitoring Systems

```ruby
# Export to Prometheus, Datadog, etc.
results = manager.get_results(test.id)

metrics_client.gauge(
  "ab_test.champion.confidence",
  results[:champion][:avg_confidence],
  tags: ["test_id:#{test.id}"]
)

metrics_client.gauge(
  "ab_test.challenger.confidence",
  results[:challenger][:avg_confidence],
  tags: ["test_id:#{test.id}"]
)
```

---

## Troubleshooting

### No assignments appearing

- Check test status: `test.status` should be `"running"`
- Verify dates: `test.start_date` should be in the past
- Check agent usage: Are you passing `ab_test_id` to `decide()`?

### Same variant every time

- This is expected with `user_id` - it ensures consistency
- Use different `user_id` values to see different variants
- Check traffic split: 99/1 will rarely show challenger

### Insufficient data error

- Minimum 30 decisions per variant required
- Continue running test to gather more data
- Check that decisions are being recorded properly

### Results seem incorrect

- Verify both champion and challenger versions exist
- Check decision recording: `manager.record_decision(...)` is being called
- Inspect raw assignments: `storage_adapter.get_assignments(test_id)`

---

## See Also

- [Versioning Guide](VERSIONING.md) - Managing rule versions
- [Monitoring Guide](MONITORING_AND_ANALYTICS.md) - Metrics and analytics
- [API Contract](API_CONTRACT.md) - Core API reference

---

**Next:** See [examples/07_ab_testing.rb](../examples/07_ab_testing.rb) for a complete working example.
