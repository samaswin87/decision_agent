require "nokogiri"
require "set"
require_relative "errors"
require_relative "../versioning/version_manager"

module DecisionAgent
  module Dmn
    # Exports DecisionAgent rules to DMN XML format
    class Exporter
      def initialize(version_manager: nil)
        @version_manager = version_manager || Versioning::VersionManager.new
      end

      # Export ruleset to DMN XML
      # @param rule_id [String] Rule ID to export
      # @param output_path [String, nil] Optional file path to write
      # @return [String] DMN XML content
      def export(rule_id, output_path: nil)
        # Get active version
        version = @version_manager.get_active_version(rule_id: rule_id)
        raise InvalidDmnModelError, "No active version found for '#{rule_id}'" unless version

        # Convert JSON rules to DMN
        dmn_xml = convert_to_dmn(version[:content], rule_id)

        # Write to file if path provided
        File.write(output_path, dmn_xml) if output_path

        dmn_xml
      end

      private

      # Helper to get hash value with both string and symbol key support
      def hash_get(hash, key)
        hash[key.to_s] || hash[key.to_sym]
      end

      def convert_to_dmn(rules_json, rule_id)
        # Handle both string and symbol keys
        ruleset_name = rules_json["ruleset"] || rules_json[:ruleset] || rule_id
        rules = rules_json["rules"] || rules_json[:rules] || []

        builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
          xml.definitions(
            "xmlns" => "https://www.omg.org/spec/DMN/20191111/MODEL/",
            "xmlns:dmndi" => "https://www.omg.org/spec/DMN/20191111/DMNDI/",
            "xmlns:dc" => "http://www.omg.org/spec/DMN/20180521/DC/",
            "id" => "definitions_#{rule_id}",
            "name" => ruleset_name,
            "namespace" => "http://decision_agent.local"
          ) do
            xml.decision(id: rule_id, name: ruleset_name) do
              xml.decisionTable(
                id: "#{rule_id}_table",
                hitPolicy: "FIRST",
                outputLabel: "decision"
              ) do
                # Extract unique inputs from rules
                inputs = extract_inputs(rules)
                inputs.each_with_index do |input, idx|
                  xml.input(id: "input_#{idx + 1}", label: input) do
                    xml.inputExpression(typeRef: "string") do
                      text_node = Nokogiri::XML::Node.new("text", xml.doc)
                      text_node.content = input
                      xml.parent.add_child(text_node)
                    end
                  end
                end

                # Single output for decision
                xml.output(id: "output_1", label: "decision", name: "decision", typeRef: "string")

                # Convert rules
                rules.each_with_index do |rule, idx|
                  convert_rule_to_xml(xml, rule, inputs, idx)
                end
              end
            end
          end
        end

        builder.to_xml
      end

      def extract_inputs(rules)
        # Extract all unique field names used in conditions
        inputs = Set.new

        return [] unless rules.is_a?(Array)

        rules.each do |rule|
          condition = hash_get(rule, "if")
          extract_fields_from_condition(condition, inputs)
        end

        inputs.to_a.sort
      end

      def extract_fields_from_condition(condition, inputs)
        return unless condition.is_a?(Hash)

        if hash_get(condition, "field")
          inputs << hash_get(condition, "field")
        elsif hash_get(condition, "all")
          hash_get(condition, "all").each { |c| extract_fields_from_condition(c, inputs) }
        elsif hash_get(condition, "any")
          hash_get(condition, "any").each { |c| extract_fields_from_condition(c, inputs) }
        end
      end

      def convert_rule_to_xml(xml, rule, inputs, idx)
        rule_id = hash_get(rule, "id") || "rule_#{idx + 1}"
        xml.rule(id: rule_id) do
          # Input entries (in order of inputs array)
          inputs.each do |input_name|
            feel_expr = condition_to_feel(hash_get(rule, "if"), input_name)
            xml.inputEntry(id: "entry_#{idx + 1}_#{input_name}") do
              text_node = Nokogiri::XML::Node.new("text", xml.doc)
              text_node.content = feel_expr
              xml.parent.add_child(text_node)
            end
          end

          # Output entry
          then_clause = hash_get(rule, "then")
          decision_value = hash_get(then_clause, "decision") if then_clause
          xml.outputEntry(id: "output_#{idx + 1}") do
            text_node = Nokogiri::XML::Node.new("text", xml.doc)
            text_node.content = format_feel_value(decision_value)
            xml.parent.add_child(text_node)
          end

          # Description
          reason = hash_get(then_clause, "reason") if then_clause
          description = hash_get(rule, "description")
          if reason || description
            xml.description do
              xml.text reason || description
            end
          end
        end
      end

      def condition_to_feel(condition, target_field)
        return "-" unless condition.is_a?(Hash)

        # Find condition for this field
        field_condition = find_field_condition(condition, target_field)
        return "-" unless field_condition

        # Convert operator and value to FEEL
        op = hash_get(field_condition, "op")
        value = hash_get(field_condition, "value")

        convert_operator_to_feel(op, value)
      end

      def find_field_condition(condition, target_field)
        if hash_get(condition, "field") == target_field
          condition
        elsif hash_get(condition, "all")
          hash_get(condition, "all").each do |c|
            result = find_field_condition(c, target_field)
            return result if result
          end
          nil
        elsif hash_get(condition, "any")
          # For export, we pick first matching (Phase 2A limitation)
          hash_get(condition, "any").each do |c|
            result = find_field_condition(c, target_field)
            return result if result
          end
          nil
        end
      end

      def convert_operator_to_feel(op, value)
        case op
        when "eq"
          format_feel_value(value)
        when "neq"
          "!= #{format_feel_value(value)}"
        when "gt"
          "> #{format_feel_value(value)}"
        when "gte"
          ">= #{format_feel_value(value)}"
        when "lt"
          "< #{format_feel_value(value)}"
        when "lte"
          "<= #{format_feel_value(value)}"
        when "in"
          "[#{value.map { |v| format_feel_value(v) }.join(', ')}]"
        when "between"
          "[#{value[0]}..#{value[1]}]"
        else
          format_feel_value(value)
        end
      end

      def format_feel_value(value)
        case value
        when String
          "\"#{value}\""
        when Numeric
          value.to_s
        when TrueClass, FalseClass
          value.to_s
        else
          value.to_s
        end
      end
    end
  end
end
