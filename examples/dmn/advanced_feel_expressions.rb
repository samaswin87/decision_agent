#!/usr/bin/env ruby
# frozen_string_literal: true

# Advanced FEEL Expressions Example
#
# This example demonstrates advanced FEEL expression features:
# - Range expressions ([min..max], (min..max))
# - Don't care wildcards (-)
# - Complex comparisons
# - Multiple input conditions

require "bundler/setup"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/evaluators/dmn_evaluator"

# Insurance premium calculation with advanced FEEL expressions
dmn_xml = <<~DMN
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="insurance_premium"
               name="Insurance Premium Calculation"
               namespace="http://example.com/insurance">

    <decision id="premium" name="Calculate Premium">
      <decisionTable id="premium_table" hitPolicy="FIRST">
        <input id="input_age" label="Age">
          <inputExpression typeRef="number">
            <text>age</text>
          </inputExpression>
        </input>

        <input id="input_health" label="Health Score">
          <inputExpression typeRef="number">
            <text>health_score</text>
          </inputExpression>
        </input>

        <input id="input_coverage" label="Coverage Level">
          <inputExpression typeRef="string">
            <text>coverage_level</text>
          </inputExpression>
        </input>

        <output id="output_premium" label="Monthly Premium" name="premium" typeRef="number"/>
        <output id="output_category" label="Risk Category" name="category" typeRef="string"/>

        <!-- Range expressions: [18..30) means 18 <= age < 30 -->
        <rule id="rule_young_excellent">
          <description>Young adults (18-30) with excellent health</description>
          <inputEntry><text>[18..30)</text></inputEntry>
          <inputEntry><text>&gt;= 90</text></inputEntry>
          <inputEntry><text>"basic"</text></inputEntry>
          <outputEntry><text>50</text></outputEntry>
          <outputEntry><text>"low_risk"</text></outputEntry>
        </rule>

        <rule id="rule_young_good">
          <description>Young adults (18-30) with good health</description>
          <inputEntry><text>[18..30)</text></inputEntry>
          <inputEntry><text>[70..90)</text></inputEntry>
          <inputEntry><text>"basic"</text></inputEntry>
          <outputEntry><text>75</text></outputEntry>
          <outputEntry><text>"medium_risk"</text></outputEntry>
        </rule>

        <!-- Range with inclusive bounds: [30..50] means 30 <= age <= 50 -->
        <rule id="rule_middle_excellent">
          <description>Middle-aged (30-50) with excellent health</description>
          <inputEntry><text>[30..50]</text></inputEntry>
          <inputEntry><text>&gt;= 90</text></inputEntry>
          <inputEntry><text>"basic"</text></inputEntry>
          <outputEntry><text>80</text></outputEntry>
          <outputEntry><text>"low_risk"</text></outputEntry>
        </rule>

        <!-- Don't care wildcard: - means any value -->
        <rule id="rule_premium_coverage">
          <description>Premium coverage for any age/health</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>"premium"</text></inputEntry>
          <outputEntry><text>200</text></outputEntry>
          <outputEntry><text>"premium"</text></outputEntry>
        </rule>

        <!-- Complex condition: age >= 50 with any health -->
        <rule id="rule_senior">
          <description>Seniors (50+) with any health score</description>
          <inputEntry><text>&gt;= 50</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>"basic"</text></inputEntry>
          <outputEntry><text>150</text></outputEntry>
          <outputEntry><text>"high_risk"</text></outputEntry>
        </rule>

        <!-- Default case: low health score regardless of age -->
        <rule id="rule_low_health">
          <description>Low health score (any age)</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>&lt; 70</text></inputEntry>
          <inputEntry><text>"basic"</text></inputEntry>
          <outputEntry><text>180</text></outputEntry>
          <outputEntry><text>"high_risk"</text></outputEntry>
        </rule>
      </decisionTable>
    </decision>
  </definitions>
DMN

puts "=" * 80
puts "Advanced FEEL Expressions Example"
puts "=" * 80
puts
puts "Demonstrating:"
puts "  • Range expressions: [min..max] (inclusive), [min..max) (exclusive end)"
puts "  • Don't care wildcards: - (matches any value)"
puts "  • Complex comparisons: >=, <, combined conditions"
puts

# Import the DMN model
importer = DecisionAgent::Dmn::Importer.new
result = importer.import_from_xml(dmn_xml, ruleset_name: "insurance_premium", created_by: "example_user")

evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: result[:model],
  decision_id: "premium"
)

puts "Test Cases: Range Expressions and Wildcards"
puts "-" * 80

test_cases = [
  {
    context: { age: 25, health_score: 95, coverage_level: "basic" },
    description: "Age 25 (in range [18..30)), excellent health (>= 90)"
  },
  {
    context: { age: 25, health_score: 75, coverage_level: "basic" },
    description: "Age 25 (in range [18..30)), good health ([70..90))"
  },
  {
    context: { age: 40, health_score: 92, coverage_level: "basic" },
    description: "Age 40 (in range [30..50]), excellent health (>= 90)"
  },
  {
    context: { age: 35, health_score: 85, coverage_level: "premium" },
    description: "Premium coverage (wildcards match any age/health)"
  },
  {
    context: { age: 55, health_score: 80, coverage_level: "basic" },
    description: "Senior (>= 50) with any health (wildcard)"
  },
  {
    context: { age: 30, health_score: 65, coverage_level: "basic" },
    description: "Low health score (< 70) regardless of age (wildcard)"
  }
]

test_cases.each_with_index do |test_case, idx|
  context = DecisionAgent::Context.new(test_case[:context])
  evaluation = evaluator.evaluate(context)

  puts "Test #{idx + 1}: #{test_case[:description]}"
  puts "  Input: age=#{test_case[:context][:age]}, health=#{test_case[:context][:health_score]}, coverage=#{test_case[:context][:coverage_level]}"
  puts "  ✓ Premium: $#{evaluation.decision}"
  puts "  ✓ Category: #{evaluation.metadata[:outputs][:category]}" if evaluation.metadata && evaluation.metadata[:outputs]
  puts
end

puts "=" * 80
puts "FEEL Expression Reference:"
puts
puts "Range Expressions:"
puts "  [18..30]  - Inclusive: 18 <= value <= 30"
puts "  [18..30)  - Half-open: 18 <= value < 30"
puts "  (18..30)  - Exclusive: 18 < value < 30"
puts
puts "Comparisons:"
puts "  >= 90     - Greater than or equal to 90"
puts "  < 70      - Less than 70"
puts "  > 50      - Greater than 50"
puts "  = value   - Equal to value"
puts
puts "Wildcards:"
puts "  -         - Don't care (matches any value)"
puts
puts "String Literals:"
puts "  \"basic\"   - String value (quotes required in DMN XML)"
puts "=" * 80

