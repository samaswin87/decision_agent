#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "fileutils"

# Find the last 2 benchmark result files
results_dir = File.join(__dir__, "..", "benchmarks", "results")
result_files = Dir.glob(File.join(results_dir, "results_*.json"))
                  .sort_by { |f| File.mtime(f) }
                  .reverse
                  .first(2)

if result_files.length < 2
  puts "⚠️  Need at least 2 benchmark results to compare"
  exit 1
end

# Load the results
latest = JSON.parse(File.read(result_files[0]))
previous = JSON.parse(File.read(result_files[1]))

# Calculate changes
def calculate_change(old_val, new_val, is_latency = false)
  return "N/A" if old_val.nil? || new_val.nil? || old_val.zero?

  change_pct = ((new_val - old_val) / old_val * 100).round(2)

  if is_latency
    # For latency, lower is better
    if change_pct.negative?
      "↓ #{change_pct.abs}% (improved)"
    elsif change_pct.positive?
      "↑ #{change_pct}% (degraded)"
    else
      "→ 0% (no change)"
    end
  elsif change_pct.positive?
    # For throughput, higher is better
    "↑ #{change_pct}% (improved)"
  elsif change_pct.negative?
    "↓ #{change_pct.abs}% (degraded)"
  else
    "→ 0% (no change)"
  end
end

# Generate markdown
markdown = <<~MARKDOWN
  ## Latest Benchmark Results

  **Last Updated:** #{latest['timestamp']}

  ### Performance Comparison

  | Metric | Latest (#{latest['timestamp'].split('T').first}) | Previous (#{previous['timestamp'].split('T').first}) | Change |
  |--------|--------------------------------------------------|------------------------------------------------------|--------|
  | Basic Throughput | #{latest['results']['basic_throughput']} decisions/sec | #{previous['results']['basic_throughput']} decisions/sec | #{calculate_change(previous['results']['basic_throughput'], latest['results']['basic_throughput'])} |
  | Basic Latency | #{latest['results']['basic_latency_ms']} ms | #{previous['results']['basic_latency_ms']} ms | #{calculate_change(previous['results']['basic_latency_ms'], latest['results']['basic_latency_ms'], true)} |
  | Multi-threaded (50 threads) Throughput | #{latest['results']['thread_50_throughput']} decisions/sec | #{previous['results']['thread_50_throughput']} decisions/sec | #{calculate_change(previous['results']['thread_50_throughput'], latest['results']['thread_50_throughput'])} |
  | Multi-threaded (50 threads) Latency | #{latest['results']['thread_50_latency_ms']} ms | #{previous['results']['thread_50_latency_ms']} ms | #{calculate_change(previous['results']['thread_50_latency_ms'], latest['results']['thread_50_latency_ms'], true)} |

  **Environment:**
  - Ruby Version: #{latest['ruby_version']}
  - Hardware: #{latest['hardware']}
  - OS: #{latest['os']}
  - Git Commit: `#{latest['git_commit'][0..7]}`

  > 💡 **Note:** Run `rake benchmark:regression` to generate new benchmark results. This section is automatically updated with the last 2 benchmark runs.
MARKDOWN

puts markdown
