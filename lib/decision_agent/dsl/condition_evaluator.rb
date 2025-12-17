module DecisionAgent
  module Dsl
    # Evaluates conditions in the rule DSL against a context
    #
    # Supports:
    # - Field conditions with various operators
    # - Nested field access via dot notation (e.g., "user.profile.role")
    # - Logical operators (all/any)
    class ConditionEvaluator
      def self.evaluate(condition, context)
        return false unless condition.is_a?(Hash)

        if condition.key?("all")
          evaluate_all(condition["all"], context)
        elsif condition.key?("any")
          evaluate_any(condition["any"], context)
        elsif condition.key?("field")
          evaluate_field_condition(condition, context)
        else
          false
        end
      end

      private

      # Evaluates 'all' condition - returns true only if ALL sub-conditions are true
      # Empty array returns true (vacuous truth)
      def self.evaluate_all(conditions, context)
        return true if conditions.is_a?(Array) && conditions.empty?
        return false unless conditions.is_a?(Array)
        conditions.all? { |cond| evaluate(cond, context) }
      end

      # Evaluates 'any' condition - returns true if AT LEAST ONE sub-condition is true
      # Empty array returns false (no options to match)
      def self.evaluate_any(conditions, context)
        return false unless conditions.is_a?(Array)
        conditions.any? { |cond| evaluate(cond, context) }
      end

      def self.evaluate_field_condition(condition, context)
        field = condition["field"]
        op = condition["op"]
        expected_value = condition["value"]

        actual_value = get_nested_value(context.to_h, field)

        case op
        when "eq"
          # Equality - uses Ruby's == for comparison
          actual_value == expected_value

        when "neq"
          # Not equal - inverse of ==
          actual_value != expected_value

        when "gt"
          # Greater than - only for comparable types (numbers, strings)
          comparable?(actual_value, expected_value) && actual_value > expected_value

        when "gte"
          # Greater than or equal - only for comparable types
          comparable?(actual_value, expected_value) && actual_value >= expected_value

        when "lt"
          # Less than - only for comparable types
          comparable?(actual_value, expected_value) && actual_value < expected_value

        when "lte"
          # Less than or equal - only for comparable types
          comparable?(actual_value, expected_value) && actual_value <= expected_value

        when "in"
          # Array membership - checks if actual_value is in the expected array
          Array(expected_value).include?(actual_value)

        when "present"
          # PRESENT SEMANTICS:
          # Returns true if value exists AND is not empty
          # - nil: false
          # - Empty string "": false
          # - Empty array []: false
          # - Empty hash {}: false
          # - Zero 0: true (zero is a valid value)
          # - False boolean: true (false is a valid value)
          # - Non-empty values: true
          !actual_value.nil? && (actual_value.respond_to?(:empty?) ? !actual_value.empty? : true)

        when "blank"
          # BLANK SEMANTICS:
          # Returns true if value is nil OR empty
          # - nil: true
          # - Empty string "": true
          # - Empty array []: true
          # - Empty hash {}: true
          # - Zero 0: false (zero is a valid value)
          # - False boolean: false (false is a valid value)
          # - Non-empty values: false
          actual_value.nil? || (actual_value.respond_to?(:empty?) ? actual_value.empty? : false)

        else
          # Unknown operator - returns false (fail-safe)
          # Note: Validation should catch this earlier
          false
        end
      end

      # Retrieves nested values from a hash using dot notation
      #
      # Examples:
      #   get_nested_value({user: {role: "admin"}}, "user.role") # => "admin"
      #   get_nested_value({user: {role: "admin"}}, "user.missing") # => nil
      #   get_nested_value({user: nil}, "user.role") # => nil
      #
      # Supports both string and symbol keys in the hash
      def self.get_nested_value(hash, key_path)
        keys = key_path.to_s.split(".")
        keys.reduce(hash) do |memo, key|
          return nil unless memo.is_a?(Hash)
          memo[key] || memo[key.to_sym]
        end
      end

      # Checks if two values can be compared with <, >, <=, >=
      # Only allows comparison between values of the same type
      def self.comparable?(val1, val2)
        (val1.is_a?(Numeric) || val1.is_a?(String)) &&
          (val2.is_a?(Numeric) || val2.is_a?(String)) &&
          val1.class == val2.class
      end
    end
  end
end
