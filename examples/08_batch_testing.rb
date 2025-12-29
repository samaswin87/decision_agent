#!/usr/bin/env ruby
# frozen_string_literal: true

# Load decision_agent from the lib directory (for development)
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "decision_agent"
require "tempfile"

# Example: Batch Testing Capabilities
#
# This example demonstrates how to use the batch testing features:
# 1. Import test scenarios from CSV
# 2. Run batch tests with parallel execution
# 3. Compare results with expected outcomes
# 4. Generate coverage reports

# Setup: Create a simple agent with evaluators
evaluator1 = DecisionAgent::Evaluators::StaticEvaluator.new(
  decision: "approve",
  weight: 0.8,
  reason: "User meets basic criteria"
)

evaluator2 = DecisionAgent::Evaluators::StaticEvaluator.new(
  decision: "approve",
  weight: 0.6,
  reason: "Transaction amount is acceptable"
)

agent = DecisionAgent::Agent.new(evaluators: [evaluator1, evaluator2])

puts "=" * 80
puts "Batch Testing Example"
puts "=" * 80
puts

# Step 1: Create test scenarios programmatically
puts "Step 1: Creating test scenarios programmatically..."
importer = DecisionAgent::Testing::BatchTestImporter.new

test_data = [
  {
    id: "test_1",
    user_id: 123,
    amount: 1000,
    expected_decision: "approve",
    expected_confidence: 0.7
  },
  {
    id: "test_2",
    user_id: 456,
    amount: 5000,
    expected_decision: "approve",
    expected_confidence: 0.7
  },
  {
    id: "test_3",
    user_id: 789,
    amount: 10_000,
    expected_decision: "approve"
  }
]

scenarios = importer.import_from_array(test_data)
puts "  ✓ Imported #{scenarios.size} test scenarios"
puts

# Step 2: Run batch tests
puts "Step 2: Running batch tests..."
runner = DecisionAgent::Testing::BatchTestRunner.new(agent)

progress_updates = []
results = runner.run(scenarios,
                     parallel: true,
                     thread_count: 2,
                     progress_callback: lambda { |progress|
                       progress_updates << progress
                       print "\r  Progress: #{progress[:completed]}/#{progress[:total]} (#{progress[:percentage]}%)"
                     })

puts
puts "  ✓ Completed #{results.size} test executions"
puts

# Step 3: Display statistics
puts "Step 3: Execution Statistics"
stats = runner.statistics
puts "  Total: #{stats[:total]}"
puts "  Successful: #{stats[:successful]}"
puts "  Failed: #{stats[:failed]}"
puts "  Success Rate: #{(stats[:success_rate] * 100).round(2)}%"
puts "  Avg Execution Time: #{stats[:avg_execution_time_ms].round(2)}ms"
puts

# Step 4: Compare results with expected outcomes
puts "Step 4: Comparing results with expected outcomes..."
comparator = DecisionAgent::Testing::TestResultComparator.new
comparison = comparator.compare(results, scenarios)

puts "  Total Comparisons: #{comparison[:total]}"
puts "  Matches: #{comparison[:matches]}"
puts "  Mismatches: #{comparison[:mismatches]}"
puts "  Accuracy Rate: #{(comparison[:accuracy_rate] * 100).round(2)}%"
puts "  Decision Accuracy: #{(comparison[:decision_accuracy] * 100).round(2)}%"
puts "  Confidence Accuracy: #{(comparison[:confidence_accuracy] * 100).round(2)}%"
puts

if comparison[:mismatches].positive?
  puts "  Mismatches:"
  comparison[:mismatches_detail].each do |mismatch|
    puts "    - Scenario #{mismatch[:scenario_id]}: #{mismatch[:differences].join(', ')}"
  end
  puts
end

# Step 5: Generate coverage report
puts "Step 5: Generating coverage report..."
coverage_analyzer = DecisionAgent::Testing::TestCoverageAnalyzer.new
coverage_report = coverage_analyzer.analyze(results, agent)

puts "  Total Rules: #{coverage_report.total_rules}"
puts "  Covered Rules: #{coverage_report.covered_rules}"
puts "  Coverage Percentage: #{(coverage_report.coverage_percentage * 100).round(2)}%"
puts

if coverage_report.untested_rules.any?
  puts "  Untested Rules:"
  coverage_report.untested_rules.each do |rule|
    puts "    - #{rule}"
  end
  puts
end

# Step 6: Export results (example)
puts "Step 6: Exporting comparison results..."
temp_csv = Tempfile.new(["comparison", ".csv"])
temp_json = Tempfile.new(["comparison", ".json"])

comparator.export_csv(temp_csv.path)
comparator.export_json(temp_json.path)

puts "  ✓ Exported CSV to: #{temp_csv.path}"
puts "  ✓ Exported JSON to: #{temp_json.path}"
puts

# Step 7: CSV Import Example
puts "Step 7: CSV Import Example"
csv_content = <<~CSV
  id,user_id,amount,expected_decision,expected_confidence
  csv_test_1,111,2000,approve,0.7
  csv_test_2,222,3000,approve,0.7
  csv_test_3,333,4000,approve,0.7
CSV

csv_file = Tempfile.new(["test_scenarios", ".csv"])
csv_file.write(csv_content)
csv_file.close

csv_scenarios = importer.import_csv(csv_file.path)
puts "  ✓ Imported #{csv_scenarios.size} scenarios from CSV"
puts

# Run tests on CSV scenarios
csv_results = runner.run(csv_scenarios, parallel: true)
csv_comparison = comparator.compare(csv_results, csv_scenarios)

puts "  CSV Test Results:"
puts "    Accuracy: #{(csv_comparison[:accuracy_rate] * 100).round(2)}%"
puts

puts "=" * 80
puts "Batch Testing Example Complete!"
puts "=" * 80

# Cleanup
temp_csv.unlink
temp_json.unlink
csv_file.unlink
