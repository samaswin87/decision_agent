module DecisionAgent
  module Dsl
    module Operators
      # Handles numeric operators: between, modulo
      module NumericOperators
        def self.handle(op, actual_value, expected_value, param_cache: nil, param_cache_mutex: nil)
          case op
          when "between"
            # Checks if numeric value is between min and max (inclusive)
            # expected_value should be [min, max] or {min: x, max: y}
            if actual_value.is_a?(Numeric)
              range = parse_range(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
              range ? actual_value.between?(range[:min], range[:max]) : false
            else
              false
            end

          when "modulo"
            # Checks if value modulo divisor equals remainder
            # expected_value should be [divisor, remainder] or {divisor: x, remainder: y}
            if actual_value.is_a?(Numeric)
              params = parse_modulo_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
              params ? (actual_value % params[:divisor]) == params[:remainder] : false
            else
              false
            end

          else
            nil # Not handled by this module
          end
        end

        # Parse range for 'between' operator
        # Accepts [min, max] or {min: x, max: y}
        # Converts arrays to hash for consistency and better performance
        def self.parse_range(value, param_cache: nil, param_cache_mutex: nil)
          # Normalize to hash if array (for large params, hash is more efficient)
          normalized_value = normalize_params_to_hash(value, [:min, :max])
          
          # Use provided caches or access ConditionEvaluator class variables
          cache = param_cache
          mutex = param_cache_mutex

          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = normalize_param_cache_key(normalized_value, "range")

          # Fast path: check cache without lock
          cached = cache[cache_key]
          return cached if cached

          # Slow path: parse and cache
          mutex.synchronize do
            cache[cache_key] ||= parse_range_impl(normalized_value)
          end
        end

        def self.parse_range_impl(value)
          return nil unless value.is_a?(Hash)

          min = value[:min] || value["min"]
          max = value[:max] || value["max"]
          return nil unless min && max

          { min: min, max: max }
        end

        # Parse modulo parameters
        # Accepts [divisor, remainder] or {divisor: x, remainder: y}
        # Converts arrays to hash for consistency and better performance
        def self.parse_modulo_params(value, param_cache: nil, param_cache_mutex: nil)
          # Normalize to hash if array (for large params, hash is more efficient)
          normalized_value = normalize_params_to_hash(value, [:divisor, :remainder])
          
          # Use provided caches or access ConditionEvaluator class variables
          cache = param_cache
          mutex = param_cache_mutex

          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = normalize_param_cache_key(normalized_value, "modulo")

          # Fast path: check cache without lock
          cached = cache[cache_key]
          return cached if cached

          # Slow path: parse and cache
          mutex.synchronize do
            cache[cache_key] ||= parse_modulo_params_impl(normalized_value)
          end
        end

        def self.parse_modulo_params_impl(value)
          return nil unless value.is_a?(Hash)

          divisor = value[:divisor] || value["divisor"]
          remainder = value[:remainder] || value["remainder"]
          return nil unless divisor && !remainder.nil?

          { divisor: divisor, remainder: remainder }
        end

        # Use Base utilities
        def self.normalize_params_to_hash(value, keys)
          Base.normalize_params_to_hash(value, keys)
        end

        def self.normalize_param_cache_key(value, prefix)
          Base.normalize_param_cache_key(value, prefix)
        end
      end
    end
  end
end
