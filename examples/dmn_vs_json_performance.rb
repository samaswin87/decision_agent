#!/usr/bin/env ruby
# frozen_string_literal: true

# DMN vs JSON Evaluator Performance Benchmark
#
# This benchmark compares the performance characteristics of:
# 1. JsonRuleEvaluator - Direct JSON rule evaluation
# 2. DmnEvaluator - DMN model evaluation (which internally converts to JSON)
#
# Metrics measured:
# - Initialization time (one-time cost)
# - Single evaluation latency
# - Batch evaluation throughput
# - Memory overhead (if available)

require "bundler/setup"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/evaluators/dmn_evaluator"
require "benchmark"

puts "=" * 80
puts "DMN vs JSON Evaluator Performance Benchmark"
puts "=" * 80
puts

# Define equivalent rules in both formats
# This ensures we're comparing equivalent logic

# JSON Rules format
json_rules = {
  version: "1.0",
  ruleset: "loan_approval_benchmark",
  rules: [
    {
      id: "rule_1",
      if: {
        all: [
          { field: "credit_score", op: "gte", value: 750 },
          { field: "income", op: "gte", value: 75_000 }
        ]
      },
      then: {
        decision: "approved",
        weight: 1.0,
        reason: "Excellent credit with high income"
      }
    },
    {
      id: "rule_2",
      if: {
        all: [
          { field: "credit_score", op: "gte", value: 650 },
          { field: "income", op: "gte", value: 50_000 }
        ]
      },
      then: {
        decision: "conditional",
        weight: 0.8,
        reason: "Good credit with moderate income"
      }
    },
    {
      id: "rule_3",
      if: {
        all: [
          { field: "credit_score", op: "gte", value: 600 },
          { field: "income", op: "gte", value: 30_000 }
        ]
      },
      then: {
        decision: "conditional",
        weight: 0.6,
        reason: "Fair credit with lower income"
      }
    },
    {
      id: "rule_4",
      if: {
        field: "credit_score", op: "lt", value: 600
      },
      then: {
        decision: "rejected",
        weight: 1.0,
        reason: "Credit score too low"
      }
    },
    {
      id: "rule_5",
      if: {
        field: "income", op: "lt", value: 30_000
      },
      then: {
        decision: "rejected",
        weight: 1.0,
        reason: "Income too low"
      }
    }
  ]
}

# Equivalent DMN XML (FIRST hit policy - most common)
dmn_xml_first = <<~DMN
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="loan_approval_benchmark"
               name="Loan Approval Benchmark"
               namespace="http://example.com/dmn">

    <decision id="loan_decision" name="Loan Approval Decision">
      <decisionTable id="loan_table" hitPolicy="FIRST">
        <input id="input_credit" label="Credit Score">
          <inputExpression typeRef="number">
            <text>credit_score</text>
          </inputExpression>
        </input>

        <input id="input_income" label="Annual Income">
          <inputExpression typeRef="number">
            <text>income</text>
          </inputExpression>
        </input>

        <output id="output_decision" label="Decision" name="decision" typeRef="string"/>

        <rule id="rule_1">
          <description>Excellent credit with high income</description>
          <inputEntry id="entry_1_credit">
            <text>>= 750</text>
          </inputEntry>
          <inputEntry id="entry_1_income">
            <text>>= 75000</text>
          </inputEntry>
          <outputEntry id="output_1">
            <text>"approved"</text>
          </outputEntry>
        </rule>

        <rule id="rule_2">
          <description>Good credit with moderate income</description>
          <inputEntry id="entry_2_credit">
            <text>>= 650</text>
          </inputEntry>
          <inputEntry id="entry_2_income">
            <text>>= 50000</text>
          </inputEntry>
          <outputEntry id="output_2">
            <text>"conditional"</text>
          </outputEntry>
        </rule>

        <rule id="rule_3">
          <description>Fair credit with lower income</description>
          <inputEntry id="entry_3_credit">
            <text>>= 600</text>
          </inputEntry>
          <inputEntry id="entry_3_income">
            <text>>= 30000</text>
          </inputEntry>
          <outputEntry id="output_3">
            <text>"conditional"</text>
          </outputEntry>
        </rule>

        <rule id="rule_4">
          <description>Credit score too low</description>
          <inputEntry id="entry_4_credit">
            <text>&lt; 600</text>
          </inputEntry>
          <inputEntry id="entry_4_income">
            <text>-</text>
          </inputEntry>
          <outputEntry id="output_4">
            <text>"rejected"</text>
          </outputEntry>
        </rule>

        <rule id="rule_5">
          <description>Income too low</description>
          <inputEntry id="entry_5_credit">
            <text>-</text>
          </inputEntry>
          <inputEntry id="entry_5_income">
            <text>&lt; 30000</text>
          </inputEntry>
          <outputEntry id="output_5">
            <text>"rejected"</text>
          </outputEntry>
        </rule>
      </decisionTable>
    </decision>
  </definitions>
