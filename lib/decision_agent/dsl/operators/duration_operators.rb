module DecisionAgent
  module Dsl
    module Operators
      # Handles duration calculation operators: duration_seconds, duration_minutes, duration_hours, duration_days
      module DurationOperators
        def self.handle(op, actual_value, expected_value, context_hash, param_cache: nil, param_cache_mutex: nil)
          case op
          when "duration_seconds"
            # Calculates duration between two dates in seconds
            return false unless actual_value

            start_date = ConditionEvaluator.parse_date(actual_value)
            return false unless start_date

            params = parse_duration_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            end_date = if params[:end] == "now"
                         Time.now
                       else
                         ConditionEvaluator.parse_date(ConditionEvaluator.get_nested_value(context_hash,
                                                                                           params[:end]))
                       end
            return false unless end_date

            duration = (end_date - start_date).abs
            compare_duration_result(duration, params)

          when "duration_minutes"
            # Calculates duration between two dates in minutes
            return false unless actual_value

            start_date = ConditionEvaluator.parse_date(actual_value)
            return false unless start_date

            params = parse_duration_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            end_date = if params[:end] == "now"
                         Time.now
                       else
                         ConditionEvaluator.parse_date(ConditionEvaluator.get_nested_value(context_hash,
                                                                                           params[:end]))
                       end
            return false unless end_date

            duration = ((end_date - start_date).abs / 60.0)
            compare_duration_result(duration, params)

          when "duration_hours"
            # Calculates duration between two dates in hours
            return false unless actual_value

            start_date = ConditionEvaluator.parse_date(actual_value)
            return false unless start_date

            params = parse_duration_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            end_date = if params[:end] == "now"
                         Time.now
                       else
                         ConditionEvaluator.parse_date(ConditionEvaluator.get_nested_value(context_hash,
                                                                                           params[:end]))
                       end
            return false unless end_date

            duration = ((end_date - start_date).abs / 3600.0)
            compare_duration_result(duration, params)

          when "duration_days"
            # Calculates duration between two dates in days
            return false unless actual_value

            start_date = ConditionEvaluator.parse_date(actual_value)
            return false unless start_date

            params = parse_duration_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            end_date = if params[:end] == "now"
                         Time.now
                       else
                         ConditionEvaluator.parse_date(ConditionEvaluator.get_nested_value(context_hash,
                                                                                           params[:end]))
                       end
            return false unless end_date

            duration = ((end_date - start_date).abs / 86_400.0)
            compare_duration_result(duration, params)
          end
          # Returns nil if not handled by this module
        end

        # Parse duration parameters
        def self.parse_duration_params(value, param_cache: nil, param_cache_mutex: nil)
          return nil unless value.is_a?(Hash)

          # Normalize to hash (already a hash, but normalize keys)
          normalized = Base.normalize_params_to_hash(value, [])

          cache = param_cache
          mutex = param_cache_mutex
          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = Base.normalize_param_cache_key(normalized, "duration")
          cached = cache[cache_key]
          return cached if cached

          mutex.synchronize do
            cache[cache_key] ||= parse_duration_params_impl(normalized)
          end
        end

        def self.parse_duration_params_impl(value)
          end_field = value[:end] || value["end"]
          return nil unless end_field

          {
            end: end_field.to_s,
            min: value[:min] || value["min"],
            max: value[:max] || value["max"],
            gt: value[:gt] || value["gt"],
            lt: value[:lt] || value["lt"],
            gte: value[:gte] || value["gte"],
            lte: value[:lte] || value["lte"]
          }
        end

        # Compare duration result
        def self.compare_duration_result(actual, params)
          result = true
          result &&= (actual >= params[:min]) if params[:min]
          result &&= (actual <= params[:max]) if params[:max]
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
