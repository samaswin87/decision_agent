#!/usr/bin/env ruby
# frozen_string_literal: true

# Simulation and What-If Analysis Examples
# Demonstrates historical replay, what-if analysis, impact analysis, and shadow testing

require_relative "../lib/decision_agent"

# ========================================
# Setup: Create a sample agent with rules
# ========================================

evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(
  rules_json: {
    version: "1.0",
    ruleset: "loan_approval",
    rules: [
      {
        id: "high_risk",
        if: { field: "credit_score", op: "lt", value: 600 },
        then: { decision: "reject", weight: 0.9, reason: "Low credit score" }
      },
      {
        id: "medium_risk",
        if: { field: "credit_score", op: "between", value: [600, 700] },
        then: { decision: "approve", weight: 0.7, reason: "Medium credit score" }
      },
      {
        id: "low_risk",
        if: { field: "credit_score", op: "gte", value: 700 },
        then: { decision: "approve", weight: 0.9, reason: "High credit score" }
      }
    ]
  }
)

agent = DecisionAgent::Agent.new(evaluators: [evaluator])
version_manager = DecisionAgent::Versioning::VersionManager.new

# Save initial version
initial_version = version_manager.save_version(
  rule_id: "loan_approval",
  rule_content: {
    version: "1.0",
    ruleset: "loan_approval",
    rules: [
      {
        id: "high_risk",
        if: { field: "credit_score", op: "lt", value: 600 },
        then: { decision: "reject", weight: 0.9, reason: "Low credit score" }
      },
      {
        id: "medium_risk",
        if: { field: "credit_score", op: "between", value: [600, 700] },
        then: { decision: "approve", weight: 0.7, reason: "Medium credit score" }
      },
      {
        id: "low_risk",
        if: { field: "credit_score", op: "gte", value: 700 },
        then: { decision: "approve", weight: 0.9, reason: "High credit score" }
      }
    ]
  },
  created_by: "example_user"
)

puts "=" * 80
puts "Simulation and What-If Analysis Examples"
puts "=" * 80
puts

# ========================================
# Example 1: Historical Replay / Backtesting
# ========================================

puts "Example 1: Historical Replay / Backtesting"
puts "-" * 80

replay_engine = DecisionAgent::Simulation::ReplayEngine.new(
  agent: agent,
  version_manager: version_manager
)

# Create historical data
historical_data = [
  { credit_score: 550, amount: 50_000 },
  { credit_score: 650, amount: 75_000 },
  { credit_score: 750, amount: 100_000 },
  { credit_score: 580, amount: 30_000 },
  { credit_score: 720, amount: 150_000 }
]

# Replay with current rules
replay_results = replay_engine.replay(historical_data: historical_data)

puts "Total decisions replayed: #{replay_results[:total_decisions]}"
puts "Decision distribution: #{replay_results[:decision_distribution]}"
puts

# Create a new version with stricter rules
stricter_version = version_manager.save_version(
  rule_id: "loan_approval",
  rule_content: {
    version: "1.0",
    ruleset: "loan_approval",
    rules: [
      {
        id: "high_risk",
        if: { field: "credit_score", op: "lt", value: 650 },
        then: { decision: "reject", weight: 0.9, reason: "Low credit score" }
      },
      {
        id: "low_risk",
        if: { field: "credit_score", op: "gte", value: 650 },
        then: { decision: "approve", weight: 0.9, reason: "High credit score" }
      }
    ]
  },
  created_by: "example_user",
  changelog: "Stricter approval threshold - require 650+ credit score"
)

# Backtest the new version
backtest_results = replay_engine.backtest(
  historical_data: historical_data,
  proposed_version: stricter_version[:id],
  baseline_version: initial_version[:id]
)

puts "Backtest Results:"
puts "  Changed decisions: #{backtest_results[:changed_decisions]}"
puts "  Change rate: #{(backtest_results[:change_rate] * 100).round(2)}%"
puts "  Average confidence delta: #{backtest_results[:average_confidence_delta].round(4)}"
puts

# ========================================
# Example 2: What-If Analysis
# ========================================

puts "Example 2: What-If Analysis"
puts "-" * 80

what_if_analyzer = DecisionAgent::Simulation::WhatIfAnalyzer.new(
  agent: agent,
  version_manager: version_manager
)

# Define scenarios to test
scenarios = [
  { credit_score: 550, amount: 50_000 },
  { credit_score: 600, amount: 75_000 },
  { credit_score: 650, amount: 100_000 },
  { credit_score: 700, amount: 150_000 },
  { credit_score: 750, amount: 200_000 }
]

# Analyze scenarios
what_if_results = what_if_analyzer.analyze(scenarios: scenarios)

puts "What-If Analysis Results:"
puts "  Total scenarios: #{what_if_results[:total_scenarios]}"
puts "  Decision distribution: #{what_if_results[:decision_distribution]}"
puts "  Average confidence: #{what_if_results[:average_confidence].round(4)}"
puts

