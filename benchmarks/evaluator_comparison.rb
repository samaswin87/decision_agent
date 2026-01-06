#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/evaluators/dmn_evaluator"
require "benchmark"

# ============================================================================
# Configuration
# ============================================================================
INIT_ITERATIONS = 100
EVAL_ITERATIONS = 10_000
WARMUP_ITERATIONS = 100

puts "=" * 80
puts "Evaluator Comparison Benchmark"
puts "=" * 80
puts

# ============================================================================
# Setup - Equivalent Rules
# ============================================================================

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

# DMN XML (FIRST hit policy)
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

# Test contexts
test_contexts = [
  { credit_score: 800, income: 100_000 },
  { credit_score: 680, income: 55_000 },
  { credit_score: 620, income: 35_000 },
  { credit_score: 550, income: 40_000 },
  { credit_score: 700, income: 25_000 }
]

# ============================================================================
# Benchmark 1: Initialization Time
# ============================================================================
puts "1. INITIALIZATION TIME COMPARISON"
puts "-" * 80

# Warm up
DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: json_rules)
importer = DecisionAgent::Dmn::Importer.new
importer.import_from_xml(dmn_xml_first, ruleset_name: "benchmark", created_by: "benchmark")

json_init_time = Benchmark.realtime do
  INIT_ITERATIONS.times do
    DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: json_rules)
  end
end

dmn_init_time = Benchmark.realtime do
  INIT_ITERATIONS.times do
    importer = DecisionAgent::Dmn::Importer.new
    result = importer.import_from_xml(dmn_xml_first, ruleset_name: "benchmark", created_by: "benchmark")
    DecisionAgent::Evaluators::DmnEvaluator.new(model: result[:model], decision_id: "loan_decision")
  end
end

json_init_avg = (json_init_time / INIT_ITERATIONS * 1000).round(4)
dmn_init_avg = (dmn_init_time / INIT_ITERATIONS * 1000).round(4)
overhead = ((dmn_init_avg - json_init_avg) / json_init_avg * 100).round(2)

puts "JSON Evaluator initialization:"
puts "  #{INIT_ITERATIONS} iterations: #{(json_init_time * 1000).round(2)}ms"
puts "  Average: #{json_init_avg}ms per evaluator"
puts
puts "DMN Evaluator initialization (includes XML parsing + conversion):"
puts "  #{INIT_ITERATIONS} iterations: #{(dmn_init_time * 1000).round(2)}ms"
puts "  Average: #{dmn_init_avg}ms per evaluator"
puts
puts "Overhead: #{overhead > 0 ? '+' : ''}#{overhead}% (#{((dmn_init_avg - json_init_avg)).round(4)}ms per evaluator)"
puts

# ============================================================================
# Benchmark 2: Evaluation Latency
# ============================================================================
puts "2. EVALUATION LATENCY COMPARISON"
puts "-" * 80

json_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: json_rules)
importer = DecisionAgent::Dmn::Importer.new
dmn_result = importer.import_from_xml(dmn_xml_first, ruleset_name: "benchmark", created_by: "benchmark")
dmn_evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(model: dmn_result[:model], decision_id: "loan_decision")

json_agent = DecisionAgent::Agent.new(evaluators: [json_evaluator], validate_evaluations: false)
dmn_agent = DecisionAgent::Agent.new(evaluators: [dmn_evaluator], validate_evaluations: false)

# Warm up
WARMUP_ITERATIONS.times do |i|
  ctx = test_contexts[i % test_contexts.size]
  json_agent.decide(context: ctx)
  dmn_agent.decide(context: ctx)
end

# Measure JSON evaluation
json_eval_time = Benchmark.realtime do
  EVAL_ITERATIONS.times do |i|
    ctx = test_contexts[i % test_contexts.size]
    json_agent.decide(context: ctx)
  end
end

# Measure DMN evaluation
dmn_eval_time = Benchmark.realtime do
  EVAL_ITERATIONS.times do |i|
    ctx = test_contexts[i % test_contexts.size]
    dmn_agent.decide(context: ctx)
  end
end

json_eval_avg = (json_eval_time / EVAL_ITERATIONS * 1000).round(4)
dmn_eval_avg = (dmn_eval_time / EVAL_ITERATIONS * 1000).round(4)
eval_overhead = ((dmn_eval_avg - json_eval_avg) / json_eval_avg * 100).round(2)

json_throughput = (EVAL_ITERATIONS / json_eval_time).round(0)
dmn_throughput = (EVAL_ITERATIONS / dmn_eval_time).round(0)

puts "JSON Evaluator:"
puts "  #{EVAL_ITERATIONS} iterations: #{(json_eval_time * 1000).round(2)}ms"
puts "  Average: #{json_eval_avg}ms per evaluation"
puts "  Throughput: #{json_throughput} evaluations/sec"
puts
puts "DMN Evaluator (FIRST hit policy):"
puts "  #{EVAL_ITERATIONS} iterations: #{(dmn_eval_time * 1000).round(2)}ms"
puts "  Average: #{dmn_eval_avg}ms per evaluation"
puts "  Throughput: #{dmn_throughput} evaluations/sec"
puts
puts "Evaluation overhead: #{eval_overhead > 0 ? '+' : ''}#{eval_overhead}%"
puts

# ============================================================================
# Summary
# ============================================================================
puts "=" * 80
puts "PERFORMANCE SUMMARY"
puts "=" * 80
puts
puts "INITIALIZATION:"
puts "  • JSON evaluator: #{json_init_avg}ms (one-time cost)"
puts "  • DMN evaluator:  #{dmn_init_avg}ms (includes XML parsing + JSON conversion)"
puts "  • Overhead: #{overhead > 0 ? '+' : ''}#{overhead}%"
puts
puts "EVALUATION:"
puts "  • JSON evaluator: #{json_eval_avg}ms per evaluation"
puts "  • DMN evaluator:  #{dmn_eval_avg}ms per evaluation"
puts "  • Overhead: #{eval_overhead > 0 ? '+' : ''}#{eval_overhead}%"
puts
puts "THROUGHPUT:"
puts "  • JSON evaluator: #{json_throughput} evaluations/sec"
puts "  • DMN evaluator:  #{dmn_throughput} evaluations/sec"
puts "=" * 80

