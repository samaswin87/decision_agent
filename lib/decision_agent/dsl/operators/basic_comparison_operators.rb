module DecisionAgent
  module Dsl
    module Operators
      # Handles basic comparison operators: eq, neq, gt, gte, lt, lte, in, present, blank
      module BasicComparisonOperators
        def self.handle(op, actual_value, expected_value)
          case op
          when "eq"
            # Equality - uses Ruby's == for comparison
            actual_value == expected_value

          when "neq"
            # Not equal - inverse of ==
            actual_value != expected_value

          when "gt"
            # Greater than - only for comparable types (numbers, strings)
            self.comparable?(actual_value, expected_value) && actual_value > expected_value

          when "gte"
            # Greater than or equal - only for comparable types
            self.comparable?(actual_value, expected_value) && actual_value >= expected_value

          when "lt"
            # Less than - only for comparable types
            self.comparable?(actual_value, expected_value) && actual_value < expected_value

          when "lte"
            # Less than or equal - only for comparable types
            self.comparable?(actual_value, expected_value) && actual_value <= expected_value

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
            nil # Not handled by this module
          end
        end

        # Checks if two values can be compared with <, >, <=, >=
        # Allows comparison between numeric types (Float, Integer, etc.) or same string types
        def self.comparable?(val1, val2)
          # Both are numeric - allow comparison between different numeric types
          # (e.g., Integer and Float are comparable in Ruby)
          return true if val1.is_a?(Numeric) && val2.is_a?(Numeric)

          # Both are strings - require exact same type
          return val1.instance_of?(val2.class) if val1.is_a?(String) && val2.is_a?(String)

          false
        end
      end
    end
  end
end