DMN

# Test contexts for evaluation
test_contexts = [
  { credit_score: 800, income: 100_000 },  # Rule 1 - Approved
  { credit_score: 680, income: 55_000 },   # Rule 2 - Conditional
  { credit_score: 620, income: 35_000 },   # Rule 3 - Conditional
  { credit_score: 550, income: 40_000 },   # Rule 4 - Rejected (credit)
  { credit_score: 700, income: 25_000 },   # Rule 5 - Rejected (income)
  { credit_score: 720, income: 80_000 },   # Rule 1 - Approved
  { credit_score: 650, income: 50_000 },   # Rule 2 - Conditional
  { credit_score: 580, income: 32_000 },   # Rule 3 - Conditional
]

# ============================================================================
# Benchmark 1: Initialization Time Comparison
# ============================================================================
puts "1. INITIALIZATION TIME COMPARISON"
puts "-" * 80

# Warm up
DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: json_rules)
importer = DecisionAgent::Dmn::Importer.new
importer.import_from_xml(dmn_xml_first, ruleset_name: "benchmark", created_by: "benchmark")

json_init_time = Benchmark.realtime do
  100.times do
    DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: json_rules)
  end
end

dmn_init_time = Benchmark.realtime do
  100.times do
    importer = DecisionAgent::Dmn::Importer.new
    result = importer.import_from_xml(dmn_xml_first, ruleset_name: "benchmark", created_by: "benchmark")
    DecisionAgent::Evaluators::DmnEvaluator.new(model: result[:model], decision_id: "loan_decision")
  end
end

json_init_avg = (json_init_time / 100 * 1000).round(4)
dmn_init_avg = (dmn_init_time / 100 * 1000).round(4)
overhead = ((dmn_init_avg - json_init_avg) / json_init_avg * 100).round(2)

puts "JSON Evaluator initialization:"
puts "  100 iterations: #{(json_init_time * 1000).round(2)}ms"
puts "  Average: #{json_init_avg}ms per evaluator"
puts
puts "DMN Evaluator initialization (includes XML parsing + conversion):"
puts "  100 iterations: #{(dmn_init_time * 1000).round(2)}ms"
puts "  Average: #{dmn_init_avg}ms per evaluator"
puts
puts "Overhead: #{overhead > 0 ? '+' : ''}#{overhead}% (#{((dmn_init_avg - json_init_avg)).round(4)}ms per evaluator)"
puts

# ============================================================================
# Benchmark 2: Single Evaluation Latency
# ============================================================================
puts "2. SINGLE EVALUATION LATENCY"
puts "-" * 80

json_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: json_rules)
importer = DecisionAgent::Dmn::Importer.new
dmn_result = importer.import_from_xml(dmn_xml_first, ruleset_name: "benchmark", created_by: "benchmark")
dmn_evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(model: dmn_result[:model], decision_id: "loan_decision")

# Warm up
test_contexts.each do |ctx|
  context = DecisionAgent::Context.new(ctx)
  json_evaluator.evaluate(context)
  dmn_evaluator.evaluate(context)
end

# Measure JSON evaluation
json_eval_time = Benchmark.realtime do
  10_000.times do |i|
    ctx = test_contexts[i % test_contexts.size]
    context = DecisionAgent::Context.new(ctx)
    json_evaluator.evaluate(context)
  end
end

# Measure DMN evaluation
dmn_eval_time = Benchmark.realtime do
  10_000.times do |i|
    ctx = test_contexts[i % test_contexts.size]
    context = DecisionAgent::Context.new(ctx)
    dmn_evaluator.evaluate(context)
  end
end

json_eval_avg = (json_eval_time / 10_000 * 1000).round(4)
dmn_eval_avg = (dmn_eval_time / 10_000 * 1000).round(4)
eval_overhead = ((dmn_eval_avg - json_eval_avg) / json_eval_avg * 100).round(2)

puts "JSON Evaluator single evaluation:"
puts "  10,000 iterations: #{(json_eval_time * 1000).round(2)}ms"
puts "  Average: #{json_eval_avg}ms per evaluation"
puts "  Throughput: #{(10_000 / json_eval_time).round(0)} evaluations/sec"
puts
puts "DMN Evaluator single evaluation (FIRST hit policy):"
puts "  10,000 iterations: #{(dmn_eval_time * 1000).round(2)}ms"
puts "  Average: #{dmn_eval_avg}ms per evaluation"
puts "  Throughput: #{(10_000 / dmn_eval_time).round(0)} evaluations/sec"
puts
puts "Evaluation overhead: #{eval_overhead > 0 ? '+' : ''}#{eval_overhead}% (#{((dmn_eval_avg - json_eval_avg)).round(4)}ms per evaluation)"
puts

