module DecisionAgent
  module Dsl
    module Helpers
      # Date/time helper methods for ConditionEvaluator
      module DateHelpers
        def self.parse_date_fast(date_string)
          return nil unless date_string.is_a?(String)

          # Fast-path: ISO8601 date format (YYYY-MM-DD)
          if date_string.match?(/^\d{4}-\d{2}-\d{2}$/)
            year, month, day = date_string.split("-").map(&:to_i)
            begin
              return Time.new(year, month, day)
            rescue StandardError
              nil
            end
          end

          # Fast-path: ISO8601 datetime format (YYYY-MM-DDTHH:MM:SS or YYYY-MM-DDTHH:MM:SSZ)
          if date_string.match?(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
            begin
              # Try ISO8601 parsing first (faster than Time.parse for this format)
              return Time.iso8601(date_string)
            rescue ArgumentError
              # Fall through to Time.parse
            end
          end

          # Fallback to Time.parse for other formats
          Time.parse(date_string)
        rescue ArgumentError, TypeError
          nil
        end

        def self.parse_date(value, get_cached_date:)
          case value
          when Time, Date, DateTime
            value
          when String
            get_cached_date.call(value)
          end
        rescue ArgumentError
          nil
        end

        def self.compare_dates(actual_value, expected_value, operator, parse_date:)
          return false unless actual_value && expected_value

          # Fast path: Both are already Time/Date objects (no parsing needed)
          actual_is_date = actual_value.is_a?(Time) || actual_value.is_a?(Date) || actual_value.is_a?(DateTime)
          expected_is_date = expected_value.is_a?(Time) || expected_value.is_a?(Date) || expected_value.is_a?(DateTime)
          return actual_value.send(operator, expected_value) if actual_is_date && expected_is_date

          # Slow path: Parse dates (with caching)
          actual_date = parse_date.call(actual_value)
          expected_date = parse_date.call(expected_value)

          return false unless actual_date && expected_date

          actual_date.send(operator, expected_date)
        end

        def self.normalize_day_of_week(value)
          case value
          when Numeric
            value.to_i % 7
          when String
            day_map = {
              "sunday" => 0, "sun" => 0,
              "monday" => 1, "mon" => 1,
              "tuesday" => 2, "tue" => 2,
              "wednesday" => 3, "wed" => 3,
              "thursday" => 4, "thu" => 4,
              "friday" => 5, "fri" => 5,
              "saturday" => 6, "sat" => 6
            }
            day_map[value.downcase]
          end
        end
      end
    end
  end
end
