module DecisionAgent
  module Dsl
    module Helpers
      # Parameter parsing helpers for ConditionEvaluator
      module ParameterParsingHelpers
        def self.parse_range(value, param_cache:, param_cache_mutex:)
          normalized = Operators::Base.normalize_params_to_hash(value, %i[min max])
          cache_key = Operators::Base.normalize_param_cache_key(normalized, "range")

          cached = param_cache[cache_key]
          return cached if cached

          param_cache_mutex.synchronize do
            param_cache[cache_key] ||= parse_range_impl(normalized)
          end
        end

        def self.parse_range_impl(value)
          normalized = Operators::Base.normalize_params_to_hash(value, %i[min max])
          return nil unless normalized.is_a?(Hash)

          min = normalized[:min] || normalized["min"]
          max = normalized[:max] || normalized["max"]
          return nil unless min && max

          { min: min, max: max }
        end

        def self.parse_modulo_params(value, param_cache:, param_cache_mutex:)
          normalized = Operators::Base.normalize_params_to_hash(value, %i[divisor remainder])
          cache_key = Operators::Base.normalize_param_cache_key(normalized, "modulo")

          cached = param_cache[cache_key]
          return cached if cached

          param_cache_mutex.synchronize do
            param_cache[cache_key] ||= parse_modulo_params_impl(normalized)
          end
        end

        def self.parse_modulo_params_impl(value)
          normalized = Operators::Base.normalize_params_to_hash(value, %i[divisor remainder])
          return nil unless normalized.is_a?(Hash)

          divisor = normalized[:divisor] || normalized["divisor"]
          remainder = normalized[:remainder] || normalized["remainder"]
          return nil unless divisor && !remainder.nil?

          { divisor: divisor, remainder: remainder }
        end

        def self.parse_power_params(value)
          normalized = Operators::Base.normalize_params_to_hash(value, %i[exponent result])
          return nil unless normalized.is_a?(Hash)

          exponent = normalized[:exponent] || normalized["exponent"]
          result = normalized[:result] || normalized["result"]
          return nil unless exponent && !result.nil?

          { exponent: exponent, result: result }
        end

        def self.parse_atan2_params(value)
          normalized = Operators::Base.normalize_params_to_hash(value, %i[y result])
          return nil unless normalized.is_a?(Hash)

          y = normalized[:y] || normalized["y"]
          result = normalized[:result] || normalized["result"]
          return nil unless y && !result.nil?

          { y: y, result: result }
        end

        def self.parse_gcd_lcm_params(value)
          normalized = Operators::Base.normalize_params_to_hash(value, %i[other result])
          return nil unless normalized.is_a?(Hash)

          other = normalized[:other] || normalized["other"]
          result = normalized[:result] || normalized["result"]
          return nil unless other && !result.nil?

          { other: other, result: result }
        end

        def self.parse_percentile_params(value)
          return nil unless value.is_a?(Hash)

          percentile = value["percentile"] || value[:percentile]
          return nil unless percentile.is_a?(Numeric) && percentile >= 0 && percentile <= 100

          {
            percentile: percentile.to_f,
            threshold: value["threshold"] || value[:threshold],
            gt: value["gt"] || value[:gt],
            lt: value["lt"] || value[:lt],
            gte: value["gte"] || value[:gte],
            lte: value["lte"] || value[:lte],
            eq: value["eq"] || value[:eq]
          }
        end

        def self.parse_duration_params(value)
          return nil unless value.is_a?(Hash)

          end_field = value["end"] || value[:end]
          return nil unless end_field

          {
            end: end_field.to_s,
            min: value["min"] || value[:min],
            max: value["max"] || value[:max],
            gt: value["gt"] || value[:gt],
            lt: value["lt"] || value[:lt],
            gte: value["gte"] || value[:gte],
            lte: value["lte"] || value[:lte]
          }
        end

        def self.parse_date_arithmetic_params(value, unit = :days)
          return nil unless value.is_a?(Hash)

          unit_value = value[unit.to_s] || value[unit]
          return nil unless unit_value.is_a?(Numeric)

          {
            unit => unit_value.to_f,
            target: value["target"] || value[:target] || "now",
            compare: value["compare"] || value[:compare],
            eq: value["eq"] || value[:eq],
            gt: value["gt"] || value[:gt],
            lt: value["lt"] || value[:lt],
            gte: value["gte"] || value[:gte],
            lte: value["lte"] || value[:lte]
          }
        end

        def self.parse_moving_window_params(value)
          return nil unless value.is_a?(Hash)

          window = value["window"] || value[:window]
          return nil unless window.is_a?(Numeric) && window > 0

          {
            window: window.to_i,
            threshold: value["threshold"] || value[:threshold],
            gt: value["gt"] || value[:gt],
            lt: value["lt"] || value[:lt],
            gte: value["gte"] || value[:gte],
            lte: value["lte"] || value[:lte]
          }
        end

        def self.parse_compound_interest_params(value)
          return nil unless value.is_a?(Hash)

          rate = value["rate"] || value[:rate]
          periods = value["periods"] || value["periods"]
          return nil unless rate.is_a?(Numeric) && periods.is_a?(Numeric) && periods > 0

          {
            rate: rate.to_f,
            periods: periods.to_f,
            result: value["result"] || value[:result],
            compare: value["compare"] || value[:compare],
            threshold: value["threshold"] || value[:threshold]
          }
        end

        def self.parse_present_value_params(value)
          return nil unless value.is_a?(Hash)

          rate = value["rate"] || value[:rate]
          periods = value["periods"] || value["periods"]
          return nil unless rate.is_a?(Numeric) && periods.is_a?(Numeric) && periods > 0

          {
            rate: rate.to_f,
            periods: periods.to_f,
            result: value["result"] || value[:result]
          }
        end

        def self.parse_future_value_params(value)
          parse_present_value_params(value)
        end

        def self.parse_payment_params(value)
          parse_compound_interest_params(value)
        end

        def self.parse_join_params(value)
          return nil unless value.is_a?(Hash)

          separator = value["separator"] || value[:separator] || ","
          {
            separator: separator.to_s,
            result: value["result"] || value[:result],
            contains: value["contains"] || value[:contains]
          }
        end
      end
    end
  end
end
