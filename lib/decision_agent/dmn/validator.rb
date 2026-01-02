require_relative "errors"
require_relative "feel/evaluator"

module DecisionAgent
  module Dmn
    # Validates DMN model structure and semantics with enhanced validation
    class Validator
      attr_reader :errors, :warnings

      def initialize(model = nil)
        @model = model
        @errors = []
        @warnings = []
        @feel_evaluator = Feel::Evaluator.new
      end

      def validate(model = nil)
        @model = model if model
        return false unless @model

        @errors = []
        @warnings = []

        # Basic structure validation
        validate_model_structure
        validate_decisions

        # Semantic validation
        validate_decision_dependencies
        validate_decision_graph_cycles

        # Business rule validation
        validate_decision_tables

        @errors.empty?
      end

      def validate!
        validate
        raise InvalidDmnModelError, format_errors if @errors.any?
        true
      end

      def valid?
        @errors.empty?
      end

      private

      # Basic structure validation
      def validate_model_structure
        @errors << "Model must have an ID" if @model.id.nil? || @model.id.empty?
        @errors << "Model must have a name" if @model.name.nil? || @model.name.empty?
        @errors << "Model must have a namespace" if @model.namespace.nil? || @model.namespace.empty?
        @warnings << "Model has no decisions defined" if @model.decisions.empty?
      end

      def validate_decisions
        decision_ids = Set.new

        @model.decisions.each_with_index do |decision, idx|
          validate_decision(decision, idx)

          # Check for duplicate decision IDs
          if decision_ids.include?(decision.id)
            @errors << "Duplicate decision ID: #{decision.id}"
          else
            decision_ids.add(decision.id)
          end
        end
      end

      def validate_decision(decision, idx)
        path = "Decision[#{idx}](#{decision.id})"

        @errors << "#{path}: Decision must have an ID" if decision.id.nil? || decision.id.empty?
        @errors << "#{path}: Decision must have a name" if decision.name.nil? || decision.name.empty?

        # Validate decision has some form of logic
        unless decision.decision_table || decision.decision_tree || decision.instance_variable_get(:@literal_expression)
          @errors << "#{path}: Decision must have decision logic (table, tree, or literal expression)"
        end

        # Validate decision table if present
        validate_decision_table(decision.decision_table, path) if decision.decision_table

        # Validate information requirements
        validate_information_requirements(decision, path)
      end

      def validate_information_requirements(decision, path)
        return unless decision.information_requirements

        decision.information_requirements.each do |req|
          required_decision_id = req[:decision_id]

          # Check if required decision exists
          @errors << "#{path}: References non-existent decision: #{required_decision_id}" unless @model.find_decision(required_decision_id)
        end
      end

      # Semantic validation - check for circular dependencies
      def validate_decision_graph_cycles
        visited = Set.new
        rec_stack = Set.new

        @model.decisions.each do |decision|
          @errors << "Circular dependency detected in decision graph involving: #{decision.id}" if cycle?(decision, visited, rec_stack)
        end
      end

      def cycle?(decision, visited, rec_stack)
        return false if visited.include?(decision.id)

        visited.add(decision.id)
        rec_stack.add(decision.id)

        # Check all dependencies
        decision.information_requirements.each do |req|
          dep = @model.find_decision(req[:decision_id])
          next unless dep

          return true if !visited.include?(dep.id) && cycle?(dep, visited, rec_stack)
          return true if rec_stack.include?(dep.id)
        end

        rec_stack.delete(decision.id)
        false
      end

      def validate_decision_dependencies
        # Check for unreachable decisions
        reachable = Set.new
        leaves = find_leaf_decisions

        leaves.each do |leaf|
          mark_reachable(leaf, reachable)
        end

        @model.decisions.each do |decision|
          @warnings << "Decision #{decision.id} is not reachable from any leaf decision" unless reachable.include?(decision.id)
        end
      end

      def find_leaf_decisions
        # Leaf decisions are those that no other decision depends on
        required_decisions = Set.new
        @model.decisions.each do |decision|
          decision.information_requirements.each do |req|
            required_decisions.add(req[:decision_id])
          end
        end

        @model.decisions.reject { |d| required_decisions.include?(d.id) }
      end

      def mark_reachable(decision, reachable)
        return if reachable.include?(decision.id)

        reachable.add(decision.id)

        decision.information_requirements.each do |req|
          dep = @model.find_decision(req[:decision_id])
          mark_reachable(dep, reachable) if dep
        end
      end

      # Business rule validation for decision tables
      def validate_decision_tables
        @model.decisions.each_with_index do |decision, idx|
          next unless decision.decision_table

          path = "Decision[#{idx}](#{decision.id})"
          table = decision.decision_table

          validate_table_structure(table, path)
          validate_table_hit_policy(table, path)
          validate_table_completeness(table, path)
          validate_table_rules(table, path)
        end
      end

      def validate_table_structure(table, path)
        @errors << "#{path}: Decision table must have at least one input" if table.inputs.empty?
        @errors << "#{path}: Decision table must have at least one output" if table.outputs.empty?
        @warnings << "#{path}: Decision table has no rules defined" if table.rules.empty?

        # Check for duplicate input/output IDs
        input_ids = table.inputs.map(&:id)
        @errors << "#{path}: Duplicate input IDs detected" if input_ids.size != input_ids.uniq.size

        output_ids = table.outputs.map(&:id)
        @errors << "#{path}: Duplicate output IDs detected" if output_ids.size != output_ids.uniq.size
      end

      def validate_table_hit_policy(table, path)
        valid_policies = %w[UNIQUE FIRST PRIORITY ANY COLLECT]

        unless valid_policies.include?(table.hit_policy)
          @errors << "#{path}: Invalid hit policy '#{table.hit_policy}'. Must be one of: #{valid_policies.join(', ')}"
        end

        # Validate hit policy requirements
        case table.hit_policy
        when "UNIQUE"
          # Check for overlapping rules (not fully implemented - would require rule evaluation)
          @warnings << "#{path}: UNIQUE hit policy requires rules to be mutually exclusive"
        when "PRIORITY"
          # Check that outputs have defined allowed values with priorities
          table.outputs.each do |output|
            unless output.instance_variable_get(:@allowed_values)
              @warnings << "#{path}: PRIORITY hit policy requires outputs to have defined allowed values"
            end
          end
        end
      end

      def validate_table_completeness(table, path)
        return if table.rules.empty?

        # Check for rules with all wildcards and empty outputs
        table.rules.each_with_index do |rule, idx|
          all_wildcards = rule.input_entries.all? { |entry| entry.nil? || entry == "-" || entry.empty? }
          @warnings << "#{path}.Rule[#{idx}]: Rule has all wildcard inputs - will match everything" if all_wildcards

          # Check for empty output entries
          rule.output_entries.each_with_index do |entry, output_idx|
            next unless entry.nil? || entry.empty?

            output = table.outputs[output_idx]
            @warnings << "#{path}.Rule[#{idx}]: Empty output for '#{output&.label}'"
          end
        end
      end

      def validate_table_rules(table, path)
        table.rules.each_with_index do |rule, idx|
          validate_rule(rule, table, "#{path}.Rule[#{idx}]")
          validate_rule_feel_expressions(rule, table, "#{path}.Rule[#{idx}]")
        end
      end

      def validate_rule(rule, table, path)
        expected_inputs = table.inputs.size
        expected_outputs = table.outputs.size

        if rule.input_entries.size != expected_inputs
          @errors << "#{path}: Expected #{expected_inputs} input entries, got #{rule.input_entries.size}"
        end

        if rule.output_entries.size != expected_outputs
          @errors << "#{path}: Expected #{expected_outputs} output entries, got #{rule.output_entries.size}"
        end

        # Validate rule has an ID
        @errors << "#{path}: Rule must have an ID" if rule.id.nil? || rule.id.empty?
      end

      def validate_rule_feel_expressions(rule, table, path)
        # Validate input entry expressions are valid FEEL
        rule.input_entries.each_with_index do |entry, idx|
          next if entry.nil? || entry == "-" || entry.empty?

          input = table.inputs[idx]
          validate_feel_expression(entry, "#{path}.Input[#{idx}](#{input&.label})")
        end

        # Validate output entry expressions
        rule.output_entries.each_with_index do |entry, idx|
          next if entry.nil? || entry.empty?

          output = table.outputs[idx]
          validate_feel_expression(entry, "#{path}.Output[#{idx}](#{output&.label})")
        end
      end

      def validate_feel_expression(expression, path)
        return if expression.nil? || expression.empty?

        begin
          # Try to parse the expression (basic validation)
          # Full validation would require evaluating with sample context
          @feel_evaluator.evaluate(expression.to_s, {})
        rescue StandardError => e
          # Only warn for FEEL validation errors since they might be context-dependent
          @warnings << "#{path}: Possible FEEL expression issue: #{e.message}"
        end
      end

      def format_errors
        parts = []

        if @errors.any?
          parts << "DMN model validation failed with #{@errors.size} error(s):"
          parts << ""
          @errors.each_with_index do |err, idx|
            parts << "  #{idx + 1}. #{err}"
          end
        end

        if @warnings.any?
          parts << "" if @errors.any?
          parts << "Warnings (#{@warnings.size}):"
          @warnings.each_with_index do |warn, idx|
            parts << "  #{idx + 1}. #{warn}"
          end
        end

        parts.join("\n")
      end
    end
  end
end
