# Batch Testing Guide

Complete guide to batch testing your decision rules against large datasets.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Importing Test Scenarios](#importing-test-scenarios)
- [Running Batch Tests](#running-batch-tests)
- [Analyzing Results](#analyzing-results)
- [Web UI](#web-ui)
- [Best Practices](#best-practices)
- [API Reference](#api-reference)

## Overview

Batch testing allows you to validate your decision rules against hundreds or thousands of test scenarios before deploying to production. This is essential for:

- **Regulatory Compliance** - Validate rule changes against compliance test suites
- **Risk Mitigation** - Test rule changes before production deployment
- **Performance Testing** - Measure decision-making performance at scale
- **Quality Assurance** - Automated regression testing for rule updates
- **Coverage Analysis** - Ensure all critical rules are tested

## Quick Start

```ruby
require 'decision_agent/testing/batch_test_importer'
require 'decision_agent/testing/batch_test_runner'
require 'decision_agent/testing/test_result_comparator'
require 'decision_agent/testing/test_coverage_analyzer'

# Step 1: Import test scenarios from CSV
importer = DecisionAgent::Testing::BatchTestImporter.new
scenarios = importer.import_csv('test_scenarios.csv')

# Step 2: Run batch tests
runner = DecisionAgent::Testing::BatchTestRunner.new(agent)
results = runner.run(scenarios, parallel: true, thread_count: 4)

# Step 3: Compare results
comparator = DecisionAgent::Testing::TestResultComparator.new
comparison = comparator.compare(results, scenarios)
puts "Accuracy: #{(comparison[:accuracy_rate] * 100).round(2)}%"

# Step 4: Analyze coverage
analyzer = DecisionAgent::Testing::TestCoverageAnalyzer.new
coverage = analyzer.analyze(results, agent)
puts "Coverage: #{(coverage.coverage_percentage * 100).round(2)}%"
```

## Importing Test Scenarios

### CSV Format

Your CSV file should have the following structure:

```csv
id,amount,user_role,expected_decision,expected_confidence
test_1,500,admin,approve,0.95
test_2,1500,user,approve,0.80
test_3,50000,user,manual_review,0.90
```

**Required Columns:**
- `id` - Unique identifier for each test scenario

**Optional Columns:**
- `expected_decision` - Expected decision value for comparison
- `expected_confidence` - Expected confidence score for comparison

**Context Columns:**
- All other columns are automatically used as context for decision-making

### Excel Format

Excel files (`.xlsx`, `.xls`) are also supported with the same structure:

```ruby
importer = DecisionAgent::Testing::BatchTestImporter.new

# Import from first sheet (default)
scenarios = importer.import_excel('test_scenarios.xlsx')

# Import from specific sheet by name
scenarios = importer.import_excel('test_scenarios.xlsx', sheet: 'Test Cases')

# Import from specific sheet by index
scenarios = importer.import_excel('test_scenarios.xlsx', sheet: 1)
```

### Custom Column Mapping

You can customize column names:

```ruby
scenarios = importer.import_csv('test_scenarios.csv',
  id_column: 'test_id',
  expected_decision_column: 'expected_result',
  expected_confidence_column: 'expected_score',
  context_columns: ['amount', 'user_role', 'region']  # Only use these as context
)
```

### Progress Tracking

For large imports (10k+ rows), use progress callbacks:

```ruby
scenarios = importer.import_csv('large_test_suite.csv',
  progress_callback: ->(progress) {
    puts "Imported #{progress[:processed]} / #{progress[:total]} rows (#{progress[:percentage]}%)"
  }
)
```

### Programmatic Import

Import from arrays of hashes:

```ruby
data = [
  { id: 'test_1', amount: 500, user_role: 'admin', expected_decision: 'approve' },
  { id: 'test_2', amount: 1500, user_role: 'user', expected_decision: 'approve' }
]

scenarios = importer.import_from_array(data)
```

### Error Handling

The importer collects errors and warnings:

```ruby
importer = DecisionAgent::Testing::BatchTestImporter.new
scenarios = importer.import_csv('test_scenarios.csv')

if importer.errors.any?
  puts "Errors: #{importer.errors.join(', ')}"
end

if importer.warnings.any?
  puts "Warnings: #{importer.warnings.join(', ')}"
end
```

## Running Batch Tests

### Basic Execution

```ruby
runner = DecisionAgent::Testing::BatchTestRunner.new(agent)
results = runner.run(scenarios)
```

### Parallel Execution

For better performance with large test suites:

```ruby
results = runner.run(scenarios,
  parallel: true,
  thread_count: 4  # Number of parallel threads
)
```

### Sequential Execution

For debugging or when order matters:

```ruby
results = runner.run(scenarios, parallel: false)
```

### Progress Tracking

Monitor execution progress:

```ruby
results = runner.run(scenarios,
  progress_callback: ->(progress) {
    puts "#{progress[:completed]} / #{progress[:total]} completed (#{progress[:percentage]}%)"
  }
)
```

### Resume Capability

For long-running tests, use checkpoints to resume if interrupted:

```ruby
# Run with checkpoint
results = runner.run(scenarios,
  checkpoint_file: 'checkpoint.json',
  parallel: true
)

# If interrupted, resume from checkpoint
results = runner.resume(scenarios, 'checkpoint.json')
```

The checkpoint file stores completed scenario IDs, so resumed tests automatically skip already-executed scenarios.

### Passing Feedback

Pass feedback context to the agent:

```ruby
results = runner.run(scenarios,
  feedback: { user_id: 123, session_id: 'abc' }
)
```

### Execution Statistics

Get performance metrics:

```ruby
stats = runner.statistics
# => {
#   total: 1000,
#   successful: 995,
#   failed: 5,
#   success_rate: 0.995,
#   avg_execution_time_ms: 12.5,
#   min_execution_time_ms: 8.2,
#   max_execution_time_ms: 45.3,
#   total_execution_time_ms: 12500.0
# }
```

## Analyzing Results

### Result Comparison

Compare actual results with expected outcomes:

```ruby
comparator = DecisionAgent::Testing::TestResultComparator.new
comparison = comparator.compare(results, scenarios)

puts "Total: #{comparison[:total]}"
puts "Matches: #{comparison[:matches]}"
puts "Mismatches: #{comparison[:mismatches]}"
puts "Accuracy: #{(comparison[:accuracy_rate] * 100).round(2)}%"
puts "Decision Accuracy: #{(comparison[:decision_accuracy] * 100).round(2)}%"
puts "Confidence Accuracy: #{(comparison[:confidence_accuracy] * 100).round(2)}%"
```

### Mismatch Details

Get detailed information about failures:

```ruby
comparison[:mismatches_detail].each do |mismatch|
  puts "Scenario #{mismatch[:scenario_id]}:"
  puts "  Expected: #{mismatch[:expected][:decision]} (#{mismatch[:expected][:confidence]})"
  puts "  Actual: #{mismatch[:actual][:decision]} (#{mismatch[:actual][:confidence]})"
  puts "  Differences: #{mismatch[:differences].join(', ')}"
end
```

### Fuzzy Matching

Enable fuzzy matching for case-insensitive comparisons:

```ruby
comparator = DecisionAgent::Testing::TestResultComparator.new(
  fuzzy_match: true,
  confidence_tolerance: 0.05  # 5% tolerance
)
comparison = comparator.compare(results, scenarios)
```

### Export Results

Export comparison results to CSV or JSON:

```ruby
# Export to CSV
comparator.export_csv('comparison_results.csv')

# Export to JSON
comparator.export_json('comparison_results.json')
```

### Coverage Analysis

Analyze which rules are covered by your tests:

```ruby
analyzer = DecisionAgent::Testing::TestCoverageAnalyzer.new
coverage = analyzer.analyze(results, agent)

puts "Coverage: #{(coverage.coverage_percentage * 100).round(2)}%"
puts "Covered Rules: #{coverage.covered_rules} / #{coverage.total_rules}"
puts "Untested Rules: #{coverage.untested_rules.size}"
```

### Coverage Details

Get rule-by-rule coverage:

```ruby
coverage.rule_coverage.each do |rule|
  puts "#{rule[:rule_id]}: #{rule[:covered] ? 'Covered' : 'Not Covered'} (#{rule[:execution_count]} times)"
end
```

## Web UI

### Accessing the Batch Testing UI

Start the web server:

```bash
decision_agent web
```

Navigate to: `http://localhost:4567/testing/batch`

### Features

1. **File Upload**
   - Drag and drop CSV/Excel files
   - Automatic file type detection
   - Progress tracking for large imports

2. **Rules Configuration**
   - Paste or import rules JSON
   - Validate rules before testing
   - Import from file

3. **Test Execution**
   - Configure parallel/sequential execution
   - Set thread count
   - Real-time progress tracking
   - Resume capability

4. **Results Visualization**
   - Statistics dashboard
   - Comparison metrics
   - Coverage analysis
   - Detailed results table

### API Endpoints

#### POST /api/testing/batch/import

Upload a CSV or Excel file with test scenarios.

**Request:**
- Content-Type: `multipart/form-data`
- Body: `file` (CSV or Excel file)

**Response:**
```json
{
  "test_id": "uuid",
  "scenarios_count": 1000,
  "errors": [],
  "warnings": []
}
```

#### POST /api/testing/batch/run

Execute a batch test.

**Request:**
```json
{
  "test_id": "uuid",
  "rules": { ... },
  "options": {
    "parallel": true,
    "thread_count": 4,
    "checkpoint_file": "checkpoint.json"
  }
}
```

**Response:**
```json
{
  "test_id": "uuid",
  "status": "completed",
  "results_count": 1000,
  "statistics": { ... },
  "comparison": { ... },
  "coverage": { ... }
}
```

#### GET /api/testing/batch/:id/results

Get detailed test results.

**Response:**
```json
{
  "test_id": "uuid",
  "status": "completed",
  "scenarios_count": 1000,
  "results": [ ... ],
  "comparison": { ... },
  "statistics": { ... }
}
```

#### GET /api/testing/batch/:id/coverage

Get coverage analysis report.

**Response:**
```json
{
  "test_id": "uuid",
  "coverage": {
    "total_rules": 50,
    "covered_rules": 45,
    "untested_rules": [ ... ],
    "coverage_percentage": 0.9,
    "rule_coverage": [ ... ]
  }
}
```

## Best Practices

### 1. Test Data Organization

- **Use meaningful IDs** - Make scenario IDs descriptive for easier debugging
- **Include expected results** - Always include `expected_decision` and `expected_confidence` when possible
- **Cover edge cases** - Include boundary conditions, null values, and error cases
- **Maintain test suites** - Keep test data in version control

### 2. Performance Optimization

- **Use parallel execution** - For large test suites (1000+ scenarios)
- **Optimize thread count** - Start with 4 threads, adjust based on CPU cores
- **Use checkpoints** - For very large tests (10k+ scenarios) to enable resume
- **Monitor memory** - Large test suites may require more memory

### 3. Result Analysis

- **Set appropriate tolerances** - Use confidence tolerance for floating-point comparisons
- **Review mismatches** - Always investigate mismatches to understand rule behavior
- **Track coverage** - Ensure all critical rules are tested
- **Export results** - Save comparison results for audit trails

### 4. Integration with CI/CD

```ruby
# In your CI pipeline
RSpec.describe "Rule Validation" do
  it "passes batch test suite" do
    scenarios = importer.import_csv('test_suite.csv')
    results = runner.run(scenarios, parallel: true)
    comparison = comparator.compare(results, scenarios)
    
    expect(comparison[:accuracy_rate]).to be >= 0.95
    expect(comparison[:mismatches]).to eq(0)
  end
end
```

### 5. Error Handling

```ruby
begin
  scenarios = importer.import_csv('test_suite.csv')
rescue DecisionAgent::ImportError => e
  puts "Import failed: #{e.message}"
  puts "Errors: #{importer.errors.join(', ')}"
  exit 1
end

results = runner.run(scenarios)
failed_results = results.reject(&:success?)

if failed_results.any?
  puts "Warning: #{failed_results.size} scenarios failed"
  failed_results.each do |result|
    puts "  #{result.scenario_id}: #{result.error.message}"
  end
end
```

## API Reference

### BatchTestImporter

#### Methods

- `import_csv(file_path, options = {})` - Import from CSV file
- `import_excel(file_path, options = {})` - Import from Excel file
- `import_from_array(data, options = {})` - Import from array of hashes

#### Options

- `id_column` - Column name for test ID (default: `"id"`)
- `expected_decision_column` - Column name for expected decision (default: `"expected_decision"`)
- `expected_confidence_column` - Column name for expected confidence (default: `"expected_confidence"`)
- `context_columns` - Array of column names to use as context (default: all except id/expected columns)
- `skip_header` - Skip first row as header (default: `true`)
- `sheet` - Excel sheet name or index (default: `0`)
- `progress_callback` - Proc called with `{ processed, total, percentage }`

#### Attributes

- `errors` - Array of error messages
- `warnings` - Array of warning messages

### BatchTestRunner

#### Methods

- `run(scenarios, options = {})` - Run batch tests
- `resume(scenarios, checkpoint_file, options = {})` - Resume from checkpoint
- `statistics` - Get execution statistics

#### Options

- `parallel` - Use parallel execution (default: `true`)
- `thread_count` - Number of threads (default: `4`)
- `progress_callback` - Proc called with `{ completed, total, percentage }`
- `feedback` - Hash of feedback context to pass to agent
- `checkpoint_file` - Path to checkpoint file for resume capability

#### Attributes

- `results` - Array of `TestResult` objects

### TestResultComparator

#### Methods

- `compare(results, scenarios)` - Compare results with expected outcomes
- `generate_summary` - Generate comparison summary
- `export_csv(file_path)` - Export to CSV
- `export_json(file_path)` - Export to JSON

#### Options

- `confidence_tolerance` - Tolerance for confidence comparison (default: `0.01`)
- `fuzzy_match` - Enable fuzzy decision matching (default: `false`)

### TestCoverageAnalyzer

#### Methods

- `analyze(results, agent)` - Analyze test coverage
- `coverage_percentage` - Get coverage percentage

#### Returns

`CoverageReport` object with:
- `total_rules` - Total number of rules
- `covered_rules` - Number of covered rules
- `untested_rules` - Array of untested rule IDs
- `coverage_percentage` - Coverage percentage (0.0 to 1.0)
- `rule_coverage` - Array of rule coverage details
- `condition_coverage` - Array of condition coverage details

## Examples

See `examples/08_batch_testing.rb` for a complete working example with:
- CSV import
- Batch execution
- Result comparison
- Coverage analysis
- Export functionality

## Troubleshooting

### Import Errors

**Problem:** `ImportError: Failed to import`

**Solution:** Check `importer.errors` for specific row-level errors. Common issues:
- Missing required `id` column
- Empty context (no context columns found)
- Invalid data types

### Performance Issues

**Problem:** Slow batch execution

**Solution:**
- Enable parallel execution: `parallel: true`
- Increase thread count: `thread_count: 8`
- Use checkpoints for very large tests
- Check agent performance (evaluator efficiency)

### Memory Issues

**Problem:** Out of memory with large test suites

**Solution:**
- Process in batches (split CSV into smaller files)
- Use streaming import (process scenarios in chunks)
- Increase available memory
- Consider using database-backed storage for results

## See Also

- [Main README](../README.md) - Installation and overview
- [Examples](../examples/README.md) - Code examples
- [API Contract](API_CONTRACT.md) - Complete API specifications

