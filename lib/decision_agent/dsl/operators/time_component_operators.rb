module DecisionAgent
  module Dsl
    module Operators
      # Handles time component extraction operators: hour_of_day, day_of_month, month, year, week_of_year
      module TimeComponentOperators
        def self.handle(op, actual_value, expected_value)
          case op
          when "hour_of_day"
            # Extracts hour of day (0-23) and compares
            return false unless actual_value

            date = ConditionEvaluator.parse_date(actual_value)
            return false unless date

            hour = date.hour
            compare_numeric_result(hour, expected_value)

          when "day_of_month"
            # Extracts day of month (1-31) and compares
            return false unless actual_value

            date = ConditionEvaluator.parse_date(actual_value)
            return false unless date

            day = date.day
            compare_numeric_result(day, expected_value)

          when "month"
            # Extracts month (1-12) and compares
            return false unless actual_value

            date = ConditionEvaluator.parse_date(actual_value)
            return false unless date

            month = date.month
            compare_numeric_result(month, expected_value)

          when "year"
            # Extracts year and compares
            return false unless actual_value

            date = ConditionEvaluator.parse_date(actual_value)
            return false unless date

            year = date.year
            compare_numeric_result(year, expected_value)

          when "week_of_year"
            # Extracts week of year (1-52) and compares
            return false unless actual_value

            date = ConditionEvaluator.parse_date(actual_value)
            return false unless date

            week = date.strftime("%U").to_i + 1 # %U returns 0-53, we want 1-53
            compare_numeric_result(week, expected_value)
          end
          # Returns nil if not handled by this module
        end

        # Compare numeric result (for time component extraction)
        def self.compare_numeric_result(actual, expected)
          return actual == expected unless expected.is_a?(Hash)

          Helpers::ComparisonHelpers.compare_numeric_with_hash(actual, expected)
        end
      end
    end
  end
end
