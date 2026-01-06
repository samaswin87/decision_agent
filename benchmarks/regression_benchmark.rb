#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "fileutils"
require "benchmark"
require "bundler/setup"
require "decision_agent"

# ============================================================================
# Configuration
# ============================================================================
ITERATIONS = 10_000
WARMUP_ITERATIONS = 100

# Detect Ruby version
ruby_version = "#{RUBY_VERSION.split('.')[0]}.#{RUBY_VERSION.split('.')[1]}"
baseline_dir = File.join(__dir__, "baselines")
results_dir = File.join(__dir__, "results")

# Ensure directories exist
FileUtils.mkdir_p(baseline_dir)
FileUtils.mkdir_p(results_dir)

# ============================================================================
# Setup
# ============================================================================
rules = {
  version: "1.0",
  ruleset: "regression_test",
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

evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
agent = DecisionAgent::Agent.new(evaluators: [evaluator], validate_evaluations: false)
test_context = { amount: 150, user: { verified: true } }

# ============================================================================
# Helper Methods
# ============================================================================
def build_change_string(is_latency_metric, overhead, degradation)
  if is_latency_metric
    overhead.positive? ? "improved by #{overhead.abs}%" : "degraded by #{degradation}%"
  elsif overhead.positive?
    "degraded by #{overhead}%"
  else
    "improved by #{overhead.abs}%"
  end
end

# ============================================================================
# Run Benchmarks
# ============================================================================
def run_benchmarks(agent, context, iterations, warmup_iterations)
  # Warm-up
  warmup_iterations.times { agent.decide(context: context) }

  # Single-threaded
  single_time = Benchmark.realtime do
    iterations.times do
      agent.decide(context: context)
    end
  end

  single_throughput = iterations / single_time
  single_latency = (single_time / iterations) * 1000

  # Multi-threaded (50 threads)
  thread_count = 50
  decisions_per_thread = iterations / thread_count
  total_decisions = thread_count * decisions_per_thread

  multi_time = Benchmark.realtime do
    threads = []
    thread_count.times do
      threads << Thread.new do
        decisions_per_thread.times do
          agent.decide(context: context)
        end
      end
    end
    threads.each(&:join)
  end

  multi_throughput = total_decisions / multi_time
  multi_latency = (multi_time / total_decisions) * 1000

  {
    basic_throughput: single_throughput.round(2),
    basic_latency_ms: single_latency.round(4),
    thread_50_throughput: multi_throughput.round(2),
    thread_50_latency_ms: multi_latency.round(4)
  }
end

# ============================================================================
# Load Baseline
# ============================================================================
baseline_file = File.join(baseline_dir, "basic_baseline_#{ruby_version}.json")
baseline = nil

if File.exist?(baseline_file)
  begin
    baseline = JSON.parse(File.read(baseline_file))
    puts "Loaded baseline for Ruby #{ruby_version}"
    puts "  Baseline timestamp: #{baseline['timestamp']}"
    puts "  Baseline commit: #{baseline['git_commit']}"
    puts
  rescue StandardError => e
    puts "⚠️  Error loading baseline: #{e.message}"
    puts
  end
else
  puts "⚠️  No baseline found for Ruby #{ruby_version}"
  puts "  Expected file: #{baseline_file}"
  puts "  Run with --update-baseline to create a baseline"
  puts
end

# ============================================================================
# Run Current Benchmarks
# ============================================================================
puts "Running benchmarks..."
puts "-" * 80

current_results = run_benchmarks(agent, test_context, ITERATIONS, WARMUP_ITERATIONS)

# Get git commit and system info
git_commit = begin
  `git rev-parse HEAD 2>/dev/null`.strip
rescue StandardError
  "unknown"
end

hardware = begin
  `uname -m 2>/dev/null`.strip
rescue StandardError
  "unknown"
end

os = begin
  `uname -s 2>/dev/null`.strip
rescue StandardError
  "unknown"
end

# Build results hash
results = {
  timestamp: Time.now.utc.iso8601,
  ruby_version: RUBY_VERSION,
  ruby_major_minor: ruby_version,
  git_commit: git_commit,
  hardware: hardware,
  os: os,
  results: current_results
}

# ============================================================================
# Compare Against Baseline
# ============================================================================
if baseline && baseline["results"]
  puts "Comparing against baseline..."
  puts "-" * 80
  puts

  baseline_results = baseline["results"]
  all_passed = true
  warnings = []

  baseline_results.each do |key, baseline_value|
    current_value = current_results[key.to_sym]
    next unless current_value

    # For latency metrics (lower is better), calculate degradation differently
    is_latency_metric = key.to_s.end_with?("_latency_ms") || key.to_s.end_with?("_ms")

    # Calculate overhead (same for both metric types)
    overhead = ((baseline_value - current_value) / baseline_value * 100).round(2)

    degradation = if is_latency_metric
                    # For latency: positive overhead means improvement (lower latency), negative means degradation
                    -overhead # Invert: negative overhead is degradation
                  else
                    # For throughput: positive overhead means degradation (lower throughput)
                    overhead
                  end

    if degradation > 10
      puts "❌ FAIL: #{key} degraded by #{degradation}%"
      puts "   Baseline: #{baseline_value}, Current: #{current_value}"
      all_passed = false
    elsif degradation > 5
      puts "⚠️  WARNING: #{key} degraded by #{degradation}%"
      puts "   Baseline: #{baseline_value}, Current: #{current_value}"
      warnings << key
    else
      # Build change string based on metric type
      change_str = build_change_string(is_latency_metric, overhead, degradation)
      puts "✅ PASS: #{key} within acceptable range (#{change_str})"
      puts "   Baseline: #{baseline_value}, Current: #{current_value}"
    end
  end

  puts
  if all_passed && warnings.empty?
    puts "✅ All benchmarks passed!"
  elsif all_passed
    puts "⚠️  Benchmarks passed with warnings"
  else
    puts "❌ Performance regression detected!"
    exit 1
  end
else
  puts "No baseline available for comparison"
  puts
  puts "Current results:"
  current_results.each do |key, value|
    puts "  #{key}: #{value}"
  end
end

# ============================================================================
# Save Baseline or Results
# ============================================================================
if ARGV.include?("--update-baseline")
  File.write(baseline_file, JSON.pretty_generate(results))
  puts
  puts "✅ Baseline updated: #{baseline_file}"
else
  # Save results to results directory
  results_file = File.join(results_dir, "results_#{ruby_version}_#{Time.now.to_i}.json")
  File.write(results_file, JSON.pretty_generate(results))
  puts
  puts "Results saved to: #{results_file}"
end

puts "=" * 80
