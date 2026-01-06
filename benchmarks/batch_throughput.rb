#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "decision_agent"
require "benchmark"

# ============================================================================
# Configuration
# ============================================================================
ITERATIONS = 50_000
WARMUP_ITERATIONS = 100

puts "=" * 80
puts "Real-World Scenarios Benchmark"
puts "=" * 80
puts

# ============================================================================
# Setup - Real-World Scenarios
# ============================================================================

# Scenario 1: Simple loan approval
simple_loan_rules = {
  version: "1.0",
  ruleset: "simple_loan",
  rules: [
    {
      id: "approve",
      if: {
        all: [
          { field: "credit_score", op: "gte", value: 700 },
          { field: "income", op: "gte", value: 50_000 }
        ]
      },
      then: { decision: "approved", weight: 1.0, reason: "Meets criteria" }
    },
    {
      id: "reject",
      if: { field: "credit_score", op: "lt", value: 600 },
      then: { decision: "rejected", weight: 1.0, reason: "Low credit score" }
    }
  ]
}

# Scenario 2: Complex loan approval (multiple conditions, nested data)
complex_loan_rules = {
  version: "1.0",
  ruleset: "complex_loan",
  rules: [
    {
      id: "high_approve",
      if: {
        all: [
          { field: "credit_score", op: "gte", value: 750 },
          { field: "income", op: "gte", value: 100_000 },
          { field: "debt_to_income", op: "lt", value: 0.3 },
          { field: "employment_years", op: "gte", value: 2 }
        ]
      },
      then: { decision: "approved", weight: 0.95, reason: "Excellent profile" }
    },
    {
      id: "medium_approve",
      if: {
        all: [
          { field: "credit_score", op: "gte", value: 650 },
          { field: "income", op: "gte", value: 60_000 },
          { field: "debt_to_income", op: "lt", value: 0.4 }
        ]
      },
      then: { decision: "approved", weight: 0.8, reason: "Good profile" }
    },
    {
      id: "review",
      if: {
        all: [
          { field: "credit_score", op: "gte", value: 600 },
          { field: "credit_score", op: "lt", value: 650 }
        ]
      },
      then: { decision: "review", weight: 0.6, reason: "Needs review" }
    },
    {
      id: "reject",
      if: { field: "credit_score", op: "lt", value: 600 },
      then: { decision: "rejected", weight: 1.0, reason: "Low credit score" }
    }
  ]
}

# Scenario 3: Fraud detection
fraud_rules = {
  version: "1.0",
  ruleset: "fraud_detection",
  rules: [
    {
      id: "high_risk",
      if: {
        all: [
          { field: "transaction_amount", op: "gt", value: 10_000 },
          { field: "user.account_age_days", op: "lt", value: 30 },
          { field: "location.distance_from_home", op: "gt", value: 1000 }
        ]
      },
      then: { decision: "flag", weight: 0.9, reason: "High risk transaction" }
    },
    {
      id: "medium_risk",
      if: {
        all: [
          { field: "transaction_amount", op: "gt", value: 5_000 },
          { field: "velocity.24h_transactions", op: "gt", value: 10 }
        ]
      },
      then: { decision: "review", weight: 0.7, reason: "Medium risk" }
    },
    {
      id: "low_risk",
      if: {
        all: [
          { field: "transaction_amount", op: "lte", value: 1_000 },
          { field: "user.verified", op: "eq", value: true }
        ]
      },
      then: { decision: "approve", weight: 0.95, reason: "Low risk" }
    }
  ]
}

# Scenario 4: Large rule set (200 rules)
large_rules = {
  version: "1.0",
  ruleset: "large_ruleset",
  rules: (1..200).map do |i|
    {
      id: "rule_#{i}",
      if: { field: "category", op: "eq", value: "cat_#{i % 20}" },
      then: { decision: "action_#{i % 10}", weight: 1.0, reason: "Rule #{i}" }
    }
  end
}

