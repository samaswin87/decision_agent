#!/usr/bin/env ruby
# frozen_string_literal: true

# DMN Error Handling Patterns Example
#
# This example demonstrates error handling with different hit policies:
# - UNIQUE: Errors when no rules match or multiple rules match
# - ANY: Errors when matching rules have conflicting outputs
# - How to handle and recover from these errors

require "bundler/setup"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/evaluators/dmn_evaluator"

puts "=" * 80
puts "DMN Error Handling Patterns Example"
puts "=" * 80
puts

# Example 1: UNIQUE hit policy errors
puts "Example 1: UNIQUE Hit Policy Error Handling"
puts "-" * 80

unique_dmn = <<~DMN
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="unique_example"
               name="UNIQUE Error Example"
               namespace="http://example.com/errors">

    <decision id="status" name="Determine Status">
      <decisionTable id="status_table" hitPolicy="UNIQUE">
        <input id="input_value" label="Value">
          <inputExpression typeRef="number">
            <text>value</text>
          </inputExpression>
        </input>

        <output id="output_status" label="Status" name="status" typeRef="string"/>

        <rule id="rule_high">
          <description>High value range</description>
          <inputEntry><text>&gt;= 100</text></inputEntry>
          <outputEntry><text>"high"</text></outputEntry>
        </rule>

        <rule id="rule_medium">
          <description>Medium value range</description>
          <inputEntry><text>[50..100)</text></inputEntry>
          <outputEntry><text>"medium"</text></outputEntry>
        </rule>

        <!-- Note: No rule for values < 50 - this creates a gap -->
      </decisionTable>
    </decision>
  </definitions>
DMN

importer = DecisionAgent::Dmn::Importer.new
unique_result = importer.import_from_xml(unique_dmn, ruleset_name: "unique_example", created_by: "example_user")

unique_evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: unique_result[:model],
  decision_id: "status"
)

# Test valid case
puts "Valid case: value = 75 (matches exactly one rule)"
begin
  context = DecisionAgent::Context.new(value: 75)
  evaluation = unique_evaluator.evaluate(context)
  puts "  ✓ Success: #{evaluation.decision}"
rescue DecisionAgent::Dmn::InvalidDmnModelError => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test error case: no rules match
puts "Error case: value = 25 (no rules match - gap in coverage)"
begin
  context = DecisionAgent::Context.new(value: 25)
  evaluation = unique_evaluator.evaluate(context)
  puts "  ✓ Success: #{evaluation.decision}"
rescue DecisionAgent::Dmn::InvalidDmnModelError => e
  puts "  ✗ Error caught: #{e.message}"
  puts "  → This indicates a gap in rule coverage that should be fixed"
end
puts

# Example 2: ANY hit policy errors
puts "Example 2: ANY Hit Policy Error Handling"
puts "-" * 80

any_dmn = <<~DMN
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="any_example"
               name="ANY Error Example"
               namespace="http://example.com/errors">

    <decision id="validation" name="Validate Data">
      <decisionTable id="validation_table" hitPolicy="ANY">
        <input id="input_field1" label="Field 1 Valid">
          <inputExpression typeRef="boolean">
            <text>field1_valid</text>
          </inputExpression>
        </input>

        <input id="input_field2" label="Field 2 Valid">
          <inputExpression typeRef="boolean">
            <text>field2_valid</text>
          </inputExpression>
        </input>

        <output id="output_valid" label="Is Valid" name="valid" typeRef="boolean"/>

        <rule id="rule_both_valid">
          <description>Both fields valid</description>
          <inputEntry><text>true</text></inputEntry>
          <inputEntry><text>true</text></inputEntry>
          <outputEntry><text>true</text></outputEntry>
        </rule>

        <rule id="rule_field1_valid">
          <description>Field 1 valid</description>
          <inputEntry><text>true</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>true</text></outputEntry>
        </rule>

        <!-- Conflicting rule: same conditions but different output -->
        <rule id="rule_field2_invalid">
          <description>Field 2 invalid</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>false</text></inputEntry>
          <outputEntry><text>false</text></outputEntry>
        </rule>
      </decisionTable>
    </decision>
  </definitions>
DMN

any_result = importer.import_from_xml(any_dmn, ruleset_name: "any_example", created_by: "example_user")

any_evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: any_result[:model],
  decision_id: "validation"
)

# Test valid case: all matching rules agree
puts "Valid case: field1=true, field2=true (all matching rules agree)"
begin
  context = DecisionAgent::Context.new(field1_valid: true, field2_valid: true)
  evaluation = any_evaluator.evaluate(context)
  puts "  ✓ Success: #{evaluation.decision}"
rescue DecisionAgent::Dmn::InvalidDmnModelError => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test error case: conflicting outputs
puts "Error case: field1=true, field2=false (conflicting rules)"
begin
  context = DecisionAgent::Context.new(field1_valid: true, field2_valid: false)
  evaluation = any_evaluator.evaluate(context)
  puts "  ✓ Success: #{evaluation.decision}"
rescue DecisionAgent::Dmn::InvalidDmnModelError => e
  puts "  ✗ Error caught: #{e.message}"
  puts "  → This indicates conflicting rule definitions that need to be resolved"
end
puts

# Example 3: Error handling best practices
puts "Example 3: Error Handling Best Practices"
puts "-" * 80
puts
puts "When handling DMN evaluation errors:"
puts
puts "1. UNIQUE Policy Errors:"
puts "   • No match: Add a catch-all rule or validate input ranges"
puts "   • Multiple matches: Make rules mutually exclusive"
puts
puts "2. ANY Policy Errors:"
puts "   • Conflicting outputs: Review rule logic, ensure consistency"
puts "   • Use for validation where all checks must agree"
puts
puts "3. General Error Handling:"
puts "   • Always wrap evaluate() calls in begin/rescue blocks"
puts "   • Log errors for debugging and rule improvement"
puts "   • Provide fallback behavior when rules fail"
puts "   • Use error messages to identify rule definition issues"
puts

puts "=" * 80
puts "Key Takeaways:"
puts "  • UNIQUE and ANY policies provide built-in validation"
puts "  • Errors indicate rule definition problems, not just execution failures"
puts "  • Use error handling to catch gaps, overlaps, or conflicts in rules"
puts "  • Error messages help identify and fix rule definition issues"
puts "=" * 80

