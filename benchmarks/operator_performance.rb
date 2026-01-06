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
puts "Operator Performance Benchmark"
puts "=" * 80
puts

# ============================================================================
# Setup - Different Operator Types
# ============================================================================

# Basic operators
basic_rules = {
  version: "1.0",
  ruleset: "basic_operators",
  rules: [
    {
      id: "basic_rule",
      if: {
        all: [
          { field: "amount", op: "gt", value: 1000 },
          { field: "user.verified", op: "eq", value: true },
          { field: "risk_score", op: "lt", value: 0.3 }
        ]
      },
      then: { decision: "approve", weight: 0.9 }
    }
  ]
}

# String operators
string_rules = {
  version: "1.0",
  ruleset: "string_operators",
  rules: [
    {
      id: "string_rule",
      if: {
        all: [
          { field: "email", op: "ends_with", value: "@company.com" },
          { field: "message", op: "contains", value: "urgent" },
          { field: "code", op: "starts_with", value: "ERR" },
          { field: "email", op: "matches", value: "^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$" }
        ]
      },
      then: { decision: "approve", weight: 0.9 }
    }
  ]
}

# Numeric operators
numeric_rules = {
  version: "1.0",
  ruleset: "numeric_operators",
  rules: [
    {
      id: "numeric_rule",
      if: {
        all: [
          { field: "age", op: "between", value: [18, 65] },
          { field: "user_id", op: "modulo", value: [2, 0] },
          { field: "angle", op: "sin", value: 0.0 },
          { field: "number", op: "sqrt", value: 3.0 },
          { field: "value", op: "abs", value: 5 }
        ]
      },
      then: { decision: "approve", weight: 0.9 }
    }
  ]
}

# Date operators
date_rules = {
  version: "1.0",
  ruleset: "date_operators",
  rules: [
    {
      id: "date_rule",
      if: {
        all: [
          { field: "created_at", op: "after_date", value: "2024-01-01" },
          { field: "expires_at", op: "before_date", value: "2026-12-31" },
          { field: "event_date", op: "within_days", value: 30 }
        ]
      },
      then: { decision: "approve", weight: 0.9 }
    }
  ]
}

# Geospatial operators
geospatial_rules = {
  version: "1.0",
  ruleset: "geospatial_operators",
  rules: [
    {
      id: "geospatial_rule",
      if: {
        field: "location",
        op: "within_radius",
        value: { center: { lat: 40.7128, lon: -74.0060 }, radius: 10 }
      },
      then: { decision: "approve", weight: 0.9 }
    }
  ]
}

# Collection operators
collection_rules = {
  version: "1.0",
  ruleset: "collection_operators",
  rules: [
    {
      id: "collection_rule",
      if: {
        all: [
          { field: "permissions", op: "contains_all", value: %w[read write] },
          { field: "tags", op: "contains_any", value: %w[urgent critical] },
          { field: "numbers", op: "sum", value: { gte: 100 } },
          { field: "scores", op: "average", value: { gte: 50 } }
        ]
      },
      then: { decision: "approve", weight: 0.9 }
    }
  ]
}

# Create evaluators and agents
basic_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: basic_rules)
string_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: string_rules)
numeric_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: numeric_rules)
date_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: date_rules)
geospatial_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: geospatial_rules)
collection_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: collection_rules)

basic_agent = DecisionAgent::Agent.new(evaluators: [basic_evaluator], validate_evaluations: false)
string_agent = DecisionAgent::Agent.new(evaluators: [string_evaluator], validate_evaluations: false)
numeric_agent = DecisionAgent::Agent.new(evaluators: [numeric_evaluator], validate_evaluations: false)
date_agent = DecisionAgent::Agent.new(evaluators: [date_evaluator], validate_evaluations: false)
geospatial_agent = DecisionAgent::Agent.new(evaluators: [geospatial_evaluator], validate_evaluations: false)
collection_agent = DecisionAgent::Agent.new(evaluators: [collection_evaluator], validate_evaluations: false)

