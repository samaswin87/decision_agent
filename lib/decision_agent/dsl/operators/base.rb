module DecisionAgent
  module Dsl
    module Operators
      # Base utilities shared across all operator modules
      module Base
        # Normalize params to hash - converts arrays to hashes for better performance
        # If value is an array and keys are provided, convert to hash
        # If value is already a hash, normalize keys to symbols
        def self.normalize_params_to_hash(value, keys)
          if value.is_a?(Array) && value.size == keys.size
            # Convert array to hash for better performance with large params
            keys.each_with_index.each_with_object({}) do |(key, idx), hash|
              hash[key] = value[idx]
            end
          elsif value.is_a?(Hash)
            # Normalize hash keys to symbols for consistency
            value.each_with_object({}) do |(k, v), h|
              key = k.is_a?(String) ? k.to_sym : k
              h[key] = v
            end
          else
            value
          end
        end

        # Normalize parameter value for cache key generation
        def self.normalize_param_cache_key(value, prefix)
          case value
          when Array
            "#{prefix}:#{value.inspect}"
          when Hash
            # Normalize keys to symbols and sort for consistent cache keys
            normalized = value.each_with_object({}) do |(k, v), h|
              key = k.is_a?(String) ? k.to_sym : k
              h[key] = v
            end
            sorted_keys = normalized.keys.sort
            "#{prefix}:#{sorted_keys.map { |k| "#{k}:#{normalized[k]}" }.join(',')}"
          else
            "#{prefix}:#{value.inspect}"
          end
        end

        # Compare aggregation result with expected value (supports hash with comparison operators)
        def self.compare_aggregation_result(actual, expected)
          if expected.is_a?(Hash)
            result = true
            result &&= (actual >= expected[:min]) if expected[:min]
            result &&= (actual <= expected[:max]) if expected[:max]
            result &&= (actual > expected[:gt]) if expected[:gt]
            result &&= (actual < expected[:lt]) if expected[:lt]
            result &&= (actual >= expected[:gte]) if expected[:gte]
            result &&= (actual <= expected[:lte]) if expected[:lte]
            result &&= (actual == expected[:eq]) if expected[:eq]
            result
          else
            actual == expected
          end
        end

        # Epsilon comparison for floating point numbers
        def self.epsilon_equal?(a, b, epsilon = 1e-10)
          (a - b).abs < epsilon
        end
      end
    end
  end
end
