require_relative "errors"

module DecisionAgent
  module Dmn
    # Validates DMN model structure and semantics
    class Validator
      def initialize(model)
        @model = model
        @errors = []
      end

      def validate!
        validate_model
        validate_decisions

        if @errors.any?
          raise InvalidDmnModelError, format_errors
        end

        true
      end

      private

      def validate_model
        @errors << "Model must have an ID" if @model.id.empty?
        @errors << "Model must have a name" if @model.name.empty?
        @errors << "Model must have at least one decision" if @model.decisions.empty?
      end

      def validate_decisions
        @model.decisions.each_with_index do |decision, idx|
          validate_decision(decision, idx)
        end
      end

      def validate_decision(decision, idx)
        path = "Decision[#{idx}](#{decision.id})"

        @errors << "#{path}: Decision must have an ID" if decision.id.empty?
        @errors << "#{path}: Decision must have a name" if decision.name.empty?

        if decision.decision_table
          validate_decision_table(decision.decision_table, path)
        else
          @errors << "#{path}: Decision must have a decision table"
        end
      end

      def validate_decision_table(table, path)
        @errors << "#{path}: Decision table must have at least one input" if table.inputs.empty?
        @errors << "#{path}: Decision table must have at least one output" if table.outputs.empty?
        @errors << "#{path}: Decision table must have at least one rule" if table.rules.empty?

        # Validate each rule has correct number of entries
        table.rules.each_with_index do |rule, idx|
          validate_rule(rule, table, "#{path}.Rule[#{idx}]")
        end
      end

      def validate_rule(rule, table, path)
        expected_inputs = table.inputs.size
        expected_outputs = table.outputs.size

        if rule.input_entries.size != expected_inputs
          @errors << "#{path}: Expected #{expected_inputs} input entries, " \
                     "got #{rule.input_entries.size}"
        end

        if rule.output_entries.size != expected_outputs
          @errors << "#{path}: Expected #{expected_outputs} output entries, " \
                     "got #{rule.output_entries.size}"
        end
      end

      def format_errors
        header = "DMN model validation failed with #{@errors.size} error(s):\n\n"
        numbered = @errors.map.with_index { |err, idx| "  #{idx + 1}. #{err}" }.join("\n")
        header + numbered
      end
    end
  end
end
