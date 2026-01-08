module DecisionAgent
  module Dsl
    module Operators
      # Handles financial calculation operators: compound_interest, present_value, future_value, payment
      module FinancialOperators
        def self.handle(op, actual_value, expected_value, param_cache: nil, param_cache_mutex: nil)
          case op
          when "compound_interest"
            # Calculates compound interest: A = P(1 + r/n)^(nt)
            return false unless actual_value.is_a?(Numeric)

            params = parse_compound_interest_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            principal = actual_value
            rate = params[:rate]
            periods = params[:periods]
            result = principal * ((1 + (rate / periods))**periods)

            if params[:result]
              (result.round(2) == params[:result].round(2))
            else
              compare_financial_result(result, params)
            end

          when "present_value"
            # Calculates present value: PV = FV / (1 + r)^n
            return false unless actual_value.is_a?(Numeric)

            params = parse_present_value_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            future_value = actual_value
            rate = params[:rate]
            periods = params[:periods]
            present_value = future_value / ((1 + rate)**periods)

            if params[:result]
              (present_value.round(2) == params[:result].round(2))
            else
              compare_financial_result(present_value, params)
            end

          when "future_value"
            # Calculates future value: FV = PV * (1 + r)^n
            return false unless actual_value.is_a?(Numeric)

            params = parse_future_value_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            present_value = actual_value
            rate = params[:rate]
            periods = params[:periods]
            future_value = present_value * ((1 + rate)**periods)

            if params[:result]
              (future_value.round(2) == params[:result].round(2))
            else
              compare_financial_result(future_value, params)
            end

          when "payment"
            # Calculates loan payment: PMT = P * [r(1+r)^n] / [(1+r)^n - 1]
            return false unless actual_value.is_a?(Numeric)

            params = parse_payment_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
            return false unless params

            principal = actual_value
            rate = params[:rate]
            periods = params[:periods]

            return false if rate <= 0 || periods <= 0

            payment = if rate.zero?
                       principal / periods
                     else
                       principal * (rate * ((1 + rate)**periods)) / (((1 + rate)**periods) - 1)
                     end

            if params[:result]
              (payment.round(2) == params[:result].round(2))
            else
              compare_financial_result(payment, params)
            end

          else
            nil # Not handled by this module
          end
        end

        # Parse compound interest parameters
        def self.parse_compound_interest_params(value, param_cache: nil, param_cache_mutex: nil)
          return nil unless value.is_a?(Hash)

          normalized = Base.normalize_params_to_hash(value, [])

          cache = param_cache
          mutex = param_cache_mutex
          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = Base.normalize_param_cache_key(normalized, "compound_interest")
          cached = cache[cache_key]
          return cached if cached

          mutex.synchronize do
            cache[cache_key] ||= parse_compound_interest_params_impl(normalized)
          end
        end

        def self.parse_compound_interest_params_impl(value)
          rate = value[:rate] || value["rate"]
          periods = value[:periods] || value["periods"]
          return nil unless rate.is_a?(Numeric) && periods.is_a?(Numeric) && periods > 0

          {
            rate: rate.to_f,
            periods: periods.to_f,
            result: value[:result] || value["result"],
            compare: value[:compare] || value["compare"],
            threshold: value[:threshold] || value["threshold"]
          }
        end

        # Parse present value parameters
        def self.parse_present_value_params(value, param_cache: nil, param_cache_mutex: nil)
          return nil unless value.is_a?(Hash)

          normalized = Base.normalize_params_to_hash(value, [])

          cache = param_cache
          mutex = param_cache_mutex
          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = Base.normalize_param_cache_key(normalized, "present_value")
          cached = cache[cache_key]
          return cached if cached

          mutex.synchronize do
            cache[cache_key] ||= parse_present_value_params_impl(normalized)
          end
        end

        def self.parse_present_value_params_impl(value)
          rate = value[:rate] || value["rate"]
          periods = value[:periods] || value["periods"]
          return nil unless rate.is_a?(Numeric) && periods.is_a?(Numeric) && periods > 0

          {
            rate: rate.to_f,
            periods: periods.to_f,
            result: value[:result] || value["result"]
          }
        end

        # Parse future value parameters
        def self.parse_future_value_params(value, param_cache: nil, param_cache_mutex: nil)
          return nil unless value.is_a?(Hash)

          normalized = Base.normalize_params_to_hash(value, [])

          cache = param_cache
          mutex = param_cache_mutex
          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = Base.normalize_param_cache_key(normalized, "future_value")
          cached = cache[cache_key]
          return cached if cached

          mutex.synchronize do
            cache[cache_key] ||= parse_future_value_params_impl(normalized)
          end
        end

        def self.parse_future_value_params_impl(value)
          rate = value[:rate] || value["rate"]
          periods = value[:periods] || value["periods"]
          return nil unless rate.is_a?(Numeric) && periods.is_a?(Numeric) && periods > 0

          {
            rate: rate.to_f,
            periods: periods.to_f,
            result: value[:result] || value["result"]
          }
        end

        # Parse payment parameters
        def self.parse_payment_params(value, param_cache: nil, param_cache_mutex: nil)
          return nil unless value.is_a?(Hash)

          normalized = Base.normalize_params_to_hash(value, [])

          cache = param_cache
          mutex = param_cache_mutex
          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = Base.normalize_param_cache_key(normalized, "payment")
          cached = cache[cache_key]
          return cached if cached

          mutex.synchronize do
            cache[cache_key] ||= parse_payment_params_impl(normalized)
          end
        end

        def self.parse_payment_params_impl(value)
          rate = value[:rate] || value["rate"]
          periods = value[:periods] || value["periods"]
          return nil unless rate.is_a?(Numeric) && periods.is_a?(Numeric) && periods > 0

          {
            rate: rate.to_f,
            periods: periods.to_f,
            result: value[:result] || value["result"]
          }
        end

        # Compare financial result
        def self.compare_financial_result(actual, params)
          ConditionEvaluator.compare_financial_result(actual, params)
        end
      end
    end
  end
end