# Test contexts
basic_context = { amount: 1500, user: { verified: true }, risk_score: 0.2 }
string_context = {
  email: "user@company.com",
  message: "This is an urgent request",
  code: "ERR_404"
}
numeric_context = {
  age: 30,
  user_id: 10,
  angle: 0,
  number: 9,
  value: -5
}
date_context = {
  created_at: "2025-06-01",
  expires_at: "2025-12-31",
  event_date: (Time.now + (3 * 24 * 60 * 60)).strftime("%Y-%m-%d")
}
geospatial_context = {
  location: { lat: 40.7200, lon: -74.0000 }
}
collection_context = {
  permissions: %w[read write execute],
  tags: %w[urgent normal],
  numbers: [20, 30, 50],
  scores: [40, 50, 60]
}

# ============================================================================
# Benchmark Helper
# ============================================================================
def benchmark_operator(name, agent, context, iterations)
  # Verify context matches rules first
  begin
    test_decision = agent.decide(context: context)
    if test_decision.nil? || test_decision.evaluations.empty?
      return {
        name: name,
        iterations: iterations,
        time_ms: 0,
        throughput: 0,
        latency_ms: 0,
        error: "Context mismatch"
      }
    end
  rescue StandardError => e
    return {
      name: name,
      iterations: iterations,
      time_ms: 0,
      throughput: 0,
      latency_ms: 0,
      error: e.message
    }
  end

  # Warm-up
  WARMUP_ITERATIONS.times { agent.decide(context: context) }

  # Benchmark
  time = Benchmark.realtime do
    iterations.times do
      agent.decide(context: context)
    end
  end

  throughput = (iterations / time).round(2)
  latency = ((time / iterations) * 1000).round(4)

  {
    name: name,
    iterations: iterations,
    time_ms: (time * 1000).round(2),
    throughput: throughput,
    latency_ms: latency
  }
end

# ============================================================================
# Run Benchmarks
# ============================================================================
puts "Running performance benchmarks (#{ITERATIONS} iterations each)..."
puts "-" * 80
puts

results = []

results << benchmark_operator("Basic Operators (gt, eq, lt)", basic_agent, basic_context, ITERATIONS)
results << benchmark_operator("String Operators (matches, contains, etc.)", string_agent, string_context, ITERATIONS)
results << benchmark_operator("Numeric Operators (between, modulo, sin, sqrt, abs)", numeric_agent, numeric_context, ITERATIONS)
results << benchmark_operator("Date Operators (after_date, before_date, within_days)", date_agent, date_context, ITERATIONS)
results << benchmark_operator("Geospatial Operators (within_radius)", geospatial_agent, geospatial_context, ITERATIONS)
results << benchmark_operator("Collection Operators (contains_all, contains_any, sum, average)", collection_agent, collection_context, ITERATIONS)

# ============================================================================
# Display Results
# ============================================================================
puts "=" * 80
puts "RESULTS"
puts "=" * 80
puts "Operator Type                                      Throughput (dec/sec)    Latency (ms)"
puts "-" * 80

baseline_throughput = results[0][:throughput]

results.each do |result|
  if result[:error]
    puts format("%-50s %15s", result[:name], "ERROR: #{result[:error]}")
  else
    overhead = ((baseline_throughput - result[:throughput]) / baseline_throughput * 100).round(2)
    overhead_str = overhead.positive? ? "(-#{overhead}%)" : "(+#{overhead.abs}%)"

    puts format(
      "%-50s %15.2f %15.4f %s",
      result[:name],
      result[:throughput],
      result[:latency_ms],
      overhead_str
    )
  end
end

puts "=" * 80
puts
puts "Summary:"
puts "  • Baseline: Basic operators"
puts "  • Iterations per test: #{ITERATIONS}"
puts "  • Warm-up iterations: #{WARMUP_ITERATIONS}"
puts "=" * 80
