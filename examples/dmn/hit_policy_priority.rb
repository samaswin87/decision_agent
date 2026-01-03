#!/usr/bin/env ruby
# frozen_string_literal: true

# DMN PRIORITY Hit Policy Example
#
# This example demonstrates the PRIORITY hit policy, which returns the
# first matching rule (rules are ordered by priority, top-to-bottom).
#
# Use PRIORITY when:
# - Multiple rules might match
# - You want the highest priority match (first in table)
# - Rules have a clear precedence order

require "bundler/setup"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/evaluators/dmn_evaluator"

# Discount eligibility using PRIORITY hit policy
# Rules are ordered from highest priority (VIP) to lowest (standard)
dmn_xml = <<~DMN
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="discount_eligibility"
               name="Discount Eligibility Decision"
               namespace="http://example.com/pricing">

    <decision id="discount" name="Determine Discount">
      <decisionTable id="discount_table" hitPolicy="PRIORITY">
        <input id="input_tier" label="Customer Tier">
          <inputExpression typeRef="string">
            <text>customer_tier</text>
          </inputExpression>
        </input>

        <input id="input_purchase" label="Purchase Amount">
          <inputExpression typeRef="number">
            <text>purchase_amount</text>
          </inputExpression>
        </input>

        <output id="output_discount" label="Discount Percentage" name="discount" typeRef="number"/>

        <rule id="rule_vip">
          <description>VIP customers get 20% discount on any purchase</description>
          <inputEntry><text>"platinum"</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>0.20</text></outputEntry>
        </rule>

        <rule id="rule_gold_high">
          <description>Gold customers get 15% on purchases over $500</description>
          <inputEntry><text>"gold"</text></inputEntry>
          <inputEntry><text>&gt; 500</text></inputEntry>
          <outputEntry><text>0.15</text></outputEntry>
        </rule>

        <rule id="rule_gold_standard">
          <description>Gold customers get 10% on standard purchases</description>
          <inputEntry><text>"gold"</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>0.10</text></outputEntry>
        </rule>

        <rule id="rule_silver_high">
          <description>Silver customers get 10% on purchases over $300</description>
          <inputEntry><text>"silver"</text></inputEntry>
          <inputEntry><text>&gt; 300</text></inputEntry>
          <outputEntry><text>0.10</text></outputEntry>
        </rule>

        <rule id="rule_silver_standard">
          <description>Silver customers get 5% on standard purchases</description>
          <inputEntry><text>"silver"</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>0.05</text></outputEntry>
        </rule>

        <rule id="rule_standard">
          <description>Standard customers get 0% discount</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>0.00</text></outputEntry>
        </rule>
      </decisionTable>
    </decision>
  </definitions>
DMN

puts "=" * 80
puts "DMN PRIORITY Hit Policy Example"
puts "=" * 80
puts
puts "PRIORITY hit policy returns the first matching rule."
puts "Rules are evaluated top-to-bottom, so order matters!"
puts

# Import the DMN model
importer = DecisionAgent::Dmn::Importer.new
result = importer.import_from_xml(dmn_xml, ruleset_name: "discount_eligibility", created_by: "example_user")

evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: result[:model],
  decision_id: "discount"
)

puts "Test Cases: Demonstrating Priority Selection"
puts "-" * 80

test_cases = [
  {
    context: { customer_tier: "platinum", purchase_amount: 100 },
    description: "VIP customer - should get highest priority (20%)"
  },
  {
    context: { customer_tier: "gold", purchase_amount: 600 },
    description: "Gold customer, high purchase - matches both gold rules, gets first (15%)"
  },
  {
    context: { customer_tier: "gold", purchase_amount: 200 },
    description: "Gold customer, standard purchase - gets 10%"
  },
  {
    context: { customer_tier: "silver", purchase_amount: 400 },
    description: "Silver customer, high purchase - matches both silver rules, gets first (10%)"
  },
  {
    context: { customer_tier: "silver", purchase_amount: 100 },
    description: "Silver customer, standard purchase - gets 5%"
  },
  {
    context: { customer_tier: "standard", purchase_amount: 1000 },
    description: "Standard customer - gets 0% (catch-all rule)"
  }
]

test_cases.each_with_index do |test_case, idx|
  context = DecisionAgent::Context.new(test_case[:context])
  evaluation = evaluator.evaluate(context)

  discount_pct = (evaluation.decision * 100).round(0)
  puts "Test #{idx + 1}: #{test_case[:description]}"
  puts "  Input: tier=#{test_case[:context][:customer_tier]}, amount=$#{test_case[:context][:purchase_amount]}"
  puts "  ✓ Selected: #{discount_pct}% discount (rule: #{evaluation.metadata[:rule_id]})"
  puts
end

puts "=" * 80
puts "Key Takeaways:"
puts "  • PRIORITY returns the first matching rule (top-to-bottom order)"
puts "  • Perfect for tiered systems where higher tiers should take precedence"
puts "  • Multiple rules can match, but only the first (highest priority) is used"
puts "  • Rule order is critical - most specific/highest priority rules should be first"
puts "=" * 80

