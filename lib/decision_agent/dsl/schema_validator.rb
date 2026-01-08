module DecisionAgent
  module Dsl
    # JSON Schema validator for Decision Agent rule DSL
    # Provides comprehensive validation with detailed error messages
    class SchemaValidator
      SUPPORTED_OPERATORS = %w[
        eq neq gt gte lt lte in present blank
        contains starts_with ends_with matches
        between modulo
        sin cos tan asin acos atan atan2
        sinh cosh tanh
        sqrt cbrt power exp log log10 log2
        round floor ceil truncate abs
        factorial gcd lcm
        min max sum average mean median stddev standard_deviation variance percentile count
        before_date after_date within_days day_of_week
        duration_seconds duration_minutes duration_hours duration_days
        add_days subtract_days add_hours subtract_hours add_minutes subtract_minutes
        hour_of_day day_of_month month year week_of_year
        rate_per_second rate_per_minute rate_per_hour
        moving_average moving_sum moving_max moving_min
        compound_interest present_value future_value payment
        join length
        contains_all contains_any intersects subset_of
        within_radius in_polygon
        fetch_from_api
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
        # Use key? to properly handle false values (|| would treat false as falsy)
        field = extract_key_value(condition, "field", :field)
        operator = extract_key_value(condition, "op", :op)
        value = extract_key_value(condition, "value", :value)

        # Validate field
        @errors << "#{path}: Field condition missing 'field' key" unless field

        # Validate operator
        unless operator
          @errors << "#{path}: Field condition missing 'op' (operator) key"
          return
        end

        validate_operator(operator, path)
        validate_field_condition_value(operator, value, path)
        validate_fetch_from_api_value(value, path) if (operator.to_s == "fetch_from_api") && value
        validate_field_path(field, path) if field
      end

      def extract_key_value(hash, string_key, symbol_key)
        return hash[string_key] if hash.key?(string_key)
        return hash[symbol_key] if hash.key?(symbol_key)

        nil
      end

      def validate_field_condition_value(operator, value, path)
        # Validate value (not required for 'present', 'blank', and 'fetch_from_api' has special validation)
        return if %w[present blank fetch_from_api].include?(operator.to_s)
        return unless value.nil?

        @errors << "#{path}: Field condition missing 'value' key for operator '#{operator}'"
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

        validate_then_clause_decision(then_clause, rule_path)
        validate_then_clause_weight(then_clause, rule_path)
        validate_then_clause_reason(then_clause, rule_path)
      end

      def validate_then_clause_decision(then_clause, rule_path)
        # Use key? to properly handle false values (|| would treat false as falsy)
        decision = extract_key_value(then_clause, "decision", :decision)

        # Check if decision exists (including false and 0, but not nil)
        @errors << "#{rule_path}.then: Missing required field 'decision'" if decision.nil?
      end

      def validate_then_clause_weight(then_clause, rule_path)
        weight = then_clause["weight"] || then_clause[:weight]

        if weight && !weight.is_a?(Numeric)
          @errors << "#{rule_path}.then.weight: Must be a number, got #{weight.class}"
        elsif weight && (weight < 0.0 || weight > 1.0)
          @errors << "#{rule_path}.then.weight: Must be between 0.0 and 1.0, got #{weight}"
        end
      end

      def validate_then_clause_reason(then_clause, rule_path)
        reason = then_clause["reason"] || then_clause[:reason]

        return unless reason && !reason.is_a?(String)

        @errors << "#{rule_path}.then.reason: Must be a string, got #{reason.class}"
      end

      def validate_fetch_from_api_value(value, path)
        unless value.is_a?(Hash)
          @errors << "#{path}: 'fetch_from_api' operator requires 'value' to be a hash with 'endpoint', 'params', and optional 'mapping'"
          return
        end

        endpoint = value["endpoint"] || value[:endpoint]
        @errors << "#{path}: 'fetch_from_api' operator requires 'endpoint' in value hash" unless endpoint

        params = value["params"] || value[:params]
        @errors << "#{path}: 'fetch_from_api' operator 'params' must be a hash if provided" unless params.nil? || params.is_a?(Hash)

        mapping = value["mapping"] || value[:mapping]
        return if mapping.nil? || mapping.is_a?(Hash)

        @errors << "#{path}: 'fetch_from_api' operator 'mapping' must be a hash if provided"
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
