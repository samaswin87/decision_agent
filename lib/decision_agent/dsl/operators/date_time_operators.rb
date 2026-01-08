module DecisionAgent
  module Dsl
    module Operators
      # Handles date/time operators: before_date, after_date, within_days, day_of_week
      module DateTimeOperators
        def self.handle(op, actual_value, expected_value, date_cache: nil, date_cache_mutex: nil)
          case op
          when "before_date"
            # Checks if date is before specified date
            ConditionEvaluator.compare_dates(actual_value, expected_value, :<)

          when "after_date"
            # Checks if date is after specified date
            ConditionEvaluator.compare_dates(actual_value, expected_value, :>)

          when "within_days"
            # Checks if date is within N days from now (past or future)
            return false unless actual_value
            return false unless expected_value.is_a?(Numeric)

            date = ConditionEvaluator.parse_date(actual_value)
            return false unless date

            now = Time.now
            diff_days = ((date - now) / 86_400).abs # 86400 seconds in a day
            diff_days <= expected_value

          when "day_of_week"
            # Checks if date falls on specified day of week
            return false unless actual_value

            date = ConditionEvaluator.parse_date(actual_value)
            return false unless date

            expected_day = ConditionEvaluator.normalize_day_of_week(expected_value)
            return false unless expected_day

            date.wday == expected_day

          else
            nil # Not handled by this module
          end
        end
      end
    end
  end
end
