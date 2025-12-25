module DecisionAgent
  module Dsl
    # JSON Schema validator for Decision Agent rule DSL
    # Provides comprehensive validation with detailed error messages
    class SchemaValidator
      SUPPORTED_OPERATORS = %w[
        eq neq gt gte lt lte in present blank
        contains starts_with ends_with matches
        between modulo
        before_date after_date within_days day_of_week
        contains_all contains_any intersects subset_of
        within_radius in_polygon
      ].freeze

      CONDITION_TYPES = %w[all any field].freeze

      # Validates the entire ruleset structure
      def self.validate!(data)
        new(data).validate!
      end

      def initialize(data)
        @data = data
        @errors = []
      end

      def validate!
        validate_root_structure
        validate_version
        validate_rules_array
        validate_each_rule

        raise InvalidRuleDslError, format_errors if @errors.any?

        true
      end

      private

      def validate_root_structure
        return if @data.is_a?(Hash)

        @errors << "Root element must be a hash/object, got #{@data.class}"
        nil
      end

      def validate_version
        return if @errors.any? # Skip if root structure is invalid

        return if @data.key?("version") || @data.key?(:version)

        @errors << "Missing required field 'version'. Example: { \"version\": \"1.0\", ... }"
      end

      def validate_rules_array
        return if @errors.any?

        rules = @data["rules"] || @data[:rules]

        unless rules
          @errors << "Missing required field 'rules'. Expected an array of rule objects."
          return
        end

        return if rules.is_a?(Array)

        @errors << "Field 'rules' must be an array, got #{rules.class}. Example: \"rules\": [...]"
      end

      def validate_each_rule
        return if @errors.any?

        rules = @data["rules"] || @data[:rules]
        return unless rules.is_a?(Array)

        rules.each_with_index do |rule, idx|
          validate_rule(rule, idx)
        end
      end

      def validate_rule(rule, idx)
        rule_path = "rules[#{idx}]"

        unless rule.is_a?(Hash)
          @errors << "#{rule_path}: Rule must be a hash/object, got #{rule.class}"
          return
        end

        # Validate required fields
        validate_rule_id(rule, rule_path)
        validate_if_clause(rule, rule_path)
        validate_then_clause(rule, rule_path)
      end

      def validate_rule_id(rule, rule_path)
        rule_id = rule["id"] || rule[:id]

        unless rule_id
          @errors << "#{rule_path}: Missing required field 'id'. Each rule must have a unique identifier."
          return
        end

        return if rule_id.is_a?(String) || rule_id.is_a?(Symbol)

        @errors << "#{rule_path}: Field 'id' must be a string, got #{rule_id.class}"
      end

      def validate_if_clause(rule, rule_path)
        if_clause = rule["if"] || rule[:if]

        unless if_clause
          @errors << "#{rule_path}: Missing required field 'if'. " \
                     "Expected a condition object with 'field', 'all', or 'any'."
          return
        end

        validate_condition(if_clause, "#{rule_path}.if")
      end

      def validate_condition(condition, path)
        unless condition.is_a?(Hash)
          @errors << "#{path}: Condition must be a hash/object, got #{condition.class}"
          return
        end

        condition_type = detect_condition_type(condition)

        unless condition_type
          @errors << "#{path}: Condition must have one of: 'field', 'all', or 'any'. " \
                     "Example: { \"field\": \"status\", \"op\": \"eq\", \"value\": \"active\" }"
          return
        end

        case condition_type
        when "field"
          validate_field_condition(condition, path)
        when "all"
          validate_all_condition(condition, path)
        when "any"
          validate_any_condition(condition, path)
        end
      end

      def detect_condition_type(condition)
        if condition.key?("field") || condition.key?(:field)
          "field"
        elsif condition.key?("all") || condition.key?(:all)
          "all"
        elsif condition.key?("any") || condition.key?(:any)
          "any"
        end
      end

      def validate_field_condition(condition, path)
        field = condition["field"] || condition[:field]
        operator = condition["op"] || condition[:op]
        value = condition["value"] || condition[:value]

        # Validate field
        @errors << "#{path}: Field condition missing 'field' key" unless field

        # Validate operator
        unless operator
          @errors << "#{path}: Field condition missing 'op' (operator) key"
          return
        end

        validate_operator(operator, path)

        # Validate value (not required for 'present' and 'blank')
        if !%w[present blank].include?(operator.to_s) && value.nil?
          @errors << "#{path}: Field condition missing 'value' key for operator '#{operator}'"
        end

        # Validate dot-notation in field path
        validate_field_path(field, path) if field
      end

      def validate_operator(operator, path)
        operator_str = operator.to_s

        return if SUPPORTED_OPERATORS.include?(operator_str)

        @errors << "#{path}: Unsupported operator '#{operator}'. " \
                   "Supported operators: #{SUPPORTED_OPERATORS.join(', ')}"
      end

      def validate_field_path(field, path)
        return unless field.is_a?(String)

        if field.empty?
          @errors << "#{path}: Field path cannot be empty"
          return
        end

        # Validate dot-notation
        parts = field.split(".")

        return unless parts.any?(&:empty?)

        @errors << "#{path}: Invalid field path '#{field}'. " \
                   "Dot-notation paths cannot have empty segments. " \
                   "Example: 'user.profile.role'"
      end

      def validate_all_condition(condition, path)
        sub_conditions = condition["all"] || condition[:all]

        unless sub_conditions.is_a?(Array)
          @errors << "#{path}: 'all' condition must contain an array of conditions, got #{sub_conditions.class}"
          return
        end

        sub_conditions.each_with_index do |sub_cond, idx|
          validate_condition(sub_cond, "#{path}.all[#{idx}]")
        end
      end

      def validate_any_condition(condition, path)
        sub_conditions = condition["any"] || condition[:any]

        unless sub_conditions.is_a?(Array)
          @errors << "#{path}: 'any' condition must contain an array of conditions, got #{sub_conditions.class}"
          return
        end

        sub_conditions.each_with_index do |sub_cond, idx|
          validate_condition(sub_cond, "#{path}.any[#{idx}]")
        end
      end

      def validate_then_clause(rule, rule_path)
        then_clause = rule["then"] || rule[:then]

        unless then_clause
          @errors << "#{rule_path}: Missing required field 'then'. " \
                     "Expected an object with 'decision' field."
          return
        end

        unless then_clause.is_a?(Hash)
          @errors << "#{rule_path}.then: Must be a hash/object, got #{then_clause.class}"
          return
        end

        # Validate decision
        decision = then_clause["decision"] || then_clause[:decision]

        @errors << "#{rule_path}.then: Missing required field 'decision'" unless decision

        # Validate optional weight
        weight = then_clause["weight"] || then_clause[:weight]

        if weight && !weight.is_a?(Numeric)
          @errors << "#{rule_path}.then.weight: Must be a number, got #{weight.class}"
        elsif weight && (weight < 0.0 || weight > 1.0)
          @errors << "#{rule_path}.then.weight: Must be between 0.0 and 1.0, got #{weight}"
        end

        # Validate optional reason
        reason = then_clause["reason"] || then_clause[:reason]

        return unless reason && !reason.is_a?(String)

        @errors << "#{rule_path}.then.reason: Must be a string, got #{reason.class}"
      end

      def format_errors
        header = "Rule DSL validation failed with #{@errors.size} error#{'s' if @errors.size > 1}:\n\n"
        numbered_errors = @errors.map.with_index { |err, idx| "  #{idx + 1}. #{err}" }.join("\n")

        footer = "\n\nFor documentation on the rule DSL format, see the README."

        header + numbered_errors + footer
      end
    end
  end
end
