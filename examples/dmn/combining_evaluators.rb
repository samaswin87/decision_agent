#!/usr/bin/env ruby
# frozen_string_literal: true

# Combining DMN and JSON Evaluators Example
#
# This example demonstrates how to:
# 1. Use DMN evaluators alongside JSON rule evaluators in the same agent
# 2. Leverage different evaluator types for different decision aspects
# 3. Combine decisions from multiple sources

require "bundler/setup"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/evaluators/dmn_evaluator"
require "decision_agent/evaluators/json_rule_evaluator"

puts "=" * 80
puts "Combining DMN and JSON Evaluators Example"
puts "=" * 80
puts

# Create a DMN model for credit assessment
dmn_xml = <<~DMN
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="credit_assessment"
               name="Credit Risk Assessment"
               namespace="http://example.com/credit">

    <decision id="credit_risk" name="Credit Risk Level">
      <decisionTable id="credit_table" hitPolicy="FIRST">
        <input id="input_score" label="Credit Score">
          <inputExpression typeRef="number">
            <text>credit_score</text>
          </inputExpression>
        </input>

        <output id="output_risk" label="Risk Level" name="risk" typeRef="string"/>

        <rule id="rule_low">
          <inputEntry><text>&gt;= 700</text></inputEntry>
          <outputEntry><text>"low"</text></outputEntry>
        </rule>

        <rule id="rule_medium">
          <inputEntry><text>&gt;= 600</text></inputEntry>
          <outputEntry><text>"medium"</text></outputEntry>
        </rule>

        <rule id="rule_high">
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>"high"</text></outputEntry>
        </rule>
      </decisionTable>
    </decision>
  </definitions>
DMN

# Create JSON rules for business policy overrides
json_rules = {
  version: "1.0",
  ruleset: "business_policies",
  description: "Business policy overrides and special cases",
  rules: [
    {
      id: "vip_customer",
      if: { field: "customer_tier", op: "eq", value: "platinum" },
      then: {
        decision: "approve_vip",
        weight: 1.0,
        reason: "Platinum tier customers get automatic approval"
      }
    },
    {
      id: "fraud_flag",
      if: { field: "fraud_alert", op: "eq", value: true },
      then: {
        decision: "reject_fraud",
        weight: 1.0,
        reason: "Fraud alert triggered - automatic rejection"
      }
    },
    {
      id: "new_customer_promotion",
      if: {
        all: [
          { field: "customer_age_days", op: "lt", value: 30 },
          { field: "promotional_code", op: "eq", value: "NEWCUST2024" }
        ]
      },
      then: {
        decision: "approve_promotion",
        weight: 0.8,
        reason: "New customer promotion - conditional approval"
      }
    }
  ]
}

puts "Step 1: Creating DMN evaluator for credit risk..."
importer = DecisionAgent::Dmn::Importer.new
dmn_result = importer.import_from_xml(dmn_xml, ruleset_name: "credit_risk", created_by: "system")

dmn_evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: dmn_result[:model],
  decision_id: "credit_risk",
  name: "CreditRiskEvaluator"
)
puts "✓ DMN evaluator created"
puts

puts "Step 2: Creating JSON rule evaluator for business policies..."
json_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(
  rules_json: json_rules,
  name: "BusinessPolicyEvaluator"
)
puts "✓ JSON evaluator created"
puts

puts "Step 3: Creating agent with both evaluators..."
agent = DecisionAgent::Agent.new(
  evaluators: [dmn_evaluator, json_evaluator]
)
puts "✓ Agent created with #{agent.evaluators.size} evaluators"
puts

puts "=" * 80
puts "Test Cases"
puts "=" * 80
puts

# Test 1: VIP customer overrides credit risk
puts "Test 1: VIP Customer Override"
puts "  Credit score: 620 (medium risk)"
puts "  Customer tier: platinum"
puts

decision1 = agent.decide(
  context: {
    credit_score: 620,
    customer_tier: "platinum"
  }
)

puts "  Final Decision: #{decision1.decision}"
puts "  Evaluations:"
decision1.evaluations.each do |eval|
  puts "    - #{eval.evaluator_name}: #{eval.decision} (confidence: #{eval.confidence})"
  puts "      Reason: #{eval.explanations.first&.reason}"
end
puts

# Test 2: Fraud alert overrides everything
puts "Test 2: Fraud Alert"
puts "  Credit score: 750 (low risk)"
puts "  Customer tier: platinum"
puts "  Fraud alert: true"
puts

decision2 = agent.decide(
  context: {
    credit_score: 750,
    customer_tier: "platinum",
    fraud_alert: true
  }
)

puts "  Final Decision: #{decision2.decision}"
puts "  Evaluations:"
decision2.evaluations.each do |eval|
  puts "    - #{eval.evaluator_name}: #{eval.decision} (confidence: #{eval.confidence})"
  puts "      Reason: #{eval.explanations.first&.reason}"
end
puts

# Test 3: New customer promotion
puts "Test 3: New Customer Promotion"
puts "  Credit score: 680 (medium risk)"
puts "  Customer age: 15 days"
puts "  Promotional code: NEWCUST2024"
puts

decision3 = agent.decide(
  context: {
    credit_score: 680,
    customer_age_days: 15,
    promotional_code: "NEWCUST2024"
  }
)

puts "  Final Decision: #{decision3.decision}"
puts "  Evaluations:"
decision3.evaluations.each do |eval|
  puts "    - #{eval.evaluator_name}: #{eval.decision} (confidence: #{eval.confidence})"
  puts "      Reason: #{eval.explanations.first&.reason}"
end
puts

# Test 4: Standard credit assessment (no overrides)
puts "Test 4: Standard Assessment (No Overrides)"
puts "  Credit score: 720 (low risk)"
puts "  No special conditions"
puts

decision4 = agent.decide(
  context: {
    credit_score: 720
  }
)

puts "  Final Decision: #{decision4.decision}"
puts "  Evaluations:"
decision4.evaluations.each do |eval|
  puts "    - #{eval.evaluator_name}: #{eval.decision} (confidence: #{eval.confidence})"
  puts "      Reason: #{eval.explanations.first&.reason}"
end
puts

puts "=" * 80
puts "Example complete!"
puts
puts "Key Takeaways:"
puts "  • DMN evaluators excel at standardized decision tables and industry models"
puts "  • JSON evaluators are great for custom business logic and dynamic rules"
puts "  • Both can work together in the same agent for comprehensive decision making"
puts "  • The agent combines results from all evaluators based on confidence weights"
puts "=" * 80
