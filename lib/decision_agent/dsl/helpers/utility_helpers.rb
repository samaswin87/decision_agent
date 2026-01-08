module DecisionAgent
  module Dsl
    module Helpers
      # Utility helpers for ConditionEvaluator
      module UtilityHelpers
        def self.get_nested_value(hash, key_path, get_cached_path:)
          keys = get_cached_path.call(key_path)
          keys.reduce(hash) do |memo, key|
            return nil unless memo.is_a?(Hash)

            # OPTIMIZE: try symbol first (most common), then string
            # Check key existence first to avoid double lookup
            key_sym = key.to_sym
            if memo.key?(key_sym)
              memo[key_sym]
            elsif memo.key?(key)
              memo[key]
            end
          end
        end

        def self.comparable?(val1, val2)
          # Both are numeric - allow comparison between different numeric types
          # (e.g., Integer and Float are comparable in Ruby)
          return true if val1.is_a?(Numeric) && val2.is_a?(Numeric)

          # Both are strings - require exact same type
          return val1.instance_of?(val2.class) if val1.is_a?(String) && val2.is_a?(String)

          false
        end

        def self.epsilon_equal?(value1, value2, epsilon = 1e-10)
          (value1 - value2).abs < epsilon
        end

        def self.string_operator?(actual_value, expected_value)
          actual_value.is_a?(String) && expected_value.is_a?(String)
        end
      end
    end
  end
end
