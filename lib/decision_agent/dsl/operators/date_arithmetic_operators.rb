module DecisionAgent
  module Dsl
    module Operators
      # Handles date arithmetic operators: add_days, subtract_days, add_hours, subtract_hours, add_minutes, subtract_minutes
      module DateArithmeticOperators
        def self.handle(op, actual_value, expected_value, context_hash, param_cache: nil, param_cache_mutex: nil)
          case op
          when "add_days"
            # Adds days to a date and compares
            return false unless actual_value

            start_date = ConditionEvaluator.parse_date(actual_value)
            return false unless start_date

            params = parse_date_arithmetic_params(expected_value, :days, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            result_date = start_date + (params[:days] * 86_400)
            target_date = if params[:target] == "now"
                            Time.now
                          else
                            ConditionEvaluator.parse_date(ConditionEvaluator.get_nested_value(context_hash, params[:target]))
                          end
            return false unless target_date

            compare_date_result?(result_date, target_date, params)

          when "subtract_days"
            # Subtracts days from a date and compares
            return false unless actual_value

            start_date = ConditionEvaluator.parse_date(actual_value)
            return false unless start_date

            params = parse_date_arithmetic_params(expected_value, :days, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            result_date = start_date - (params[:days] * 86_400)
            target_date = if params[:target] == "now"
                            Time.now
                          else
                            ConditionEvaluator.parse_date(ConditionEvaluator.get_nested_value(context_hash, params[:target]))
                          end
            return false unless target_date

            compare_date_result?(result_date, target_date, params)

          when "add_hours"
            # Adds hours to a date and compares
            return false unless actual_value

            start_date = ConditionEvaluator.parse_date(actual_value)
            return false unless start_date

            params = parse_date_arithmetic_params(expected_value, :hours, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            result_date = start_date + (params[:hours] * 3600)
            target_date = if params[:target] == "now"
                            Time.now
                          else
                            ConditionEvaluator.parse_date(ConditionEvaluator.get_nested_value(context_hash, params[:target]))
                          end
            return false unless target_date

            compare_date_result?(result_date, target_date, params)

          when "subtract_hours"
            # Subtracts hours from a date and compares
            return false unless actual_value

            start_date = ConditionEvaluator.parse_date(actual_value)
            return false unless start_date

            params = parse_date_arithmetic_params(expected_value, :hours, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            result_date = start_date - (params[:hours] * 3600)
            target_date = if params[:target] == "now"
                            Time.now
                          else
                            ConditionEvaluator.parse_date(ConditionEvaluator.get_nested_value(context_hash, params[:target]))
                          end
            return false unless target_date

            compare_date_result?(result_date, target_date, params)

          when "add_minutes"
            # Adds minutes to a date and compares
            return false unless actual_value

            start_date = ConditionEvaluator.parse_date(actual_value)
            return false unless start_date

            params = parse_date_arithmetic_params(expected_value, :minutes, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            result_date = start_date + (params[:minutes] * 60)
            target_date = if params[:target] == "now"
                            Time.now
                          else
                            ConditionEvaluator.parse_date(ConditionEvaluator.get_nested_value(context_hash, params[:target]))
                          end
            return false unless target_date

            compare_date_result?(result_date, target_date, params)

          when "subtract_minutes"
            # Subtracts minutes from a date and compares
            return false unless actual_value

            start_date = ConditionEvaluator.parse_date(actual_value)
            return false unless start_date

            params = parse_date_arithmetic_params(expected_value, :minutes, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            result_date = start_date - (params[:minutes] * 60)
            target_date = if params[:target] == "now"
                            Time.now
                          else
                            ConditionEvaluator.parse_date(ConditionEvaluator.get_nested_value(context_hash, params[:target]))
                          end
            return false unless target_date

            compare_date_result?(result_date, target_date, params)
          end
          # Returns nil if not handled by this module
        end

        # Parse date arithmetic parameters
        def self.parse_date_arithmetic_params(value, unit = :days, param_cache: nil, param_cache_mutex: nil)
          return nil unless value.is_a?(Hash)

          # Normalize to hash (already a hash, but normalize keys)
          normalized = Base.normalize_params_to_hash(value, [])

          cache = param_cache
          mutex = param_cache_mutex
          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = Base.normalize_param_cache_key(normalized, "date_arithmetic_#{unit}")
          cached = cache[cache_key]
          return cached if cached

          mutex.synchronize do
            cache[cache_key] ||= parse_date_arithmetic_params_impl(normalized, unit)
          end
        end

        def self.parse_date_arithmetic_params_impl(value, unit)
          unit_value = value[unit.to_s] || value[unit]
          return nil unless unit_value.is_a?(Numeric)

          {
            unit => unit_value.to_f,
            target: value[:target] || value["target"] || "now",
            compare: value[:compare] || value["compare"],
            eq: value[:eq] || value["eq"],
            gt: value[:gt] || value["gt"],
            lt: value[:lt] || value["lt"],
            gte: value[:gte] || value["gte"],
            lte: value[:lte] || value["lte"]
          }
        end

        # Compare date result
        def self.compare_date_result?(actual, target, params)
          if params[:compare]
            case params[:compare].to_s
            when "eq", "=="
              (actual - target).abs < 1
            when "gt", ">"
              actual > target
            when "lt", "<"
              actual < target
            when "gte", ">="
              actual >= target
            when "lte", "<="
              actual <= target
            else
              false
            end
          elsif params[:eq]
            (actual - target).abs < 1
          elsif params[:gt]
            actual > target
          elsif params[:lt]
            actual < target
          elsif params[:gte]
            actual >= target
          elsif params[:lte]
            actual <= target
          else
            false
          end
        end
      end
    end
  end
end
