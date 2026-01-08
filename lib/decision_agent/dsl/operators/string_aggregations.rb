module DecisionAgent
  module Dsl
    module Operators
      # Handles string aggregation operators: join, length
      module StringAggregations
        def self.handle(op, actual_value, expected_value, param_cache: nil, param_cache_mutex: nil)
          case op
          when "join"
            # Joins array of strings with separator
            return false unless actual_value.is_a?(Array)
            return false if actual_value.empty?

            string_array = actual_value.map(&:to_s)
            params = parse_join_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            joined = string_array.join(params[:separator])

            if params[:result]
              joined == params[:result]
            elsif params[:contains]
              joined.include?(params[:contains])
            else
              false
            end

          when "length"
            # Gets length of string or array
            return false if actual_value.nil?

            length_value = if actual_value.is_a?(String) || actual_value.is_a?(Array)
                             actual_value.length
                           else
                             return false
                           end

            compare_length_result(length_value, expected_value)
          end
          # Returns nil if not handled by this module
        end

        # Parse join parameters
        def self.parse_join_params(value, param_cache: nil, param_cache_mutex: nil)
          return nil unless value.is_a?(Hash)

          normalized = Base.normalize_params_to_hash(value, [])

          cache = param_cache
          mutex = param_cache_mutex
          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = Base.normalize_param_cache_key(normalized, "join")
          cached = cache[cache_key]
          return cached if cached

          mutex.synchronize do
            cache[cache_key] ||= parse_join_params_impl(normalized)
          end
        end

        def self.parse_join_params_impl(value)
          separator = value[:separator] || value["separator"]
          return nil unless separator

          {
            separator: separator.to_s,
            result: value[:result] || value["result"],
            contains: value[:contains] || value["contains"]
          }
        end

        # Compare length result
        def self.compare_length_result(actual, expected)
          ConditionEvaluator.compare_length_result(actual, expected)
        end
      end
    end
  end
end
