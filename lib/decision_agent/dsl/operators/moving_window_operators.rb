module DecisionAgent
  module Dsl
    module Operators
      # Handles moving window calculation operators: moving_average, moving_sum, moving_max, moving_min
      module MovingWindowOperators
        def self.handle(op, actual_value, expected_value, param_cache: nil, param_cache_mutex: nil)
          case op
          when "moving_average"
            # Calculates moving average over window
            return false unless actual_value.is_a?(Array)
            return false if actual_value.empty?

            numeric_array = actual_value.select { |v| v.is_a?(Numeric) }
            return false if numeric_array.empty?

            params = parse_moving_window_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            window = [params[:window], numeric_array.size].min
            return false if window < 1

            window_array = numeric_array.slice(-window, window)
            moving_avg = window_array.sum.to_f / window
            compare_moving_window_result(moving_avg, params)

          when "moving_sum"
            # Calculates moving sum over window
            return false unless actual_value.is_a?(Array)
            return false if actual_value.empty?

            numeric_array = actual_value.select { |v| v.is_a?(Numeric) }
            return false if numeric_array.empty?

            params = parse_moving_window_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            window = [params[:window], numeric_array.size].min
            return false if window < 1

            window_array = numeric_array.slice(-window, window)
            moving_sum = window_array.sum
            compare_moving_window_result(moving_sum, params)

          when "moving_max"
            # Calculates moving max over window
            return false unless actual_value.is_a?(Array)
            return false if actual_value.empty?

            numeric_array = actual_value.select { |v| v.is_a?(Numeric) }
            return false if numeric_array.empty?

            params = parse_moving_window_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            window = [params[:window], numeric_array.size].min
            return false if window < 1

            window_array = numeric_array.slice(-window, window)
            moving_max = window_array.max
            compare_moving_window_result(moving_max, params)

          when "moving_min"
            # Calculates moving min over window
            return false unless actual_value.is_a?(Array)
            return false if actual_value.empty?

            numeric_array = actual_value.select { |v| v.is_a?(Numeric) }
            return false if numeric_array.empty?

            params = parse_moving_window_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            window = [params[:window], numeric_array.size].min
            return false if window < 1

            window_array = numeric_array.slice(-window, window)
            moving_min = window_array.min
            compare_moving_window_result(moving_min, params)

          else
            nil # Not handled by this module
          end
        end

        # Parse moving window parameters
        def self.parse_moving_window_params(value, param_cache: nil, param_cache_mutex: nil)
          return nil unless value.is_a?(Hash)

          # Normalize to hash (already a hash, but normalize keys)
          normalized = Base.normalize_params_to_hash(value, [])

          cache = param_cache
          mutex = param_cache_mutex
          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = Base.normalize_param_cache_key(normalized, "moving_window")
          cached = cache[cache_key]
          return cached if cached

          mutex.synchronize do
            cache[cache_key] ||= parse_moving_window_params_impl(normalized)
          end
        end

        def self.parse_moving_window_params_impl(value)
          window = value[:window] || value["window"]
          return nil unless window.is_a?(Numeric) && window > 0

          {
            window: window.to_i,
            threshold: value[:threshold] || value["threshold"],
            gt: value[:gt] || value["gt"],
            lt: value[:lt] || value["lt"],
            gte: value[:gte] || value["gte"],
            lte: value[:lte] || value["lte"]
          }
        end

        # Compare moving window result
        def self.compare_moving_window_result(actual, params)
          result = true
          result &&= (actual >= params[:threshold]) if params[:threshold]
          result &&= (actual > params[:gt]) if params[:gt]
          result &&= (actual < params[:lt]) if params[:lt]
          result &&= (actual >= params[:gte]) if params[:gte]
          result &&= (actual <= params[:lte]) if params[:lte]
          result
        end
      end
    end
  end
end
