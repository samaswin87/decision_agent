module DecisionAgent
  module Dsl
    module Operators
      # Handles mathematical operators: trigonometric, exponential, logarithmic, rounding, etc.
      module MathematicalOperators
        def self.handle(op, actual_value, expected_value, param_cache: nil, param_cache_mutex: nil)
          case op
          # Trigonometric functions
          when "sin"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            Base.epsilon_equal?(Math.sin(actual_value), expected_value)
          when "cos"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            Base.epsilon_equal?(Math.cos(actual_value), expected_value)
          when "tan"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            Base.epsilon_equal?(Math.tan(actual_value), expected_value)
          when "asin"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            return false if actual_value < -1 || actual_value > 1
            Base.epsilon_equal?(Math.asin(actual_value), expected_value)
          when "acos"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            return false if actual_value < -1 || actual_value > 1
            Base.epsilon_equal?(Math.acos(actual_value), expected_value)
          when "atan"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            Base.epsilon_equal?(Math.atan(actual_value), expected_value)
          when "atan2"
            return false unless actual_value.is_a?(Numeric)
            params = parse_atan2_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params
            Base.epsilon_equal?(Math.atan2(actual_value, params[:y]), params[:result])
          when "sinh"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            Base.epsilon_equal?(Math.sinh(actual_value), expected_value)
          when "cosh"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            Base.epsilon_equal?(Math.cosh(actual_value), expected_value)
          when "tanh"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            Base.epsilon_equal?(Math.tanh(actual_value), expected_value)

          # Exponential and logarithmic functions
          when "sqrt"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            return false if actual_value.negative?
            Base.epsilon_equal?(Math.sqrt(actual_value), expected_value)
          when "cbrt"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            result = if actual_value.negative?
                       -((-actual_value)**(1.0 / 3))
                     else
                       actual_value**(1.0 / 3)
                     end
            Base.epsilon_equal?(result, expected_value)
          when "power"
            return false unless actual_value.is_a?(Numeric)
            params = parse_power_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params
            Base.epsilon_equal?(actual_value**params[:exponent], params[:result])
          when "exp"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            Base.epsilon_equal?(Math.exp(actual_value), expected_value)
          when "log"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            return false if actual_value <= 0
            Base.epsilon_equal?(Math.log(actual_value), expected_value)
          when "log10"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            return false if actual_value <= 0
            Base.epsilon_equal?(Math.log10(actual_value), expected_value)
          when "log2"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            return false if actual_value <= 0
            Base.epsilon_equal?(Math.log(actual_value) / Math.log(2), expected_value)

          # Rounding and absolute value functions
          when "round"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            actual_value.round == expected_value
          when "floor"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            actual_value.floor == expected_value
          when "ceil"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            actual_value.ceil == expected_value
          when "abs"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            actual_value.abs == expected_value
          when "truncate"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            actual_value.truncate == expected_value

          # Advanced mathematical functions
          when "factorial"
            return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
            return false if actual_value.negative? || !actual_value.integer?
            (1..actual_value.to_i).reduce(1, :*) == expected_value
          when "gcd"
            return false unless actual_value.is_a?(Numeric) && actual_value.integer?
            params = parse_gcd_lcm_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params && params[:other].integer?
            actual_value.to_i.gcd(params[:other].to_i) == params[:result]
          when "lcm"
            return false unless actual_value.is_a?(Numeric) && actual_value.integer?
            params = parse_gcd_lcm_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params && params[:other].integer?
            actual_value.to_i.lcm(params[:other].to_i) == params[:result]

          else
            nil # Not handled by this module
          end
        end

        # Parse atan2 parameters
        def self.parse_atan2_params(value, param_cache: nil, param_cache_mutex: nil)
          normalized = Base.normalize_params_to_hash(value, [:y, :result])
          return nil unless normalized.is_a?(Hash)

          cache = param_cache
          mutex = param_cache_mutex
          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = Base.normalize_param_cache_key(normalized, "atan2")
          cached = cache[cache_key]
          return cached if cached

          mutex.synchronize do
            cache[cache_key] ||= parse_atan2_params_impl(normalized)
          end
        end

        def self.parse_atan2_params_impl(value)
          y = value[:y] || value["y"]
          result = value[:result] || value["result"]
          return nil unless y && !result.nil?

          { y: y, result: result }
        end

        # Parse power parameters
        def self.parse_power_params(value, param_cache: nil, param_cache_mutex: nil)
          normalized = Base.normalize_params_to_hash(value, [:exponent, :result])
          return nil unless normalized.is_a?(Hash)

          cache = param_cache
          mutex = param_cache_mutex
          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = Base.normalize_param_cache_key(normalized, "power")
          cached = cache[cache_key]
          return cached if cached

          mutex.synchronize do
            cache[cache_key] ||= parse_power_params_impl(normalized)
          end
        end

        def self.parse_power_params_impl(value)
          exponent = value[:exponent] || value["exponent"]
          result = value[:result] || value["result"]
          return nil unless exponent && !result.nil?

          { exponent: exponent, result: result }
        end

        # Parse gcd/lcm parameters
        def self.parse_gcd_lcm_params(value, param_cache: nil, param_cache_mutex: nil)
          normalized = Base.normalize_params_to_hash(value, [:other, :result])
          return nil unless normalized.is_a?(Hash)

          cache = param_cache
          mutex = param_cache_mutex
          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = Base.normalize_param_cache_key(normalized, "gcd_lcm")
          cached = cache[cache_key]
          return cached if cached

          mutex.synchronize do
            cache[cache_key] ||= parse_gcd_lcm_params_impl(normalized)
          end
        end

        def self.parse_gcd_lcm_params_impl(value)
          other = value[:other] || value["other"]
          result = value[:result] || value["result"]
          return nil unless other && !result.nil?

          { other: other, result: result }
        end
      end
    end
  end
end