# ============================================================================
# Benchmark 3: Batch Throughput Comparison
# ============================================================================
puts "3. BATCH THROUGHPUT COMPARISON"
puts "-" * 80

iterations = 50_000

json_throughput_time = Benchmark.realtime do
  iterations.times do |i|
    ctx = test_contexts[i % test_contexts.size]
    context = DecisionAgent::Context.new(ctx)
    json_evaluator.evaluate(context)
  end
end

dmn_throughput_time = Benchmark.realtime do
  iterations.times do |i|
    ctx = test_contexts[i % test_contexts.size]
    context = DecisionAgent::Context.new(ctx)
    dmn_evaluator.evaluate(context)
  end
end

json_throughput = (iterations / json_throughput_time).round(0)
dmn_throughput = (iterations / dmn_throughput_time).round(0)
throughput_diff = ((dmn_throughput - json_throughput) / json_throughput.to_f * 100).round(2)

puts "JSON Evaluator batch throughput:"
puts "  #{iterations} evaluations in #{(json_throughput_time * 1000).round(2)}ms"
puts "  Throughput: #{json_throughput} evaluations/sec"
puts
puts "DMN Evaluator batch throughput:"
puts "  #{iterations} evaluations in #{(dmn_throughput_time * 1000).round(2)}ms"
puts "  Throughput: #{dmn_throughput} evaluations/sec"
puts
puts "Throughput difference: #{throughput_diff > 0 ? '+' : ''}#{throughput_diff}%"
puts

# ============================================================================
# Benchmark 4: Hit Policy Overhead (FIRST vs UNIQUE)
# ============================================================================
puts "4. HIT POLICY OVERHEAD COMPARISON"
puts "-" * 80

# Create UNIQUE hit policy DMN (mutually exclusive rules)
dmn_xml_unique = <<~DMN
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="loan_approval_unique"
               name="Loan Approval UNIQUE"
               namespace="http://example.com/dmn">

    <decision id="loan_decision" name="Loan Approval Decision">
      <decisionTable id="loan_table" hitPolicy="UNIQUE">
        <input id="input_credit" label="Credit Score">
          <inputExpression typeRef="number">
            <text>credit_score</text>
          </inputExpression>
        </input>

        <input id="input_income" label="Annual Income">
          <inputExpression typeRef="number">
            <text>income</text>
          </inputExpression>
        </input>

        <output id="output_decision" label="Decision" name="decision" typeRef="string"/>

        <rule id="rule_1">
          <description>Excellent credit with high income</description>
          <inputEntry id="entry_1_credit">
            <text>[750..999]</text>
          </inputEntry>
          <inputEntry id="entry_1_income">
            <text>[75000..999999]</text>
          </inputEntry>
          <outputEntry id="output_1">
            <text>"approved"</text>
          </outputEntry>
        </rule>

        <rule id="rule_2">
          <description>Good credit with moderate income</description>
          <inputEntry id="entry_2_credit">
            <text>[650..749]</text>
          </inputEntry>
          <inputEntry id="entry_2_income">
            <text>[50000..74999]</text>
          </inputEntry>
          <outputEntry id="output_2">
            <text>"conditional"</text>
          </outputEntry>
        </rule>

        <rule id="rule_3">
          <description>Fair credit with lower income</description>
          <inputEntry id="entry_3_credit">
            <text>[600..649]</text>
          </inputEntry>
          <inputEntry id="entry_3_income">
            <text>[30000..49999]</text>
          </inputEntry>
          <outputEntry id="output_3">
            <text>"conditional"</text>
          </outputEntry>
        </rule>

        <rule id="rule_4">
          <description>Rejected</description>
          <inputEntry id="entry_4_credit">
            <text>-</text>
          </inputEntry>
          <inputEntry id="entry_4_income">
            <text>-</text>
          </inputEntry>
          <outputEntry id="output_4">
            <text>"rejected"</text>
          </outputEntry>
        </rule>
      </decisionTable>
    </decision>
  </definitions>
DMN

importer_unique = DecisionAgent::Dmn::Importer.new
dmn_result_unique = importer_unique.import_from_xml(dmn_xml_unique, ruleset_name: "benchmark_unique", created_by: "benchmark")
dmn_evaluator_unique = DecisionAgent::Evaluators::DmnEvaluator.new(model: dmn_result_unique[:model], decision_id: "loan_decision")

# Warm up
test_contexts.each do |ctx|
  context = DecisionAgent::Context.new(ctx)
  dmn_evaluator_unique.evaluate(context) rescue nil
