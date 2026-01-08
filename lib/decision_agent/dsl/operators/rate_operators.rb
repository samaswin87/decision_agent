module DecisionAgent
  module Dsl
    module Operators
      # Handles rate calculation operators: rate_per_second, rate_per_minute, rate_per_hour
      module RateOperators
        def self.handle(op, actual_value, expected_value)
          case op
          when "rate_per_second"
            # Calculates rate per second from array of timestamps
            return false unless actual_value.is_a?(Array)
            return false if actual_value.empty?

            timestamps = actual_value.map { |ts| ConditionEvaluator.parse_date(ts) }.compact
            return false if timestamps.size < 2

            sorted_timestamps = timestamps.sort
            time_span = sorted_timestamps.last - sorted_timestamps.first
            return false if time_span <= 0

            rate = timestamps.size.to_f / time_span
            compare_rate_result(rate, expected_value)

          when "rate_per_minute"
            # Calculates rate per minute from array of timestamps
            return false unless actual_value.is_a?(Array)
            return false if actual_value.empty?

            timestamps = actual_value.map { |ts| ConditionEvaluator.parse_date(ts) }.compact
            return false if timestamps.size < 2

            sorted_timestamps = timestamps.sort
            time_span = sorted_timestamps.last - sorted_timestamps.first
            return false if time_span <= 0

            rate = (timestamps.size.to_f / time_span) * 60.0
            compare_rate_result(rate, expected_value)

          when "rate_per_hour"
            # Calculates rate per hour from array of timestamps
            return false unless actual_value.is_a?(Array)
            return false if actual_value.empty?

            timestamps = actual_value.map { |ts| ConditionEvaluator.parse_date(ts) }.compact
            return false if timestamps.size < 2

            sorted_timestamps = timestamps.sort
            time_span = sorted_timestamps.last - sorted_timestamps.first
            return false if time_span <= 0

            rate = (timestamps.size.to_f / time_span) * 3600.0
            compare_rate_result(rate, expected_value)
          end
          # Returns nil if not handled by this module
        end

        # Compare rate result
        def self.compare_rate_result(actual, expected)
          ConditionEvaluator.compare_rate_result(actual, expected)
        end
      end
    end
  end
end
