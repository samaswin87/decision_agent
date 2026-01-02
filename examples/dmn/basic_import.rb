#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic DMN Import and Execution Example
#
# This example demonstrates how to:
# 1. Import a DMN XML file
# 2. Create a DMN evaluator
# 3. Make decisions using the imported DMN model

require "bundler/setup"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/evaluators/dmn_evaluator"

# Create a simple DMN XML file for demonstration
dmn_xml = <<~DMN
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="loan_approval"
               name="Loan Approval Decision"
               namespace="http://example.com/dmn">

    <decision id="loan_decision" name="Loan Approval">
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
          <description>Approve excellent credit with high income</description>
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
          <description>Conditional approval for good credit</description>
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
          <description>Reject low credit or income</description>
          <inputEntry id="entry_3_credit">
            <text>-</text>
          </inputEntry>
          <inputEntry id="entry_3_income">
            <text>-</text>
          </inputEntry>
          <outputEntry id="output_3">
            <text>"rejected"</text>
          </outputEntry>
        </rule>
      </decisionTable>
    </decision>
  </definitions>
DMN

puts "=" * 80
puts "DMN Basic Import and Execution Example"
puts "=" * 80
puts

# Step 1: Import the DMN XML
puts "Step 1: Importing DMN model..."
importer = DecisionAgent::Dmn::Importer.new
result = importer.import_from_xml(dmn_xml, ruleset_name: "loan_approval", created_by: "example_user")

puts "✓ Successfully imported #{result[:decisions_imported]} decision(s)"
puts "  Model: #{result[:model].name}"
puts "  Decision ID: #{result[:model].decisions.first.id}"
puts

# Step 2: Create a DMN evaluator
puts "Step 2: Creating DMN evaluator..."
evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: result[:model],
  decision_id: "loan_decision"
)
puts "✓ Evaluator created"
puts

# Step 3: Make decisions with different contexts
puts "Step 3: Making decisions..."
puts

# Test case 1: Excellent credit, high income
context1 = DecisionAgent::Context.new(
  credit_score: 800,
  income: 100_000
)
evaluation1 = evaluator.evaluate(context1)
puts "Test 1: Credit Score: 800, Income: $100,000"
puts "  Decision: #{evaluation1.decision}"
puts "  Weight: #{evaluation1.weight}"
puts "  Reason: #{evaluation1.reason}"
puts

# Test case 2: Good credit, moderate income
context2 = DecisionAgent::Context.new(
  credit_score: 680,
  income: 55_000
)
evaluation2 = evaluator.evaluate(context2)
puts "Test 2: Credit Score: 680, Income: $55,000"
puts "  Decision: #{evaluation2.decision}"
puts "  Weight: #{evaluation2.weight}"
puts "  Reason: #{evaluation2.reason}"
puts

# Test case 3: Low credit score
context3 = DecisionAgent::Context.new(
  credit_score: 580,
  income: 45_000
)
evaluation3 = evaluator.evaluate(context3)
puts "Test 3: Credit Score: 580, Income: $45,000"
puts "  Decision: #{evaluation3.decision}"
puts "  Weight: #{evaluation3.weight}"
puts "  Reason: #{evaluation3.reason}"
puts

puts "=" * 80
puts "Example complete!"
puts "=" * 80
