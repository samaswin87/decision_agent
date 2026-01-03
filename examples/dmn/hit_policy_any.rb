#!/usr/bin/env ruby
# frozen_string_literal: true

# DMN ANY Hit Policy Example
#
# This example demonstrates the ANY hit policy, which requires all matching
# rules to have the same output. If multiple rules match with different outputs,
# an error is raised.
#
# Use ANY when:
# - Multiple rules might match
# - All matches should agree on the result
# - You want validation that rules are consistent

require "bundler/setup"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/evaluators/dmn_evaluator"

# Data validation using ANY hit policy
# Multiple validation rules can match, but they must all agree on validity
dmn_xml = <<~DMN
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="data_validation"
               name="Data Validation Decision"
               namespace="http://example.com/validation">

    <decision id="validation" name="Validate User Data">
      <decisionTable id="validation_table" hitPolicy="ANY">
        <input id="input_age" label="Age">
          <inputExpression typeRef="number">
            <text>age</text>
          </inputExpression>
        </input>

        <input id="input_email" label="Email Format Valid">
          <inputExpression typeRef="boolean">
            <text>email_valid</text>
          </inputExpression>
        </input>

        <input id="input_phone" label="Phone Format Valid">
          <inputExpression typeRef="boolean">
            <text>phone_valid</text>
          </inputExpression>
        </input>

        <output id="output_valid" label="Is Valid" name="valid" typeRef="boolean"/>

        <rule id="rule_valid_all">
          <description>All checks pass - valid</description>
          <inputEntry><text>&gt;= 18</text></inputEntry>
          <inputEntry><text>true</text></inputEntry>
          <inputEntry><text>true</text></inputEntry>
          <outputEntry><text>true</text></outputEntry>
        </rule>

        <rule id="rule_valid_age_email">
          <description>Age and email valid - valid</description>
          <inputEntry><text>&gt;= 18</text></inputEntry>
          <inputEntry><text>true</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>true</text></outputEntry>
        </rule>

        <rule id="rule_valid_age_phone">
          <description>Age and phone valid - valid</description>
          <inputEntry><text>&gt;= 18</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>true</text></inputEntry>
          <outputEntry><text>true</text></outputEntry>
        </rule>

        <rule id="rule_invalid_age">
          <description>Age too young - invalid</description>
          <inputEntry><text>&lt; 18</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>false</text></outputEntry>
        </rule>

        <rule id="rule_invalid_email">
          <description>Email invalid - invalid</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>false</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>false</text></outputEntry>
        </rule>

        <rule id="rule_invalid_phone">
          <description>Phone invalid - invalid</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>false</text></inputEntry>
          <outputEntry><text>false</text></outputEntry>
        </rule>
      </decisionTable>
    </decision>
  </definitions>
DMN

puts "=" * 80
puts "DMN ANY Hit Policy Example"
puts "=" * 80
puts
puts "ANY hit policy requires all matching rules to have the same output."
puts "If multiple rules match with different outputs, an error is raised."
puts

# Import the DMN model
importer = DecisionAgent::Dmn::Importer.new
result = importer.import_from_xml(dmn_xml, ruleset_name: "data_validation", created_by: "example_user")

evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: result[:model],
  decision_id: "validation"
)

puts "Test Cases: Valid Scenarios (all matching rules agree)"
puts "-" * 80

valid_test_cases = [
  {
    context: { age: 25, email_valid: true, phone_valid: true },
    description: "All valid - multiple rules match, all say 'true'"
  },
  {
    context: { age: 30, email_valid: true, phone_valid: false },
    description: "Age and email valid - matches rules that all say 'true'"
  },
  {
    context: { age: 20, email_valid: false, phone_valid: true },
    description: "Age and phone valid - matches rules that all say 'true'"
  },
  {
    context: { age: 15, email_valid: true, phone_valid: true },
    description: "Age invalid - matches rule that says 'false'"
  },
  {
    context: { age: 25, email_valid: false, phone_valid: true },
    description: "Email invalid - matches rule that says 'false'"
  }
]

valid_test_cases.each_with_index do |test_case, idx|
  context = DecisionAgent::Context.new(test_case[:context])
  evaluation = evaluator.evaluate(context)

  puts "Test #{idx + 1}: #{test_case[:description]}"
  puts "  Input: age=#{test_case[:context][:age]}, email=#{test_case[:context][:email_valid]}, phone=#{test_case[:context][:phone_valid]}"
  puts "  ✓ Result: #{evaluation.decision} (all matching rules agreed)"
  puts
end

puts "Error Case: Conflicting Rules"
puts "-" * 80
puts "If we had conflicting rules (e.g., one says valid=true, another says valid=false),"
puts "ANY policy would raise: InvalidDmnModelError"
puts "  'ANY hit policy requires all matching rules to have the same output'"
puts
puts "This ensures consistency - if multiple validation rules match,"
puts "they must all agree on whether the data is valid or not."
puts

puts "=" * 80
puts "Key Takeaways:"
puts "  • ANY ensures all matching rules have the same output"
puts "  • Perfect for validation where multiple checks must agree"
puts "  • Raises error if rules conflict - helps catch rule definition errors"
puts "  • Use when you want consistency validation across multiple matching rules"
puts "=" * 80

