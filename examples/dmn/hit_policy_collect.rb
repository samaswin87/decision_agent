#!/usr/bin/env ruby
# frozen_string_literal: true

# DMN COLLECT Hit Policy Example
#
# This example demonstrates the COLLECT hit policy, which returns all
# matching rules. The first match is returned as the decision, with
# metadata about all matches available.
#
# Use COLLECT when:
# - Multiple rules might match
# - You want to know all matching rules
# - You need to process multiple recommendations or results

require "bundler/setup"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/evaluators/dmn_evaluator"

# Product recommendations using COLLECT hit policy
# Multiple products can match based on user preferences
dmn_xml = <<~DMN
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="product_recommendations"
               name="Product Recommendation Decision"
               namespace="http://example.com/recommendations">

    <decision id="recommendations" name="Get Product Recommendations">
      <decisionTable id="recommendation_table" hitPolicy="COLLECT">
        <input id="input_budget" label="Budget">
          <inputExpression typeRef="number">
            <text>budget</text>
          </inputExpression>
        </input>

        <input id="input_category" label="Category Preference">
          <inputExpression typeRef="string">
            <text>category</text>
          </inputExpression>
        </input>

        <output id="output_product" label="Recommended Product" name="product" typeRef="string"/>

        <rule id="rule_laptop_basic">
          <description>Basic laptop for budget under $500</description>
          <inputEntry><text>&lt; 500</text></inputEntry>
          <inputEntry><text>"electronics"</text></inputEntry>
          <outputEntry><text>"Basic Laptop"</text></outputEntry>
        </rule>

        <rule id="rule_laptop_premium">
          <description>Premium laptop for budget over $1000</description>
          <inputEntry><text>&gt;= 1000</text></inputEntry>
          <inputEntry><text>"electronics"</text></inputEntry>
          <outputEntry><text>"Premium Laptop"</text></outputEntry>
        </rule>

        <rule id="rule_tablet">
          <description>Tablet for budget $300-$800</description>
          <inputEntry><text>[300..800]</text></inputEntry>
          <inputEntry><text>"electronics"</text></inputEntry>
          <outputEntry><text>"Tablet"</text></outputEntry>
        </rule>

        <rule id="rule_book_fiction">
          <description>Fiction books for any budget</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>"books"</text></inputEntry>
          <outputEntry><text>"Fiction Book"</text></outputEntry>
        </rule>

        <rule id="rule_book_tech">
          <description>Tech books for any budget</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>"books"</text></inputEntry>
          <outputEntry><text>"Tech Book"</text></outputEntry>
        </rule>
      </decisionTable>
    </decision>
  </definitions>
DMN

puts "=" * 80
puts "DMN COLLECT Hit Policy Example"
puts "=" * 80
puts
puts "COLLECT hit policy returns all matching rules."
puts "The first match is the decision, but metadata includes all matches."
puts

# Import the DMN model
importer = DecisionAgent::Dmn::Importer.new
result = importer.import_from_xml(dmn_xml, ruleset_name: "product_recommendations", created_by: "example_user")

evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: result[:model],
  decision_id: "recommendations"
)

puts "Test Cases: Multiple Matching Rules"
puts "-" * 80

test_cases = [
  {
    context: { budget: 400, category: "electronics" },
    description: "Budget $400, electronics - matches basic laptop"
  },
  {
    context: { budget: 1200, category: "electronics" },
    description: "Budget $1200, electronics - matches premium laptop"
  },
  {
    context: { budget: 600, category: "electronics" },
    description: "Budget $600, electronics - matches tablet"
  },
  {
    context: { budget: 50, category: "books" },
    description: "Budget $50, books - matches both book rules (2 matches)"
  },
  {
    context: { budget: 800, category: "electronics" },
    description: "Budget $800, electronics - matches tablet and premium laptop (2 matches)"
  }
]

test_cases.each_with_index do |test_case, idx|
  context = DecisionAgent::Context.new(test_case[:context])
  evaluation = evaluator.evaluate(context)

  puts "Test #{idx + 1}: #{test_case[:description]}"
  puts "  Input: budget=$#{test_case[:context][:budget]}, category=#{test_case[:context][:category]}"
  puts "  Primary Decision: #{evaluation.decision}"
  
  if evaluation.metadata && evaluation.metadata[:collect_count]
    puts "  Total Matches: #{evaluation.metadata[:collect_count]}"
    puts "  All Recommendations: #{evaluation.metadata[:collect_decisions].join(', ')}"
    puts "  Matched Rule IDs: #{evaluation.metadata[:collect_rule_ids].join(', ')}"
  end
  puts
end

puts "=" * 80
puts "Key Takeaways:"
puts "  • COLLECT returns all matching rules, not just the first"
puts "  • Primary decision is the first match, but all matches are in metadata"
puts "  • Perfect for recommendations, multi-select scenarios, or when you need all options"
puts "  • Use metadata[:collect_count], [:collect_decisions], [:collect_rule_ids] to access all matches"
puts "=" * 80