end

# Measure FIRST policy
dmn_first_time = Benchmark.realtime do
  10_000.times do |i|
    ctx = test_contexts[i % test_contexts.size]
    context = DecisionAgent::Context.new(ctx)
    dmn_evaluator.evaluate(context)
  end
end

# Measure UNIQUE policy (requires all matches)
dmn_unique_time = Benchmark.realtime do
  10_000.times do |i|
    ctx = test_contexts[i % test_contexts.size]
    context = DecisionAgent::Context.new(ctx)
    dmn_evaluator_unique.evaluate(context) rescue nil
  end
end

dmn_first_avg = (dmn_first_time / 10_000 * 1000).round(4)
dmn_unique_avg = (dmn_unique_time / 10_000 * 1000).round(4)
policy_overhead = ((dmn_unique_avg - dmn_first_avg) / dmn_first_avg * 100).round(2)

puts "DMN FIRST hit policy (short-circuit, returns first match):"
puts "  10,000 iterations: #{(dmn_first_time * 1000).round(2)}ms"
puts "  Average: #{dmn_first_avg}ms per evaluation"
puts
puts "DMN UNIQUE hit policy (requires all matches, then validates):"
puts "  10,000 iterations: #{(dmn_unique_time * 1000).round(2)}ms"
puts "  Average: #{dmn_unique_avg}ms per evaluation"
puts
puts "UNIQUE policy overhead: #{policy_overhead > 0 ? '+' : ''}#{policy_overhead}%"
puts

# ============================================================================
# Summary
# ============================================================================
puts "=" * 80
puts "PERFORMANCE SUMMARY"
puts "=" * 80
puts
puts "KEY FINDINGS:"
puts
puts "1. INITIALIZATION:"
puts "   • JSON evaluator: #{json_init_avg}ms (one-time cost)"
puts "   • DMN evaluator:  #{dmn_init_avg}ms (includes XML parsing + JSON conversion)"
puts "   • Overhead: #{overhead > 0 ? '+' : ''}#{overhead}% (#{dmn_init_avg > json_init_avg ? 'slower' : 'faster'})"
puts
puts "2. EVALUATION LATENCY:"
puts "   • JSON evaluator: #{json_eval_avg}ms per evaluation"
puts "   • DMN evaluator:  #{dmn_eval_avg}ms per evaluation"
puts "   • Overhead: #{eval_overhead > 0 ? '+' : ''}#{eval_overhead}% (#{dmn_eval_avg > json_eval_avg ? 'slower' : 'faster'})"
puts
puts "3. THROUGHPUT:"
puts "   • JSON evaluator: #{json_throughput} evaluations/sec"
puts "   • DMN evaluator:  #{dmn_throughput} evaluations/sec"
puts "   • Difference: #{throughput_diff > 0 ? '+' : ''}#{throughput_diff}%"
puts
puts "4. HIT POLICY IMPACT:"
puts "   • FIRST policy (short-circuit):  #{dmn_first_avg}ms per evaluation"
puts "   • UNIQUE policy (all matches):   #{dmn_unique_avg}ms per evaluation"
puts "   • Overhead: #{policy_overhead > 0 ? '+' : ''}#{policy_overhead}%"
puts
puts "RECOMMENDATIONS:"
puts
if overhead > 50
  puts "⚠️  DMN initialization overhead is significant (#{overhead}%)"
  puts "   Consider caching DMN evaluators for reuse"
else
  puts "✓ DMN initialization overhead is acceptable"
end

if eval_overhead.abs < 5
  puts "✓ DMN evaluation performance is comparable to JSON evaluator"
  puts "  The conversion overhead is minimal at runtime"
elsif eval_overhead > 20
  puts "⚠️  DMN evaluation shows noticeable overhead (#{eval_overhead}%)"
  puts "   For high-throughput scenarios, JSON evaluators may be preferred"
else
  puts "✓ DMN evaluation overhead is acceptable for most use cases"
end

if policy_overhead > 10
  puts "⚠️  UNIQUE hit policy adds overhead (#{policy_overhead}%)"
  puts "   Use FIRST policy when possible for better performance"
else
  puts "✓ Hit policy overhead is minimal"
end

puts
puts "ARCHITECTURE NOTES:"
puts "• DMN evaluator internally converts DMN to JSON rules during initialization"
puts "• DMN evaluator uses JsonRuleEvaluator for actual rule evaluation"
puts "• Additional overhead comes from hit policy handling and metadata"
puts "• FIRST/PRIORITY policies use short-circuiting (better performance)"
puts "• UNIQUE/ANY/COLLECT policies require all matches (higher overhead)"
puts
puts "=" * 80
puts "Benchmark complete!"
puts "=" * 80

