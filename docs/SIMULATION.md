# Simulation and What-If Analysis

DecisionAgent provides comprehensive simulation and what-if analysis capabilities to help you test rule changes, predict impact, and validate decisions before deploying to production.

## Table of Contents

- [Overview](#overview)
- [Historical Replay / Backtesting](#historical-replay--backtesting)
- [What-If Analysis](#what-if-analysis)
- [Impact Analysis](#impact-analysis)
- [Shadow Testing](#shadow-testing)
- [Scenario Engine](#scenario-engine)
- [Scenario Library](#scenario-library)
- [Best Practices](#best-practices)

## Overview

The Simulation module provides five main capabilities:

1. **Historical Replay / Backtesting** - Replay historical decisions with different rule versions
2. **What-If Analysis** - Simulate scenarios and perform sensitivity analysis
3. **Impact Analysis** - Quantify the impact of rule changes before deployment
4. **Shadow Testing** - Compare new rules against production without affecting outcomes
5. **Scenario Engine** - Manage and execute test scenarios

## Historical Replay / Backtesting

Replay historical decisions with different rule versions to see how outcomes would change.

### Basic Usage

```ruby
require 'decision_agent'

# Create agent and version manager
agent = DecisionAgent::Agent.new(evaluators: [evaluator])
version_manager = DecisionAgent::Versioning::VersionManager.new

# Create replay engine
replay_engine = DecisionAgent::Simulation::ReplayEngine.new(
  agent: agent,
  version_manager: version_manager
)

# Historical data (array of contexts)
historical_data = [
  { credit_score: 550, amount: 50_000 },
  { credit_score: 650, amount: 75_000 },
  { credit_score: 750, amount: 100_000 }
]

# Replay with current rules
results = replay_engine.replay(historical_data: historical_data)

puts "Total decisions: #{results[:total_decisions]}"
puts "Decision distribution: #{results[:decision_distribution]}"
```

### Loading from Files

ReplayEngine supports loading historical data from CSV or JSON files:

```ruby
# From CSV file
results = replay_engine.replay(historical_data: "decisions_2025.csv")

# From JSON file
results = replay_engine.replay(historical_data: "decisions_2025.json")
```

**CSV Format:**
```csv
credit_score,amount,income
550,50000,30000
650,75000,60000
750,100000,100000
```

**JSON Format:**
```json
[
  { "credit_score": 550, "amount": 50000, "income": 30000 },
  { "credit_score": 650, "amount": 75000, "income": 60000 },
  { "credit_score": 750, "amount": 100000, "income": 100000 }
]
```

### Comparing Versions

Compare outcomes between baseline and proposed versions:

```ruby
# Replay with proposed version and compare with baseline
results = replay_engine.replay(
  historical_data: historical_data,
  rule_version: proposed_version_id,
  compare_with: baseline_version_id
)

puts "Changed decisions: #{results[:changed_decisions]}"
puts "Change rate: #{(results[:change_rate] * 100).round(2)}%"
puts "Average confidence delta: #{results[:average_confidence_delta]}"
```

### Backtesting

Backtest a proposed rule change against historical data:

```ruby
results = replay_engine.backtest(
  historical_data: historical_data,
  proposed_version: proposed_version_id,
  baseline_version: baseline_version_id  # Optional, defaults to active version
)

puts "Impact: #{results[:changed_decisions]} decisions changed"
puts "Risk: #{results[:change_rate]} change rate"
```

### Parallel Execution

ReplayEngine supports parallel execution for large datasets:

```ruby
results = replay_engine.replay(
  historical_data: historical_data,
  options: {
    parallel: true,
    thread_count: 8,
    progress_callback: ->(progress) {
      puts "Progress: #{progress[:percentage]}%"
    }
  }
)
```

## What-If Analysis

Simulate different scenarios and analyze how decisions change based on input variations.

### Basic Usage

```ruby
what_if_analyzer = DecisionAgent::Simulation::WhatIfAnalyzer.new(
  agent: agent,
  version_manager: version_manager
)

# Define scenarios to test
scenarios = [
  { credit_score: 550, amount: 50_000 },
  { credit_score: 600, amount: 75_000 },
  { credit_score: 650, amount: 100_000 },
  { credit_score: 700, amount: 150_000 }
]

# Analyze scenarios
results = what_if_analyzer.analyze(scenarios: scenarios)

puts "Decision distribution: #{results[:decision_distribution]}"
puts "Average confidence: #{results[:average_confidence]}"
```

### Sensitivity Analysis

Identify which input fields have the most impact on decisions:

```ruby
sensitivity_results = what_if_analyzer.sensitivity_analysis(
  base_scenario: { credit_score: 650, amount: 100_000 },
  variations: {
    credit_score: [550, 600, 650, 700, 750],
    amount: [50_000, 75_000, 100_000, 150_000, 200_000]
  }
)

puts "Most sensitive fields: #{sensitivity_results[:most_sensitive_fields]}"
sensitivity_results[:field_sensitivity].each do |field, data|
  puts "#{field}: impact=#{data[:impact]}"
end
```

### Using Different Rule Versions

Test scenarios with different rule versions:

```ruby
results = what_if_analyzer.analyze(
  scenarios: scenarios,
  rule_version: version_id,
  options: {
    sensitivity_analysis: true
  }
)
```

## Impact Analysis

Quantify the impact of rule changes before deploying to production.

### Basic Usage

```ruby
impact_analyzer = DecisionAgent::Simulation::ImpactAnalyzer.new(
  version_manager: version_manager
)

# Analyze impact of proposed version
results = impact_analyzer.analyze(
  baseline_version: baseline_version_id,
  proposed_version: proposed_version_id,
  test_data: test_contexts
)

puts "Decision changes: #{results[:decision_changes]}"
puts "Change rate: #{results[:change_rate]}"
puts "Risk score: #{results[:risk_score]}"
puts "Risk level: #{results[:risk_level]}"
```

### Impact Report Structure

The impact analysis report includes:

- **Decision Changes** - Number and rate of decisions that changed
- **Decision Distribution** - Before/after decision distributions
- **Confidence Impact** - Average delta, max shift, positive/negative shifts
- **Rule Execution Frequency** - How often rules fire (approximate)
- **Risk Score** - Calculated risk score (0.0 to 1.0)
- **Risk Level** - Categorized risk (low, medium, high, critical)

```ruby
results = impact_analyzer.analyze(
  baseline_version: baseline_version_id,
  proposed_version: proposed_version_id,
  test_data: test_contexts,
  options: {
    calculate_risk: true,
    parallel: true,
    thread_count: 4
  }
)

# Access detailed results
results[:decision_distribution][:baseline]  # Original distribution
results[:decision_distribution][:proposed]  # New distribution
results[:confidence_impact][:average_delta] # Average confidence change
results[:risk_score]                        # Risk score (0.0-1.0)
results[:risk_level]                        # "low", "medium", "high", or "critical"
```

### Risk Score Calculation

The risk score considers:

- **Change Rate** (40% weight) - Percentage of decisions that changed
- **Confidence Volatility** (30% weight) - Large confidence shifts (>0.2)
- **Rejection Risk** (30% weight) - Increase in rejections/denials

## Shadow Testing

Compare new rules against production without affecting actual outcomes.

### Basic Usage

```ruby
shadow_engine = DecisionAgent::Simulation::ShadowTestEngine.new(
  production_agent: production_agent,
  version_manager: version_manager
)

# Test a single context
result = shadow_engine.test(
  context: { credit_score: 650, amount: 100_000 },
  shadow_version: shadow_version_id
)

puts "Production: #{result[:production_decision]}"
puts "Shadow: #{result[:shadow_decision]}"
puts "Matches: #{result[:matches]}"
puts "Confidence delta: #{result[:confidence_delta]}"
```

### Batch Shadow Testing

Test multiple contexts in parallel:

```ruby
contexts = [
  { credit_score: 550, amount: 50_000 },
  { credit_score: 650, amount: 100_000 },
  { credit_score: 750, amount: 200_000 }
]

results = shadow_engine.batch_test(
  contexts: contexts,
  shadow_version: shadow_version_id,
  options: {
    parallel: true,
    thread_count: 4,
    progress_callback: ->(progress) {
      puts "Progress: #{progress[:percentage]}%"
    }
  }
)

puts "Match rate: #{(results[:match_rate] * 100).round(2)}%"
puts "Mismatches: #{results[:mismatches]}"
```

### Tracking Differences

Enable detailed difference tracking:

```ruby
result = shadow_engine.test(
  context: context,
  shadow_version: shadow_version_id,
  options: {
    track_differences: true
  }
)

if !result[:matches]
  puts "Differences: #{result[:differences]}"
end
```

## Scenario Engine

Manage and execute test scenarios with support for version comparison.

### Basic Usage

```ruby
scenario_engine = DecisionAgent::Simulation::ScenarioEngine.new(
  agent: agent,
  version_manager: version_manager
)

# Execute single scenario
scenario = {
  context: { credit_score: 650, amount: 100_000 },
  metadata: { type: "test", description: "Medium risk loan" }
}

result = scenario_engine.execute(scenario: scenario)
puts "Decision: #{result[:decision]}"
puts "Confidence: #{result[:confidence]}"
```

### Batch Execution

Execute multiple scenarios:

```ruby
scenarios = [
  { context: { credit_score: 550, amount: 50_000 } },
  { context: { credit_score: 650, amount: 100_000 } },
  { context: { credit_score: 750, amount: 200_000 } }
]

results = scenario_engine.execute_batch(
  scenarios: scenarios,
  options: {
    parallel: true,
    thread_count: 4
  }
)

puts "Total scenarios: #{results[:total_scenarios]}"
puts "Decision distribution: #{results[:decision_distribution]}"
```

### Version Comparison

Compare scenarios across different rule versions:

```ruby
results = scenario_engine.compare_versions(
  scenarios: scenarios,
  versions: [version1_id, version2_id, version3_id]
)

results[:results_by_version].each do |version_id, version_results|
  puts "Version #{version_id}:"
  puts "  Distribution: #{version_results[:decision_distribution]}"
end
```

## Scenario Library

Pre-defined scenario templates for common use cases.

### Available Templates

```ruby
# List all templates
templates = DecisionAgent::Simulation::ScenarioLibrary.list_templates
puts templates
# => ["loan_approval_high_risk", "loan_approval_low_risk", ...]
```

### Using Templates

```ruby
# Get a template
template = DecisionAgent::Simulation::ScenarioLibrary.get_template(:loan_approval_high_risk)

# Create scenario from template
scenario = DecisionAgent::Simulation::ScenarioLibrary.create_scenario(
  :loan_approval_high_risk,
  overrides: {
    context: { amount: 200_000 }  # Override specific values
  }
)
```

### Generating Edge Cases

Automatically generate edge case scenarios:

```ruby
base_context = {
  credit_score: 700,
  amount: 100_000,
  name: "John Doe"
}

edge_cases = DecisionAgent::Simulation::ScenarioLibrary.generate_edge_cases(base_context)

edge_cases.each do |scenario|
  puts "#{scenario[:metadata][:field]}: #{scenario[:metadata][:value]}"
end
```

Edge cases include:
- **Nil values** - Test with nil for each field
- **Zero values** - Test with 0 for numeric fields
- **Negative values** - Test with negative for positive numeric fields
- **Large values** - Test with 1000x multiplier for numeric fields
- **Empty strings** - Test with "" for string fields

## Best Practices

### 1. Use Historical Replay for Validation

Before deploying rule changes, replay recent production decisions to validate:

```ruby
# Replay last 30 days of decisions
recent_decisions = load_recent_decisions(days: 30)
results = replay_engine.replay(
  historical_data: recent_decisions,
  rule_version: proposed_version_id,
  compare_with: current_version_id
)

# Only deploy if change rate is acceptable
if results[:change_rate] > 0.1
  puts "Warning: High change rate (#{results[:change_rate]})"
end
```

### 2. Perform Impact Analysis Before Deployment

Always run impact analysis before deploying significant rule changes:

```ruby
impact = impact_analyzer.analyze(
  baseline_version: current_version_id,
  proposed_version: new_version_id,
  test_data: representative_sample
)

# Check risk level
if impact[:risk_level] == "critical"
  puts "CRITICAL: Do not deploy without review"
elsif impact[:risk_level] == "high"
  puts "HIGH RISK: Review carefully before deploying"
end
```

### 3. Use Shadow Testing for Gradual Rollout

Test new rules in shadow mode before full deployment:

```ruby
# Shadow test on production traffic
production_contexts.each do |context|
  result = shadow_engine.test(
    context: context,
    shadow_version: new_version_id
  )
  
  # Log mismatches for analysis
  log_mismatch(result) unless result[:matches]
end

# Analyze shadow test results
summary = shadow_engine.get_summary(new_version_id)
if summary[:match_rate] > 0.95
  puts "Safe to deploy - high match rate"
end
```

### 4. Leverage Sensitivity Analysis

Use sensitivity analysis to understand which inputs matter most:

```ruby
sensitivity = what_if_analyzer.sensitivity_analysis(
  base_scenario: typical_scenario,
  variations: {
    credit_score: (500..800).step(50).to_a,
    amount: [25_000, 50_000, 100_000, 200_000, 500_000]
  }
)

# Focus testing on most sensitive fields
sensitivity[:most_sensitive_fields].each do |field|
  puts "Test edge cases for: #{field}"
end
```

### 5. Use Scenario Library for Consistency

Standardize testing with scenario library templates:

```ruby
# Use templates for consistent testing
test_scenarios = [
  DecisionAgent::Simulation::ScenarioLibrary.create_scenario(:loan_approval_high_risk),
  DecisionAgent::Simulation::ScenarioLibrary.create_scenario(:loan_approval_low_risk),
  DecisionAgent::Simulation::ScenarioLibrary.create_scenario(:loan_approval_medium_risk)
]

results = scenario_engine.execute_batch(scenarios: test_scenarios)
```

### 6. Parallel Execution for Performance

Use parallel execution for large datasets:

```ruby
options = {
  parallel: true,
  thread_count: [CPU.count, 8].min,  # Don't exceed CPU count
  progress_callback: ->(progress) {
    logger.info "Progress: #{progress[:percentage]}%"
  }
}

results = replay_engine.replay(
  historical_data: large_dataset,
  options: options
)
```

## Performance Considerations

- **Historical Replay**: Can handle 10k+ decisions in <5 minutes with parallel execution
- **What-If Analysis**: Supports 100+ scenarios efficiently
- **Impact Analysis**: Optimized for batch processing
- **Shadow Testing**: Zero impact on production (read-only comparison)

## Web UI Integration

All simulation features are available through the DecisionAgent Web UI:

- **Simulation Dashboard** - Navigate to `/simulation` for an overview of all simulation features
- **Historical Replay** - Access at `/simulation/replay` with file upload support (CSV/JSON)
- **What-If Analysis** - Interactive scenario builder at `/simulation/whatif`
- **Impact Analysis** - Version comparison and risk visualization at `/simulation/impact`
- **Shadow Testing** - Production comparison interface at `/simulation/shadow`

The Web UI provides:
- File upload with drag-and-drop support
- Version selection dropdowns (loads from version manager)
- Real-time rule validation
- Interactive scenario and context builders
- Results visualization with metrics, tables, and charts
- Parallel execution configuration
- Progress tracking for long-running operations

## See Also

- [Versioning System](VERSIONING.md) - Rule version management
- [A/B Testing](AB_TESTING.md) - Compare rule versions with statistical analysis
- [Batch Testing](BATCH_TESTING.md) - Batch test execution
- [Web UI Setup](WEB_UI_SETUP.md) - Web UI installation and configuration
- [Examples](../examples/simulation_example.rb) - Complete working examples