# Create evaluators and agents
simple_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: simple_loan_rules)
complex_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: complex_loan_rules)
fraud_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: fraud_rules)
large_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: large_rules)

simple_agent = DecisionAgent::Agent.new(evaluators: [simple_evaluator], validate_evaluations: false)
complex_agent = DecisionAgent::Agent.new(evaluators: [complex_evaluator], validate_evaluations: false)
fraud_agent = DecisionAgent::Agent.new(evaluators: [fraud_evaluator], validate_evaluations: false)
large_agent = DecisionAgent::Agent.new(evaluators: [large_evaluator], validate_evaluations: false)

# Test contexts
simple_contexts = [
  { credit_score: 750, income: 75_000 },
  { credit_score: 550, income: 40_000 },
  { credit_score: 680, income: 60_000 }
]

complex_contexts = [
  { credit_score: 780, income: 120_000, debt_to_income: 0.25, employment_years: 5 },
  { credit_score: 680, income: 70_000, debt_to_income: 0.35, employment_years: 3 },
  { credit_score: 620, income: 50_000, debt_to_income: 0.45, employment_years: 1 },
  { credit_score: 550, income: 40_000, debt_to_income: 0.5, employment_years: 0 }
]

fraud_contexts = [
  { transaction_amount: 12_000, user: { account_age_days: 15 }, location: { distance_from_home: 1500 } },
  { transaction_amount: 6_000, velocity: { "24h_transactions": 15 } },
  { transaction_amount: 500, user: { verified: true } }
]

large_contexts = (1..20).map { |i| { category: "cat_#{i}" } }

# ============================================================================
# Benchmark Helper
# ============================================================================
def run_benchmark(name, agent, contexts, iterations)
  # Warm-up
  WARMUP_ITERATIONS.times do |i|
    ctx = contexts[i % contexts.size]
    agent.decide(context: ctx)
  end

  # Benchmark
  time = Benchmark.realtime do
    iterations.times do |i|
      ctx = contexts[i % contexts.size]
      agent.decide(context: ctx)
    end
  end

  throughput = iterations / time
  latency = (time / iterations) * 1000

  {
    name: name,
    throughput: throughput,
    latency_ms: latency,
    time_ms: time * 1000
  }
rescue => e
  {
    name: name,
    throughput: 0,
    latency_ms: 0,
    time_ms: 0,
    error: e.message
  }
end

# ============================================================================
# Run Benchmarks
# ============================================================================
puts "Running real-world scenario benchmarks (#{ITERATIONS} iterations each)..."
puts "-" * 80
puts

results = []

results << run_benchmark("Loan approval (simple)", simple_agent, simple_contexts, ITERATIONS)
results << run_benchmark("Loan approval (complex)", complex_agent, complex_contexts, ITERATIONS)
results << run_benchmark("Fraud detection", fraud_agent, fraud_contexts, ITERATIONS)
results << run_benchmark("Large rule set (200 rules)", large_agent, large_contexts, ITERATIONS)

# ============================================================================
# Display Results
# ============================================================================
puts "=" * 80
puts "RESULTS"
puts "=" * 80
puts format("%-40s %15s %15s %15s", "Scenario", "Throughput (dec/sec)", "Latency (ms)", "Time (ms)")
puts "-" * 80

results.each do |result|
  if result[:error]
    puts format("%-40s %15s", result[:name], "ERROR: #{result[:error]}")
  else
    puts format(
      "%-40s %15.2f %15.4f %15.2f",
      result[:name],
      result[:throughput],
      result[:latency_ms],
      result[:time_ms]
    )
  end
end

puts "=" * 80
puts
puts "Summary:"
puts "  • Iterations per test: #{ITERATIONS}"
puts "  • Warm-up iterations: #{WARMUP_ITERATIONS}"
puts "  • Validation: Disabled (maximum performance)"
puts "=" * 80

