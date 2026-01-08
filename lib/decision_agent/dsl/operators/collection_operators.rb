module DecisionAgent
  module Dsl
    module Operators
      # Handles collection operators: contains_all, contains_any, intersects, subset_of
      module CollectionOperators
        def self.handle(op, actual_value, expected_value)
          case op
          when "contains_all"
            # Checks if array contains all specified elements
            return false unless actual_value.is_a?(Array)
            return false unless expected_value.is_a?(Array)
            return true if expected_value.empty?

            # OPTIMIZE: Use Set for O(1) lookups instead of O(n) include?
            actual_set = actual_value.to_set
            expected_value.all? { |item| actual_set.include?(item) }

          when "contains_any"
            # Checks if array contains any of the specified elements
            return false unless actual_value.is_a?(Array)
            return false unless expected_value.is_a?(Array)
            return false if expected_value.empty?

            # OPTIMIZE: Use Set for O(1) lookups instead of O(n) include?
            actual_set = actual_value.to_set
            expected_value.any? { |item| actual_set.include?(item) }

          when "intersects"
            # Checks if two arrays have any common elements
            return false unless actual_value.is_a?(Array)
            return false unless expected_value.is_a?(Array)
            return false if actual_value.empty? || expected_value.empty?

            # OPTIMIZE: Use Set intersection for O(n) instead of array & which creates intermediate array
            if actual_value.size <= expected_value.size
              expected_set = expected_value.to_set
              actual_value.any? { |item| expected_set.include?(item) }
            else
              actual_set = actual_value.to_set
              expected_value.any? { |item| actual_set.include?(item) }
            end

          when "subset_of"
            # Checks if array is a subset of another array
            return false unless actual_value.is_a?(Array)
            return false unless expected_value.is_a?(Array)
            return true if actual_value.empty?

            # OPTIMIZE: Use Set for O(1) lookups instead of O(n) include?
            expected_set = expected_value.to_set
            actual_value.all? { |item| expected_set.include?(item) }

          else
            nil # Not handled by this module
          end
        end
      end
    end
  end
end
