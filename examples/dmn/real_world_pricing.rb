#!/usr/bin/env ruby
# frozen_string_literal: true

# Real-World Use Case: Dynamic Pricing Decision
#
# This example demonstrates a real-world e-commerce pricing scenario:
# - Customer segment-based pricing
# - Product category discounts
# - Volume-based pricing tiers
# - Promotional pricing overrides

require "bundler/setup"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/evaluators/dmn_evaluator"

# Dynamic pricing decision table
dmn_xml = <<~DMN
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="dynamic_pricing"
               name="Dynamic Pricing Decision"
               namespace="http://example.com/pricing">

    <decision id="pricing" name="Calculate Final Price">
      <decisionTable id="pricing_table" hitPolicy="PRIORITY">
        <input id="input_segment" label="Customer Segment">
          <inputExpression typeRef="string">
            <text>customer_segment</text>
          </inputExpression>
        </input>

        <input id="input_category" label="Product Category">
          <inputExpression typeRef="string">
            <text>product_category</text>
          </inputExpression>
        </input>

        <input id="input_quantity" label="Quantity">
          <inputExpression typeRef="number">
            <text>quantity</text>
          </inputExpression>
        </input>

        <input id="input_promo" label="Promotional Code">
          <inputExpression typeRef="string">
            <text>promo_code</text>
          </inputExpression>
        </input>

        <output id="output_discount" label="Discount Percentage" name="discount" typeRef="number"/>
        <output id="output_tier" label="Pricing Tier" name="tier" typeRef="string"/>

        <!-- VIP customers get best pricing -->
        <rule id="rule_vip_electronics">
          <description>VIP customers buying electronics</description>
          <inputEntry><text>"vip"</text></inputEntry>
          <inputEntry><text>"electronics"</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>0.25</text></outputEntry>
          <outputEntry><text>"vip"</text></outputEntry>
        </rule>

        <!-- Bulk pricing for high quantities -->
        <rule id="rule_bulk_electronics">
          <description>Bulk purchase of electronics (10+ units)</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>"electronics"</text></inputEntry>
          <inputEntry><text>&gt;= 10</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>0.20</text></outputEntry>
          <outputEntry><text>"bulk"</text></outputEntry>
        </rule>

        <!-- Promotional codes override standard pricing -->
        <rule id="rule_promo_summer">
          <description>Summer sale promotional code</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>"SUMMER2024"</text></inputEntry>
          <outputEntry><text>0.15</text></outputEntry>
          <outputEntry><text>"promotional"</text></outputEntry>
        </rule>

        <!-- Category-specific discounts -->
        <rule id="rule_books_standard">
          <description>Standard discount for books</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>"books"</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>0.10</text></outputEntry>
          <outputEntry><text>"standard"</text></outputEntry>
        </rule>

        <!-- Premium segment gets moderate discount -->
        <rule id="rule_premium">
          <description>Premium customers get standard discount</description>
          <inputEntry><text>"premium"</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>0.10</text></outputEntry>
          <outputEntry><text>"premium"</text></outputEntry>
        </rule>

        <!-- Default: no discount -->
        <rule id="rule_default">
          <description>Default pricing - no discount</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>0.00</text></outputEntry>
          <outputEntry><text>"standard"</text></outputEntry>
        </rule>
      </decisionTable>
    </decision>
  </definitions>
DMN

puts "=" * 80
puts "Real-World Use Case: Dynamic Pricing"
puts "=" * 80
puts
puts "This example shows how DMN can model complex business pricing rules:"
puts "  • Customer segment-based pricing (VIP, Premium, Standard)"
puts "  • Product category discounts (Electronics, Books)"
puts "  • Volume-based pricing (bulk discounts)"
puts "  • Promotional code overrides"
puts

# Import the DMN model
importer = DecisionAgent::Dmn::Importer.new
result = importer.import_from_xml(dmn_xml, ruleset_name: "dynamic_pricing", created_by: "example_user")

evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: result[:model],
  decision_id: "pricing"
)

puts "Pricing Scenarios"
puts "-" * 80

scenarios = [
  {
    context: { customer_segment: "vip", product_category: "electronics", quantity: 1, promo_code: "" },
    description: "VIP customer buying single electronics item"
  },
  {
    context: { customer_segment: "standard", product_category: "electronics", quantity: 15, promo_code: "" },
    description: "Standard customer buying bulk electronics (15 units)"
  },
  {
    context: { customer_segment: "standard", product_category: "books", quantity: 2, promo_code: "" },
    description: "Standard customer buying books"
  },
  {
    context: { customer_segment: "premium", product_category: "electronics", quantity: 1, promo_code: "" },
    description: "Premium customer buying electronics"
  },
  {
    context: { customer_segment: "standard", product_category: "electronics", quantity: 1, promo_code: "SUMMER2024" },
    description: "Standard customer with promotional code"
  },
  {
    context: { customer_segment: "standard", product_category: "clothing", quantity: 1, promo_code: "" },
    description: "Standard customer, no special category (default pricing)"
  }
]

scenarios.each_with_index do |scenario, idx|
  context = DecisionAgent::Context.new(scenario[:context])
  evaluation = evaluator.evaluate(context)

  discount_pct = (evaluation.decision * 100).round(0)
  tier = evaluation.metadata[:outputs][:tier] if evaluation.metadata && evaluation.metadata[:outputs]

  puts "Scenario #{idx + 1}: #{scenario[:description]}"
  puts "  Input: segment=#{scenario[:context][:customer_segment]}, category=#{scenario[:context][:product_category]}, qty=#{scenario[:context][:quantity]}, promo=#{scenario[:context][:promo_code].empty? ? 'none' : scenario[:context][:promo_code]}"
  puts "  ✓ Discount: #{discount_pct}%"
  puts "  ✓ Tier: #{tier}"
  puts
end

puts "=" * 80
puts "Business Benefits:"
puts "  • Business analysts can modify pricing rules without code changes"
puts "  • Rules are visible, auditable, and version-controlled"
puts "  • Complex pricing logic is centralized and maintainable"
puts "  • Easy to test different pricing scenarios"
puts "=" * 80

