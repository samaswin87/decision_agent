# Simulation and What-If Analysis

DecisionAgent provides comprehensive simulation and what-if analysis capabilities to help you test rule changes, predict impact, and validate decisions before deploying to production.

## Table of Contents

- [Overview](#overview)
- [Historical Replay / Backtesting](#historical-replay--backtesting)
- [What-If Analysis](#what-if-analysis)
- [Impact Analysis](#impact-analysis)
- [Shadow Testing](#shadow-testing)
- [Monte Carlo Simulation](#monte-carlo-simulation)
- [Scenario Engine](#scenario-engine)
- [Scenario Library](#scenario-library)
- [Best Practices](#best-practices)

## Overview

The Simulation module provides six main capabilities:

1. **Historical Replay / Backtesting** - Replay historical decisions with different rule versions
2. **What-If Analysis** - Simulate scenarios and perform sensitivity analysis
3. **Impact Analysis** - Quantify the impact of rule changes before deployment
4. **Shadow Testing** - Compare new rules against production without affecting outcomes
5. **Monte Carlo Simulation** - Model probabilistic inputs and understand decision outcome probabilities
6. **Scenario Engine** - Manage and execute test scenarios

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

### Loading from Database

ReplayEngine supports loading historical data from databases using ActiveRecord. This requires the `activerecord` gem to be available.

**Using SQL Query:**

```ruby
# Using default ActiveRecord connection
db_config = {
  database: {
    connection: "default",
    query: "SELECT credit_score, amount, income FROM historical_decisions WHERE created_at > '2025-01-01'"
  }
}

results = replay_engine.replay(historical_data: db_config)
```

**Using Table Name with WHERE Clause:**

```ruby
# Query a specific table with filtering
db_config = {
  database: {
    connection: "default",
    table: "historical_decisions",
    where: { status: "pending", amount: 100_000 }
  }
}

results = replay_engine.replay(historical_data: db_config)
```

**Using Custom Database Connection:**

```ruby
# Connect to a different database
db_config = {
  database: {
    connection: {
      adapter: "postgresql",
      host: "localhost",
      database: "production_db",
      username: "user",
      password: "password",
      port: 5432
    },
    query: "SELECT * FROM decision_logs WHERE date >= CURRENT_DATE - INTERVAL '30 days'"
  }
}

results = replay_engine.replay(historical_data: db_config)
```

**Supported Database Adapters:**

- SQLite (`adapter: "sqlite3"`)
- PostgreSQL (`adapter: "postgresql"`)
- MySQL (`adapter: "mysql2"`)
- Any ActiveRecord-compatible adapter

**Connection Configuration:**

- **Default Connection**: Use `connection: "default"` to use the existing ActiveRecord::Base connection
- **Custom Connection**: Provide a Hash with adapter-specific connection parameters
- **Connection String**: For simple cases, you can pass connection parameters as a Hash

**Notes:**

- Database queries require ActiveRecord to be available (add `activerecord` to your Gemfile)
- JSON columns in database results are automatically parsed when detected
- Common ActiveRecord metadata fields (id, created_at, updated_at) are filtered out unless they contain data
- Large result sets are handled efficiently with streaming support

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

### Decision Boundary Visualization

Visualize how decisions change across parameter spaces to understand decision boundaries and thresholds:

#### 1D Boundary Visualization

Visualize how a single parameter affects decisions:

```ruby
# Visualize decision boundaries for credit_score parameter
boundary_1d = what_if_analyzer.visualize_decision_boundaries(
  base_scenario: { amount: 100_000 },
  parameters: {
    credit_score: { min: 500, max: 800, steps: 100 }
  }
)

puts "Parameter: #{boundary_1d[:parameter]}"
puts "Boundaries found: #{boundary_1d[:boundaries].size}"
boundary_1d[:boundaries].each do |boundary|
  puts "  Boundary at #{boundary[:value].round(2)}: #{boundary[:decision_from]} -> #{boundary[:decision_to]}"
end
```

#### 2D Boundary Visualization

Visualize how two parameters interact to affect decisions:

```ruby
# Visualize decision boundaries for credit_score vs amount
boundary_2d = what_if_analyzer.visualize_decision_boundaries(
  base_scenario: {},
  parameters: {
    credit_score: { min: 500, max: 800 },
    amount: { min: 50_000, max: 200_000 }
  },
  options: { resolution: 30 }
)

puts "Parameters: #{boundary_2d[:parameter1]} vs #{boundary_2d[:parameter2]}"
puts "Resolution: #{boundary_2d[:resolution]}x#{boundary_2d[:resolution]}"
puts "Boundaries found: #{boundary_2d[:boundaries].size}"
puts "Decision distribution: #{boundary_2d[:decision_distribution]}"
```

#### HTML Visualization Output

Generate interactive HTML visualizations:

```ruby
# Generate HTML visualization
html_output = what_if_analyzer.visualize_decision_boundaries(
  base_scenario: { amount: 100_000 },
  parameters: {
    credit_score: { min: 500, max: 800, steps: 100 }
  },
  options: { output_format: 'html' }
)

# Save to file
File.write('decision_boundary.html', html_output)
```

The HTML output includes:
- Color-coded decision regions
- Boundary lines showing where decisions change
- Interactive legend
- Statistical summary (boundaries found, decision distribution)

#### JSON Output

Get structured data for custom visualization:

```ruby
json_output = what_if_analyzer.visualize_decision_boundaries(
  base_scenario: { amount: 100_000 },
  parameters: {
    credit_score: { min: 500, max: 800, steps: 100 }
  },
  options: { output_format: 'json' }
)

# Parse and use in your own visualization tools
data = JSON.parse(json_output)
```

#### Configuration Options

- `output_format`: `'data'` (default), `'html'`, or `'json'`
- `resolution`: Number of steps for grid generation (default: 100 for 1D, 30 for 2D)
- `rule_version`: Optional rule version to use for visualization

#### Use Cases

- **Identify decision thresholds**: Find exact parameter values where decisions change
- **Understand parameter interactions**: See how two parameters work together
- **Validate rule logic**: Visually verify that decision boundaries match expectations
- **Communicate rules**: Share visual representations with stakeholders
- **Debug rule issues**: Identify unexpected decision boundaries or gaps

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
- **Performance Impact** - Latency, throughput, and rule complexity metrics
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
results[:performance_impact]                # Performance metrics (see below)
results[:risk_score]                        # Risk score (0.0-1.0)
results[:risk_level]                        # "low", "medium", "high", or "critical"
```

### Performance Impact Estimation

The impact analyzer automatically measures and reports performance differences between baseline and proposed rule versions:

```ruby
results = impact_analyzer.analyze(
  baseline_version: baseline_version_id,
  proposed_version: proposed_version_id,
  test_data: test_contexts
)

perf = results[:performance_impact]

# Latency metrics
puts "Baseline avg latency: #{perf[:latency][:baseline][:average_ms]}ms"
puts "Proposed avg latency: #{perf[:latency][:proposed][:average_ms]}ms"
puts "Latency delta: #{perf[:latency][:delta_ms]}ms (#{perf[:latency][:delta_percent]}%)"

# Throughput metrics
puts "Baseline throughput: #{perf[:throughput][:baseline_decisions_per_second]} decisions/sec"
puts "Proposed throughput: #{perf[:throughput][:proposed_decisions_per_second]} decisions/sec"
puts "Throughput delta: #{perf[:throughput][:delta_percent]}%"

# Rule complexity
puts "Baseline avg evaluations: #{perf[:rule_complexity][:baseline_avg_evaluations]}"
puts "Proposed avg evaluations: #{perf[:rule_complexity][:proposed_avg_evaluations]}"
puts "Evaluations delta: #{perf[:rule_complexity][:evaluations_delta]}"

# Impact summary
puts "Impact level: #{perf[:impact_level]}"  # improvement, neutral, minor_degradation, etc.
puts "Summary: #{perf[:summary]}"
```

#### Performance Impact Metrics

The performance impact report includes:

**Latency Metrics:**
- `baseline.average_ms` - Average decision latency for baseline version
- `baseline.min_ms` - Minimum latency observed
- `baseline.max_ms` - Maximum latency observed
- `proposed.average_ms` - Average decision latency for proposed version
- `proposed.min_ms` - Minimum latency observed
- `proposed.max_ms` - Maximum latency observed
- `delta_ms` - Absolute latency difference (proposed - baseline)
- `delta_percent` - Percentage change in latency

**Throughput Metrics:**
- `baseline_decisions_per_second` - Estimated throughput for baseline
- `proposed_decisions_per_second` - Estimated throughput for proposed
- `delta_percent` - Percentage change in throughput

**Rule Complexity Metrics:**
- `baseline_avg_evaluations` - Average number of rule evaluations per decision (baseline)
- `proposed_avg_evaluations` - Average number of rule evaluations per decision (proposed)
- `evaluations_delta` - Change in average evaluations

**Impact Level:**
- `improvement` - Performance improved by >5%
- `neutral` - Performance change <5%
- `minor_degradation` - Performance degraded by 5-15%
- `moderate_degradation` - Performance degraded by 15-30%
- `significant_degradation` - Performance degraded by >30%

**Summary:**
- Human-readable summary of performance changes

#### Use Cases

Performance impact estimation helps you:

- **Identify performance regressions** before deploying rule changes
- **Optimize rule complexity** by comparing evaluation counts
- **Plan capacity** by understanding throughput changes
- **Set performance budgets** for rule changes
- **Communicate impact** to stakeholders with clear metrics

#### Example Output

```ruby
{
  latency: {
    baseline: { average_ms: 0.125, min_ms: 0.098, max_ms: 0.234 },
    proposed: { average_ms: 0.142, min_ms: 0.105, max_ms: 0.267 },
    delta_ms: 0.017,
    delta_percent: 13.6
  },
  throughput: {
    baseline_decisions_per_second: 8000.0,
    proposed_decisions_per_second: 7042.25,
    delta_percent: -11.97
  },
  rule_complexity: {
    baseline_avg_evaluations: 1.2,
    proposed_avg_evaluations: 1.8,
    evaluations_delta: 0.6
  },
  impact_level: "minor_degradation",
  summary: "Average latency is 13.6% slower. Throughput is 11.97% lower. Average 0.6 more rule evaluations per decision."
}
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

## Monte Carlo Simulation

Model input variables with probability distributions and run thousands of simulations to understand decision outcome probabilities. This is particularly useful for risk assessment, uncertainty quantification, and understanding how variability in inputs affects decision outcomes.

### Basic Usage

```ruby
monte_carlo = DecisionAgent::Simulation::MonteCarloSimulator.new(
  agent: agent,
  version_manager: version_manager
)

# Define probabilistic input distributions
distributions = {
  credit_score: { type: :normal, mean: 650, stddev: 50 },
  amount: { type: :uniform, min: 50_000, max: 200_000 }
}

# Run Monte Carlo simulation
results = monte_carlo.simulate(
  distributions: distributions,
  iterations: 10_000,
  base_context: { name: "Monte Carlo Test" },
  options: { seed: 42 } # Use seed for reproducibility
)

puts "Decision probabilities:"
results[:decision_probabilities].each do |decision, prob|
  puts "  #{decision}: #{(prob * 100).round(2)}%"
end
puts "Average confidence: #{results[:average_confidence].round(4)}"
puts "Confidence interval (95%): [#{results[:confidence_intervals][:confidence][:lower].round(4)}, #{results[:confidence_intervals][:confidence][:upper].round(4)}]"
```

### Supported Probability Distributions

MonteCarloSimulator supports six types of probability distributions:

#### 1. Normal Distribution

For values that follow a bell curve (e.g., credit scores, test scores):

```ruby
distributions = {
  credit_score: { type: :normal, mean: 650, stddev: 50 }
}
```

#### 2. Uniform Distribution

For values that are equally likely across a range (e.g., random selection):

```ruby
distributions = {
  amount: { type: :uniform, min: 50_000, max: 200_000 }
}
```

#### 3. Log-Normal Distribution

For values that are always positive and have a long tail (e.g., income, prices):

```ruby
distributions = {
  income: { type: :lognormal, mean: 10.0, stddev: 0.5 }
}
```

#### 4. Exponential Distribution

For time-to-event or waiting times (e.g., time between events):

```ruby
distributions = {
  time_to_event: { type: :exponential, lambda: 0.1 }
}
```

#### 5. Discrete Distribution

For categorical or discrete values with known probabilities:

```ruby
distributions = {
  risk_level: {
    type: :discrete,
    values: ["low", "medium", "high"],
    probabilities: [0.6, 0.3, 0.1]
  }
}
```

**Note:** Probabilities must sum to 1.0.

#### 6. Triangular Distribution

For values with a most likely value (mode) and bounds (e.g., expert estimates):

```ruby
distributions = {
  estimate: { type: :triangular, min: 100, mode: 150, max: 200 }
}
```

### Statistical Analysis

The simulation results include comprehensive statistics:

```ruby
results = monte_carlo.simulate(
  distributions: distributions,
  iterations: 10_000
)

# Decision probabilities
results[:decision_probabilities]
# => { "approve" => 0.65, "reject" => 0.35 }

# Decision-specific statistics
results[:decision_stats].each do |decision, stats|
  puts "#{decision}:"
  puts "  Count: #{stats[:count]}"
  puts "  Probability: #{(stats[:probability] * 100).round(2)}%"
  puts "  Average confidence: #{stats[:average_confidence].round(4)}"
  puts "  Confidence stddev: #{stats[:confidence_stddev].round(4)}"
end

# Overall statistics
puts "Average confidence: #{results[:average_confidence].round(4)}"
puts "Confidence stddev: #{results[:confidence_stddev].round(4)}"
puts "Confidence interval (95%): #{results[:confidence_intervals][:confidence]}"
```

### Sensitivity Analysis

Analyze how changes to distribution parameters affect decision outcomes:

```ruby
sensitivity_results = monte_carlo.sensitivity_analysis(
  base_distributions: {
    credit_score: { type: :normal, mean: 650, stddev: 50 }
  },
  sensitivity_params: {
    credit_score: {
      mean: [600, 650, 700],
      stddev: [40, 50, 60]
    }
  },
  iterations: 5_000,
  base_context: { name: "Sensitivity Test" }
)

sensitivity_results[:sensitivity_results][:credit_score].each do |param_name, param_data|
  puts "Parameter: #{param_name}"
  puts "  Values tested: #{param_data[:values_tested]}"
  puts "  Impact analysis:"
  param_data[:impact_analysis].each do |decision, impact|
    puts "    #{decision}:"
    puts "      Min probability: #{(impact[:min_probability] * 100).round(2)}%"
    puts "      Max probability: #{(impact[:max_probability] * 100).round(2)}%"
    puts "      Range: #{(impact[:range] * 100).round(2)}%"
    puts "      Sensitivity: #{impact[:sensitivity]}" # "low", "medium", or "high"
  end
end
```

### Multiple Distributions

You can model multiple probabilistic inputs simultaneously:

```ruby
distributions = {
  credit_score: { type: :normal, mean: 650, stddev: 50 },
  amount: { type: :uniform, min: 50_000, max: 200_000 },
  income: { type: :lognormal, mean: 10.0, stddev: 0.5 }
}

results = monte_carlo.simulate(
  distributions: distributions,
  iterations: 10_000,
  base_context: { name: "Multi-variate Test" }
)
```

### Nested Field Support

Monte Carlo simulation supports nested field paths:

```ruby
distributions = {
  "user.credit_score" => { type: :normal, mean: 650, stddev: 50 }
}

results = monte_carlo.simulate(
  distributions: distributions,
  iterations: 1_000,
  base_context: { user: { name: "Test User" } }
)

# Contexts will have nested structure
sample_context = results[:results].first[:context]
# => { user: { name: "Test User", credit_score: 642.3 } }
```

### Parallel Execution

For large simulations, enable parallel execution:

```ruby
results = monte_carlo.simulate(
  distributions: distributions,
  iterations: 100_000,
  options: {
    parallel: true,
    thread_count: 4,
    seed: 42  # Seed is applied before parallel execution
  }
)
```

**Note:** When using parallel execution with a seed, each thread will have different random states, but the overall distribution will be consistent across runs.

### Reproducibility

Use seeds for reproducible results:

```ruby
# Same seed produces same results
results1 = monte_carlo.simulate(
  distributions: distributions,
  iterations: 1_000,
  options: { seed: 12345, parallel: false }
)

results2 = monte_carlo.simulate(
  distributions: distributions,
  iterations: 1_000,
  options: { seed: 12345, parallel: false }
)

# Decision probabilities should match
results1[:decision_probabilities] == results2[:decision_probabilities]
```

### Use Cases

Monte Carlo simulation is particularly useful for:

1. **Risk Assessment** - Understand the probability of different decision outcomes under uncertainty
2. **Sensitivity Analysis** - Identify which input parameters have the most impact on decisions
3. **Confidence Intervals** - Estimate confidence score ranges for decision outcomes
4. **Scenario Planning** - Model different business scenarios with probabilistic inputs
5. **Validation** - Validate decision rules against expected probability distributions

### Example: Loan Approval Risk Analysis

```ruby
# Model credit score uncertainty
distributions = {
  credit_score: { type: :normal, mean: 650, stddev: 50 },
  debt_to_income: { type: :normal, mean: 0.35, stddev: 0.1 },
  loan_amount: { type: :uniform, min: 50_000, max: 500_000 }
}

results = monte_carlo.simulate(
  distributions: distributions,
  iterations: 50_000,
  base_context: { applicant_name: "Risk Analysis" }
)

# Analyze approval probability
approval_prob = results[:decision_probabilities]["approve"] || 0.0
puts "Approval probability: #{(approval_prob * 100).round(2)}%"

# Analyze confidence in approvals
if results[:decision_stats]["approve"]
  approval_stats = results[:decision_stats]["approve"]
  puts "Average confidence for approvals: #{approval_stats[:average_confidence].round(4)}"
  puts "Confidence stddev: #{approval_stats[:confidence_stddev].round(4)}"
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
# Replay last 30 days of decisions from database
db_config = {
  database: {
    connection: "default",
    query: "SELECT * FROM decision_logs WHERE created_at >= DATE('now', '-30 days')"
  }
}

results = replay_engine.replay(
  historical_data: db_config,
  rule_version: proposed_version_id,
  compare_with: current_version_id
)

# Only deploy if change rate is acceptable
if results[:change_rate] > 0.1
  puts "Warning: High change rate (#{results[:change_rate]})"
end
```

**Data Source Options:**

- **Database queries** - Best for production data stored in databases
- **CSV/JSON files** - Good for exported data or test datasets
- **Array of contexts** - Useful for programmatically generated test data

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
- **Monte Carlo Simulation**: Can run 100k+ iterations efficiently with parallel execution

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

