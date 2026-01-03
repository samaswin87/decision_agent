#!/usr/bin/env ruby
# frozen_string_literal: true

# DMN UNIQUE Hit Policy Example
#
# This example demonstrates the UNIQUE hit policy, which requires exactly
# one rule to match. If zero or multiple rules match, an error is raised.
#
# Use UNIQUE when:
# - Rules should be mutually exclusive (e.g., tax brackets)
# - You want to ensure exactly one rule matches
# - You need strict validation of rule coverage

require "bundler/setup"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/evaluators/dmn_evaluator"

# Tax bracket decision table using UNIQUE hit policy
# Each income range should match exactly one tax bracket
dmn_xml = <<~DMN
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="tax_brackets"
               name="Tax Bracket Determination"
               namespace="http://example.com/tax">

    <decision id="tax_bracket" name="Determine Tax Bracket">
      <decisionTable id="tax_table" hitPolicy="UNIQUE">
        <input id="input_income" label="Annual Income">
          <inputExpression typeRef="number">
            <text>income</text>
          </inputExpression>
        </input>

        <output id="output_bracket" label="Tax Bracket" name="bracket" typeRef="string"/>
        <output id="output_rate" label="Tax Rate" name="rate" typeRef="number"/>

        <rule id="rule_10">
          <description>10% bracket: $0 to $10,000</description>
          <inputEntry><text>[0..10000)</text></inputEntry>
          <outputEntry><text>"10%"</text></outputEntry>
          <outputEntry><text>0.10</text></outputEntry>
        </rule>

        <rule id="rule_15">
          <description>15% bracket: $10,000 to $40,000</description>
          <inputEntry><text>[10000..40000)</text></inputEntry>
          <outputEntry><text>"15%"</text></outputEntry>
          <outputEntry><text>0.15</text></outputEntry>
        </rule>

        <rule id="rule_25">
          <description>25% bracket: $40,000 to $85,000</description>
          <inputEntry><text>[40000..85000)</text></inputEntry>
          <outputEntry><text>"25%"</text></outputEntry>
          <outputEntry><text>0.25</text></outputEntry>
        </rule>

        <rule id="rule_35">
          <description>35% bracket: $85,000 and above</description>
          <inputEntry><text>&gt;= 85000</text></inputEntry>
          <outputEntry><text>"35%"</text></outputEntry>
          <outputEntry><text>0.35</text></outputEntry>
        </rule>
      </decisionTable>
    </decision>
  </definitions>
DMN

puts "=" * 80
puts "DMN UNIQUE Hit Policy Example"
puts "=" * 80
puts
puts "UNIQUE hit policy ensures exactly one rule matches."
puts "If zero or multiple rules match, an error is raised."
puts

# Import the DMN model
importer = DecisionAgent::Dmn::Importer.new
result = importer.import_from_xml(dmn_xml, ruleset_name: "tax_brackets", created_by: "example_user")

evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: result[:model],
  decision_id: "tax_bracket"
)

puts "Step 1: Valid matches (exactly one rule matches)"
puts "-" * 80

test_cases = [
  { income: 5_000, expected_bracket: "10%" },
  { income: 25_000, expected_bracket: "15%" },
  { income: 60_000, expected_bracket: "25%" },
  { income: 100_000, expected_bracket: "35%" }
]

test_cases.each_with_index do |test_case, idx|
  context = DecisionAgent::Context.new(income: test_case[:income])
  evaluation = evaluator.evaluate(context)

  puts "Test #{idx + 1}: Income = $#{test_case[:income].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  puts "  ✓ Matched exactly one rule"
  puts "  Tax Bracket: #{evaluation.decision}"
  puts "  Rule ID: #{evaluation.metadata[:rule_id]}" if evaluation.metadata[:rule_id]
  puts
end

puts "Step 2: Error cases (demonstrating UNIQUE validation)"
puts "-" * 80

# Note: The current rules cover all cases, so we'll show what happens
# if we had a gap in coverage (which would cause an error)
puts "If income doesn't match any rule (e.g., negative income),"
puts "UNIQUE policy would raise: InvalidDmnModelError"
puts "  'UNIQUE hit policy requires exactly one matching rule, but none matched'"
puts

puts "If multiple rules could match (overlapping ranges),"
puts "UNIQUE policy would raise: InvalidDmnModelError"
puts "  'UNIQUE hit policy requires exactly one matching rule, but N matched'"
puts

puts "=" * 80
puts "Key Takeaways:"
puts "  • UNIQUE ensures exactly one rule matches - great for mutually exclusive rules"
puts "  • Use for tax brackets, status classifications, or any exclusive categories"
puts "  • Provides built-in validation that rules are properly defined"
puts "  • Raises errors if rules overlap or have gaps"
puts "=" * 80

