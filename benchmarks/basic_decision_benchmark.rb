#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "decision_agent"
require "benchmark"

# ============================================================================
# Configuration
# ============================================================================
ITERATIONS = 10_000
WARMUP_ITERATIONS = 100

puts "=" * 80
puts "Basic Decision Performance Benchmark"
puts "=" * 80
puts

# ============================================================================
# Setup
# ============================================================================

# Single condition rule
single_condition_rules = {
  version: "1.0",
  ruleset: "single_condition",
  rules: [
    {
      id: "rule1",
      if: { field: "amount", op: "gte", value: 100 },
      then: { decision: "approve", weight: 1.0, reason: "Approved" }
    }
  ]
}

# Multiple conditions (all)
multiple_conditions_rules = {
  version: "1.0",
  ruleset: "multiple_conditions",
  rules: [
    {
      id: "rule1",
      if: {
        all: [
          { field: "amount", op: "gte", value: 100 },
          { field: "user.verified", op: "eq", value: true }
        ]
      },
      then: { decision: "approve", weight: 1.0, reason: "Approved" }
    }
  ]
}

# Single evaluator
single_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: single_condition_rules)
single_agent = DecisionAgent::Agent.new(evaluators: [single_evaluator], validate_evaluations: false)

# Multiple evaluators
evaluator1 = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: single_condition_rules)
evaluator2 = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: multiple_conditions_rules)
multiple_agent = DecisionAgent::Agent.new(evaluators: [evaluator1, evaluator2], validate_evaluations: false)

# Large rule set (100 rules)
large_rules = {
  version: "1.0",
  ruleset: "large_ruleset",
  rules: (1..100).map do |i|
    {
      id: "rule_#{i}",
      if: { field: "value", op: "eq", value: i },
      then: { decision: "match_#{i}", weight: 1.0, reason: "Matched rule #{i}" }
    }
  end
}
large_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: large_rules)
large_agent = DecisionAgent::Agent.new(evaluators: [large_evaluator], validate_evaluations: false)

# Test contexts
single_context = { amount: 150 }
multiple_context = { amount: 150, user: { verified: true } }
large_context = { value: 50 }

# ============================================================================
# Benchmark Helper
# ============================================================================
def run_benchmark(name, agent, context, iterations)
  # Warm-up
  WARMUP_ITERATIONS.times { agent.decide(context: context) }

  # Benchmark
  time = Benchmark.realtime do
    iterations.times do
      agent.decide(context: context)
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
puts "Running benchmarks (#{ITERATIONS} iterations each)..."
puts "-" * 80
puts

results = []

results << run_benchmark("Single condition", single_agent, single_context, ITERATIONS)
results << run_benchmark("Multiple conditions (all)", multiple_agent, multiple_context, ITERATIONS)
results << run_benchmark("Single evaluator", single_agent, single_context, ITERATIONS)
results << run_benchmark("Multiple evaluators", multiple_agent, multiple_context, ITERATIONS)
results << run_benchmark("Large rule set (100 rules)", large_agent, large_context, ITERATIONS)

# ============================================================================
# Display Results
# ============================================================================
puts "=" * 80
puts "RESULTS"
puts "=" * 80
puts format("%-40s %15s %15s", "Test", "Throughput (dec/sec)", "Latency (ms)")
puts "-" * 80

results.each do |result|
  if result[:error]
    puts format("%-40s %15s", result[:name], "ERROR: #{result[:error]}")
  else
    puts format(
      "%-40s %15.2f %15.4f",
      result[:name],
      result[:throughput],
      result[:latency_ms]
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

