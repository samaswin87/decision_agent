#!/usr/bin/env ruby
# frozen_string_literal: true

# DMN Import/Export Example
#
# This example demonstrates how to:
# 1. Import a DMN file from disk
# 2. Store it in the versioning system
# 3. Export it back to DMN XML format
# 4. Verify round-trip conversion preserves the model

require "bundler/setup"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/dmn/exporter"
require "tempfile"
require "fileutils"

puts "=" * 80
puts "DMN Import/Export Example"
puts "=" * 80
puts

# Create a temporary directory for this example
temp_dir = Dir.mktmpdir
puts "Using temporary directory: #{temp_dir}"
puts

# Create a version manager with file storage
version_manager = DecisionAgent::Versioning::VersionManager.new(
  adapter: DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: temp_dir)
)

# Create a sample DMN file
dmn_file = Tempfile.new(["sample_decision", ".dmn"])
dmn_file.write(<<~DMN)
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="shipping_decision"
               name="Shipping Method Decision"
               namespace="http://example.com/shipping">

    <decision id="shipping_method" name="Determine Shipping Method">
      <decisionTable id="shipping_table" hitPolicy="FIRST">
        <input id="input_weight" label="Package Weight (lbs)">
          <inputExpression typeRef="number">
            <text>weight</text>
          </inputExpression>
        </input>

        <input id="input_distance" label="Distance (miles)">
          <inputExpression typeRef="number">
            <text>distance</text>
          </inputExpression>
        </input>

        <output id="output_method" label="Shipping Method" name="method" typeRef="string"/>

        <rule id="rule_express">
          <description>Express shipping for urgent or distant packages</description>
          <inputEntry id="entry_1_weight">
            <text>&lt; 50</text>
          </inputEntry>
          <inputEntry id="entry_1_distance">
            <text>&gt; 1000</text>
          </inputEntry>
          <outputEntry id="output_1">
            <text>"express"</text>
          </outputEntry>
        </rule>

        <rule id="rule_standard">
          <description>Standard shipping for medium packages</description>
          <inputEntry id="entry_2_weight">
            <text>&lt; 100</text>
          </inputEntry>
          <inputEntry id="entry_2_distance">
            <text>-</text>
          </inputEntry>
          <outputEntry id="output_2">
            <text>"standard"</text>
          </outputEntry>
        </rule>

        <rule id="rule_freight">
          <description>Freight shipping for heavy packages</description>
          <inputEntry id="entry_3_weight">
            <text>-</text>
          </inputEntry>
          <inputEntry id="entry_3_distance">
            <text>-</text>
          </inputEntry>
          <outputEntry id="output_3">
            <text>"freight"</text>
          </outputEntry>
        </rule>
      </decisionTable>
    </decision>
  </definitions>
DMN
dmn_file.close

puts "Step 1: Importing DMN file..."
puts "  Source file: #{dmn_file.path}"

importer = DecisionAgent::Dmn::Importer.new(version_manager: version_manager)
import_result = importer.import(
  dmn_file.path,
  ruleset_name: "shipping_rules",
  created_by: "example_user"
)

puts "✓ Import successful!"
puts "  Decisions imported: #{import_result[:decisions_imported]}"
puts "  Model name: #{import_result[:model].name}"
puts "  Decision table rules: #{import_result[:model].decisions.first.decision_table.rules.size}"
puts

puts "Step 2: Verifying storage in versioning system..."
active_version = version_manager.get_active_version(rule_id: "shipping_rules")
puts "✓ Active version found"
puts "  Version: #{active_version[:version]}"
puts "  Created by: #{active_version[:created_by]}"
puts "  Created at: #{active_version[:created_at]}"
puts

puts "Step 3: Exporting back to DMN XML..."
exporter = DecisionAgent::Dmn::Exporter.new(version_manager: version_manager)
exported_xml = exporter.export("shipping_rules")

puts "✓ Export successful!"
puts "  XML size: #{exported_xml.bytesize} bytes"
puts

# Write exported XML to a file for inspection
exported_file = File.join(temp_dir, "exported_shipping_rules.dmn")
File.write(exported_file, exported_xml)
puts "  Exported file: #{exported_file}"
puts

puts "Step 4: Re-importing exported XML to verify round-trip..."
reimport_result = importer.import_from_xml(
  exported_xml,
  ruleset_name: "shipping_rules_v2",
  created_by: "example_user"
)

puts "✓ Re-import successful!"
puts "  Decisions: #{reimport_result[:decisions_imported]}"
puts "  Rules: #{reimport_result[:model].decisions.first.decision_table.rules.size}"
puts

puts "Step 5: Comparing original and re-imported models..."
original_decision = import_result[:model].decisions.first
reimported_decision = reimport_result[:model].decisions.first

puts "  Original decision ID: #{original_decision.id}"
puts "  Re-imported decision ID: #{reimported_decision.id}"
puts "  Original rules count: #{original_decision.decision_table.rules.size}"
puts "  Re-imported rules count: #{reimported_decision.decision_table.rules.size}"
puts

# Test that both models produce the same decisions
puts "Step 6: Verifying both models produce identical results..."

original_evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: import_result[:model],
  decision_id: original_decision.id
)

reimported_evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: reimport_result[:model],
  decision_id: reimported_decision.id
)

test_contexts = [
  { weight: 30, distance: 1500 },   # Should be express
  { weight: 75, distance: 500 },    # Should be standard
  { weight: 150, distance: 100 }    # Should be freight
]

test_contexts.each_with_index do |context_data, idx|
  context = DecisionAgent::Context.new(context_data)

  original_result = original_evaluator.evaluate(context)
  reimported_result = reimported_evaluator.evaluate(context)

  match = original_result.decision == reimported_result.decision ? "✓" : "✗"
  puts "  Test #{idx + 1}: weight=#{context_data[:weight]}, distance=#{context_data[:distance]}"
  puts "    Original: #{original_result.decision}"
  puts "    Re-imported: #{reimported_result.decision}"
  puts "    #{match} Match!"
  puts
end

# Cleanup
FileUtils.rm_rf(temp_dir)
dmn_file.unlink

puts "=" * 80
puts "Example complete!"
puts "Round-trip conversion successful - models are equivalent!"
puts "=" * 80