# Sensitivity analysis
puts "Sensitivity Analysis:"
sensitivity_results = what_if_analyzer.sensitivity_analysis(
  base_scenario: { credit_score: 650, amount: 100_000 },
  variations: {
    credit_score: [550, 600, 650, 700, 750],
    amount: [50_000, 75_000, 100_000, 150_000, 200_000]
  }
)

puts "  Base decision: #{sensitivity_results[:base_decision]}"
puts "  Most sensitive fields: #{sensitivity_results[:most_sensitive_fields].join(', ')}"
sensitivity_results[:field_sensitivity].each do |field, data|
  puts "  #{field}: impact=#{data[:impact].round(4)}"
end
puts

# ========================================
# Example 3: Impact Analysis
# ========================================

puts "Example 3: Impact Analysis"
puts "-" * 80

impact_analyzer = DecisionAgent::Simulation::ImpactAnalyzer.new(
  version_manager: version_manager
)

# Analyze impact of the stricter version
impact_results = impact_analyzer.analyze(
  baseline_version: initial_version[:id],
  proposed_version: stricter_version[:id],
  test_data: historical_data
)

puts "Impact Analysis Results:"
puts "  Total contexts tested: #{impact_results[:total_contexts]}"
puts "  Decision changes: #{impact_results[:decision_changes]}"
puts "  Change rate: #{(impact_results[:change_rate] * 100).round(2)}%"
puts "  Risk score: #{impact_results[:risk_score].round(4)}"
puts "  Risk level: #{impact_results[:risk_level]}"
puts "  Average confidence delta: #{impact_results[:confidence_impact][:average_delta].round(4)}"
puts

# ========================================
# Example 4: Shadow Testing
# ========================================

puts "Example 4: Shadow Testing"
puts "-" * 80

shadow_engine = DecisionAgent::Simulation::ShadowTestEngine.new(
  production_agent: agent,
  version_manager: version_manager
)

# Test a single context
test_context = { credit_score: 650, amount: 100_000 }
shadow_result = shadow_engine.test(
  context: test_context,
  shadow_version: stricter_version[:id]
)

puts "Shadow Test Result:"
puts "  Production decision: #{shadow_result[:production_decision]}"
puts "  Shadow decision: #{shadow_result[:shadow_decision]}"
puts "  Matches: #{shadow_result[:matches]}"
puts "  Confidence delta: #{shadow_result[:confidence_delta].round(4)}"
puts

# Batch shadow testing
batch_contexts = [
  { credit_score: 550, amount: 50_000 },
  { credit_score: 650, amount: 100_000 },
  { credit_score: 750, amount: 200_000 }
]

batch_results = shadow_engine.batch_test(
  contexts: batch_contexts,
  shadow_version: stricter_version[:id]
)

puts "Batch Shadow Test Results:"
puts "  Total tests: #{batch_results[:total_tests]}"
puts "  Matches: #{batch_results[:matches]}"
puts "  Mismatches: #{batch_results[:mismatches]}"
puts "  Match rate: #{(batch_results[:match_rate] * 100).round(2)}%"
puts

# ========================================
# Example 5: Scenario Engine and Library
# ========================================

puts "Example 5: Scenario Engine and Library"
puts "-" * 80

scenario_engine = DecisionAgent::Simulation::ScenarioEngine.new(
  agent: agent,
  version_manager: version_manager
)

# Use scenario library templates
scenario_library = DecisionAgent::Simulation::ScenarioLibrary

# Get a template
template = scenario_library.get_template(:loan_approval_high_risk)
puts "Template: #{template[:metadata][:description]}"

# Create scenario from template
scenario = scenario_library.create_scenario(
  :loan_approval_high_risk,
  overrides: { context: { credit_score: 550, amount: 100_000 } }
)

# Execute scenario
result = scenario_engine.execute(scenario: scenario)
puts "Scenario result: #{result[:decision]} (confidence: #{result[:confidence].round(4)})"
puts

# Generate edge cases
base_context = { credit_score: 700, amount: 100_000, name: "John Doe" }
edge_cases = scenario_library.generate_edge_cases(base_context)
puts "Generated #{edge_cases.size} edge case scenarios"
puts

# Execute batch scenarios
batch_scenarios = [
  { context: { credit_score: 550, amount: 50_000 } },
  { context: { credit_score: 650, amount: 100_000 } },
  { context: { credit_score: 750, amount: 200_000 } }
]

batch_results = scenario_engine.execute_batch(scenarios: batch_scenarios)
puts "Batch execution:"
puts "  Total scenarios: #{batch_results[:total_scenarios]}"
puts "  Decision distribution: #{batch_results[:decision_distribution]}"
puts "  Average confidence: #{batch_results[:average_confidence].round(4)}"
puts

puts "=" * 80
puts "Examples completed!"
puts "=" * 80

