require_relative "feel/evaluator"

module DecisionAgent
  module Dmn
    # Converts DMN decision tables to DecisionAgent JSON rule format
    class Adapter
      def initialize(decision_table)
        @table = decision_table
        @feel = Feel::Evaluator.new
      end

      # Convert DMN decision table to JSON rules
      def to_json_rules
        {
          "version" => "1.0",
          "ruleset" => @table.id,
          "description" => "Converted from DMN decision table",
          "rules" => convert_rules
        }
      end

      private

      def convert_rules
        @table.rules.map.with_index do |rule, idx|
          convert_rule(rule, idx)
        end
      end

      def convert_rule(rule, idx)
        {
          "id" => rule.id || "rule_#{idx + 1}",
          "if" => build_condition(rule),
          "then" => build_output(rule),
          "description" => rule.description
        }.compact
      end

      def build_condition(rule)
        # Build 'all' condition combining all input entries
        conditions = []

        rule.input_entries.each_with_index do |entry, idx|
          next if entry == "-" # Skip "don't care" entries

          input = @table.inputs[idx]
          condition = convert_feel_to_condition(entry, input.expression || input.label)
          conditions << condition if condition
        end

        # If no conditions, return a condition that always matches
        return { "all" => [] } if conditions.empty?

        # If only one condition, return it directly
        return conditions.first if conditions.size == 1

        # Otherwise, wrap in 'all'
        { "all" => conditions }
      end

      def convert_feel_to_condition(feel_expression, field_name)
        parsed = @feel.parse_expression(feel_expression)

        {
          "field" => field_name,
          "op" => parsed[:operator],
          "value" => parsed[:value]
        }
      rescue StandardError => e
        # Log warning and skip invalid expressions
        warn "Warning: Could not parse FEEL expression '#{feel_expression}': #{e.message}"
        nil
      end

      def build_output(rule)
        # For Phase 2A, we take the first output as the decision
        # Multi-output support in Phase 2B
        output_value = rule.output_entries.first

        # Parse FEEL expression in output value (remove quotes from string literals)
        parsed_value = parse_output_value(output_value)

        # Ensure we always have a decision value
        parsed_value = "" if parsed_value.nil?

        {
          "decision" => parsed_value,
          "weight" => 1.0,
          "reason" => rule.description || "DMN rule #{rule.id} matched"
        }
      end

      def parse_output_value(value)
        # Handle nil values
        return nil if value.nil?

        # If already not a string, return as-is (number, boolean, etc.)
        return value unless value.is_a?(String)

        value_str = value.to_s.strip

        # Return nil for empty strings
        return nil if value_str.empty?

        # Remove quotes from string literals
        if value_str.start_with?('"') && value_str.end_with?('"')
          return value_str[1..-2]
        end

        # Try to parse as number
        if value_str.match?(/^-?\d+\.\d+$/)
          return value_str.to_f
        elsif value_str.match?(/^-?\d+$/)
          return value_str.to_i
        end

        # Boolean
        return true if value_str.downcase == "true"
        return false if value_str.downcase == "false"

        # Return as-is (unquoted string)
        value_str
      end
    end
  end
end
