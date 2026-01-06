require "set"

module DecisionAgent
  module Dsl
    # Evaluates conditions in the rule DSL against a context
    #
    # Supports:
    # - Field conditions with various operators
    # - Nested field access via dot notation (e.g., "user.profile.role")
    # - Logical operators (all/any)
    # rubocop:disable Metrics/ClassLength
    class ConditionEvaluator
      # Thread-safe caches for performance optimization
      @regex_cache = {}
      @regex_cache_mutex = Mutex.new
      @path_cache = {}
      @path_cache_mutex = Mutex.new
      @date_cache = {}
      @date_cache_mutex = Mutex.new
      @geospatial_cache = {}
      @geospatial_cache_mutex = Mutex.new
      @param_cache = {}
      @param_cache_mutex = Mutex.new

      class << self
        attr_reader :regex_cache, :path_cache, :date_cache, :geospatial_cache, :param_cache
      end

      def self.evaluate(condition, context, enriched_context_hash: nil)
        return false unless condition.is_a?(Hash)

        # Use enriched context hash if provided, otherwise create mutable copy
        # This ensures all conditions in the same evaluation share the same enriched hash
        enriched = enriched_context_hash
        enriched ||= context.to_h.dup

        if condition.key?("all")
          evaluate_all(condition["all"], context, enriched_context_hash: enriched)
        elsif condition.key?("any")
          evaluate_any(condition["any"], context, enriched_context_hash: enriched)
        elsif condition.key?("field")
          evaluate_field_condition(condition, context, enriched_context_hash: enriched)
        else
          false
        end
      end

      # Evaluates 'all' condition - returns true only if ALL sub-conditions are true
      # Empty array returns true (vacuous truth)
      def self.evaluate_all(conditions, context, enriched_context_hash: nil)
        return true if conditions.is_a?(Array) && conditions.empty?
        return false unless conditions.is_a?(Array)

        # Use enriched context hash if provided, otherwise create mutable copy
        # All conditions share the same enriched hash so data enrichment persists
        enriched = enriched_context_hash
        enriched ||= context.to_h.dup

        conditions.all? { |cond| evaluate(cond, context, enriched_context_hash: enriched) }
      end

      # Evaluates 'any' condition - returns true if AT LEAST ONE sub-condition is true
      # Empty array returns false (no options to match)
      def self.evaluate_any(conditions, context, enriched_context_hash: nil)
        return false unless conditions.is_a?(Array)

        # Use enriched context hash if provided, otherwise create mutable copy
        # All conditions share the same enriched hash so data enrichment persists
        enriched = enriched_context_hash
        enriched ||= context.to_h.dup

        conditions.any? { |cond| evaluate(cond, context, enriched_context_hash: enriched) }
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def self.evaluate_field_condition(condition, context, enriched_context_hash: nil)
        field = condition["field"]
        op = condition["op"]
        expected_value = condition["value"]

        # Special handling for "don't care" conditions (from DMN "-" entries)
        return true if field == "__always_match__" && op == "eq" && expected_value == true

        # Use enriched context hash if provided, otherwise create mutable copy
        # This ensures all conditions in the same evaluation share the same enriched hash
        context_hash = enriched_context_hash || context.to_h.dup
        actual_value = get_nested_value(context_hash, field)

        case op
        when "eq"
          # Equality - uses Ruby's == for comparison
          actual_value == expected_value

        when "neq"
          # Not equal - inverse of ==
          actual_value != expected_value

        when "gt"
          # Greater than - only for comparable types (numbers, strings)
          comparable?(actual_value, expected_value) && actual_value > expected_value

        when "gte"
          # Greater than or equal - only for comparable types
          comparable?(actual_value, expected_value) && actual_value >= expected_value

        when "lt"
          # Less than - only for comparable types
          comparable?(actual_value, expected_value) && actual_value < expected_value

        when "lte"
          # Less than or equal - only for comparable types
          comparable?(actual_value, expected_value) && actual_value <= expected_value

        when "in"
          # Array membership - checks if actual_value is in the expected array
          Array(expected_value).include?(actual_value)

        when "present"
          # PRESENT SEMANTICS:
          # Returns true if value exists AND is not empty
          # - nil: false
          # - Empty string "": false
          # - Empty array []: false
          # - Empty hash {}: false
          # - Zero 0: true (zero is a valid value)
          # - False boolean: true (false is a valid value)
          # - Non-empty values: true
          !actual_value.nil? && (actual_value.respond_to?(:empty?) ? !actual_value.empty? : true)

        when "blank"
          # BLANK SEMANTICS:
          # Returns true if value is nil OR empty
          # - nil: true
          # - Empty string "": true
          # - Empty array []: true
          # - Empty hash {}: true
          # - Zero 0: false (zero is a valid value)
          # - False boolean: false (false is a valid value)
          # - Non-empty values: false
          actual_value.nil? || (actual_value.respond_to?(:empty?) ? actual_value.empty? : false)

        # STRING OPERATORS
        when "contains"
          # Checks if string contains substring (case-sensitive)
          string_operator?(actual_value, expected_value) &&
            actual_value.include?(expected_value)

        when "starts_with"
          # Checks if string starts with prefix (case-sensitive)
          string_operator?(actual_value, expected_value) &&
            actual_value.start_with?(expected_value)

        when "ends_with"
          # Checks if string ends with suffix (case-sensitive)
          string_operator?(actual_value, expected_value) &&
            actual_value.end_with?(expected_value)

        when "matches"
          # Matches string against regular expression
          # expected_value can be a string (converted to regex) or Regexp object
          return false unless actual_value.is_a?(String)
          return false if expected_value.nil?

          begin
            regex = get_cached_regex(expected_value)
            !regex.match(actual_value).nil?
          rescue RegexpError
            false
          end

        # NUMERIC OPERATORS
        when "between"
          # Checks if numeric value is between min and max (inclusive)
          # expected_value should be [min, max] or {min: x, max: y}
          return false unless actual_value.is_a?(Numeric)

          range = parse_range(expected_value)
          return false unless range

          actual_value.between?(range[:min], range[:max])

        when "modulo"
          # Checks if value modulo divisor equals remainder
          # expected_value should be [divisor, remainder] or {divisor: x, remainder: y}
          return false unless actual_value.is_a?(Numeric)

          params = parse_modulo_params(expected_value)
          return false unless params

          (actual_value % params[:divisor]) == params[:remainder]

        # MATHEMATICAL FUNCTIONS
        # Trigonometric functions
        when "sin"
          # Checks if sin(field_value) equals expected_value
          # expected_value is the expected result of sin(actual_value)
          return false unless actual_value.is_a?(Numeric)
          return false unless expected_value.is_a?(Numeric)

          # OPTIMIZE: Use epsilon comparison instead of round for better performance
          result = Math.sin(actual_value)
          (result - expected_value).abs < 1e-10

        when "cos"
          # Checks if cos(field_value) equals expected_value
          # expected_value is the expected result of cos(actual_value)
          return false unless actual_value.is_a?(Numeric)
          return false unless expected_value.is_a?(Numeric)

          # OPTIMIZE: Use epsilon comparison instead of round for better performance
          result = Math.cos(actual_value)
          (result - expected_value).abs < 1e-10

        when "tan"
          # Checks if tan(field_value) equals expected_value
          # expected_value is the expected result of tan(actual_value)
          return false unless actual_value.is_a?(Numeric)
          return false unless expected_value.is_a?(Numeric)

          # OPTIMIZE: Use epsilon comparison instead of round for better performance
          result = Math.tan(actual_value)
          (result - expected_value).abs < 1e-10

        # Exponential and logarithmic functions
        when "sqrt"
          # Checks if sqrt(field_value) equals expected_value
          # expected_value is the expected result of sqrt(actual_value)
          return false unless actual_value.is_a?(Numeric)
          return false unless expected_value.is_a?(Numeric)
          return false if actual_value.negative? # sqrt of negative number is invalid

          # OPTIMIZE: Use epsilon comparison instead of round for better performance
          result = Math.sqrt(actual_value)
          (result - expected_value).abs < 1e-10

        when "power"
          # Checks if power(field_value, exponent) equals result
          # expected_value should be [exponent, result] or {exponent: x, result: y}
          return false unless actual_value.is_a?(Numeric)

          params = parse_power_params(expected_value)
          return false unless params

          # OPTIMIZE: Use epsilon comparison instead of round for better performance
          result = actual_value**params[:exponent]
          (result - params[:result]).abs < 1e-10

        when "exp"
          # Checks if exp(field_value) equals expected_value
          # expected_value is the expected result of exp(actual_value) (e^actual_value)
          return false unless actual_value.is_a?(Numeric)
          return false unless expected_value.is_a?(Numeric)

          # OPTIMIZE: Use epsilon comparison instead of round for better performance
          result = Math.exp(actual_value)
          (result - expected_value).abs < 1e-10

        when "log"
          # Checks if log(field_value) equals expected_value
          # expected_value is the expected result of log(actual_value) (natural logarithm)
          return false unless actual_value.is_a?(Numeric)
          return false unless expected_value.is_a?(Numeric)
          return false if actual_value <= 0 # log of non-positive number is invalid

          # OPTIMIZE: Use epsilon comparison instead of round for better performance
          result = Math.log(actual_value)
          (result - expected_value).abs < 1e-10

        # Rounding and absolute value functions
        when "round"
          # Checks if round(field_value) equals expected_value
          # expected_value is the expected result of round(actual_value)
          return false unless actual_value.is_a?(Numeric)
          return false unless expected_value.is_a?(Numeric)

          actual_value.round == expected_value

        when "floor"
          # Checks if floor(field_value) equals expected_value
          # expected_value is the expected result of floor(actual_value)
          return false unless actual_value.is_a?(Numeric)
          return false unless expected_value.is_a?(Numeric)

          actual_value.floor == expected_value

        when "ceil"
          # Checks if ceil(field_value) equals expected_value
          # expected_value is the expected result of ceil(actual_value)
          return false unless actual_value.is_a?(Numeric)
          return false unless expected_value.is_a?(Numeric)

          actual_value.ceil == expected_value

        when "abs"
          # Checks if abs(field_value) equals expected_value
          # expected_value is the expected result of abs(actual_value)
          return false unless actual_value.is_a?(Numeric)
          return false unless expected_value.is_a?(Numeric)

          actual_value.abs == expected_value

        # Aggregation functions
        when "min"
          # Checks if min(field_value) equals expected_value
          # field_value should be an array, expected_value is the minimum value
          return false unless actual_value.is_a?(Array)
          return false if actual_value.empty?
          return false unless expected_value.is_a?(Numeric)

          actual_value.min == expected_value

        when "max"
          # Checks if max(field_value) equals expected_value
          # field_value should be an array, expected_value is the maximum value
          return false unless actual_value.is_a?(Array)
          return false if actual_value.empty?
          return false unless expected_value.is_a?(Numeric)

          actual_value.max == expected_value

        # STATISTICAL AGGREGATIONS
        when "sum"
          # Checks if sum of numeric array equals expected_value
          # expected_value can be numeric or hash with comparison operators
          return false unless actual_value.is_a?(Array)
          return false if actual_value.empty?

          # OPTIMIZE: calculate sum in single pass, filtering as we go
          sum_value = 0.0
          found_numeric = false
          actual_value.each do |v|
            if v.is_a?(Numeric)
              sum_value += v
              found_numeric = true
            end
          end
          return false unless found_numeric

          compare_aggregation_result(sum_value, expected_value)

        when "average", "mean"
          # Checks if average of numeric array equals expected_value
          return false unless actual_value.is_a?(Array)
          return false if actual_value.empty?

          # OPTIMIZE: calculate sum and count in single pass
          sum_value = 0.0
          count = 0
          actual_value.each do |v|
            if v.is_a?(Numeric)
              sum_value += v
              count += 1
            end
          end
          return false if count.zero?

          avg_value = sum_value / count
          compare_aggregation_result(avg_value, expected_value)

        when "median"
          # Checks if median of numeric array equals expected_value
          return false unless actual_value.is_a?(Array)
          return false if actual_value.empty?

          numeric_array = actual_value.select { |v| v.is_a?(Numeric) }.sort
          return false if numeric_array.empty?

          median_value = if numeric_array.size.odd?
                           numeric_array[numeric_array.size / 2]
                         else
                           (numeric_array[(numeric_array.size / 2) - 1] + numeric_array[numeric_array.size / 2]) / 2.0
                         end
          compare_aggregation_result(median_value, expected_value)

        when "stddev", "standard_deviation"
          # Checks if standard deviation of numeric array equals expected_value
          return false unless actual_value.is_a?(Array)
          return false if actual_value.size < 2

          numeric_array = actual_value.select { |v| v.is_a?(Numeric) }
          return false if numeric_array.size < 2

          mean = numeric_array.sum.to_f / numeric_array.size
          variance = numeric_array.sum { |v| (v - mean)**2 } / numeric_array.size
          stddev_value = Math.sqrt(variance)
          compare_aggregation_result(stddev_value, expected_value)

        when "variance"
          # Checks if variance of numeric array equals expected_value
          return false unless actual_value.is_a?(Array)
          return false if actual_value.size < 2

          numeric_array = actual_value.select { |v| v.is_a?(Numeric) }
          return false if numeric_array.size < 2

          mean = numeric_array.sum.to_f / numeric_array.size
          variance_value = numeric_array.sum { |v| (v - mean)**2 } / numeric_array.size
          compare_aggregation_result(variance_value, expected_value)

        when "percentile"
          # Checks if Nth percentile of numeric array meets threshold
          # expected_value: {percentile: 95, threshold: 200} or {percentile: 95, gt: 200, lt: 500}
          return false unless actual_value.is_a?(Array)
          return false if actual_value.empty?

          numeric_array = actual_value.select { |v| v.is_a?(Numeric) }.sort
          return false if numeric_array.empty?

          params = parse_percentile_params(expected_value)
          return false unless params

          percentile_index = (params[:percentile] / 100.0) * (numeric_array.size - 1)
          percentile_value = if percentile_index == percentile_index.to_i
                               numeric_array[percentile_index.to_i]
                             else
                               lower = numeric_array[percentile_index.floor]
                               upper = numeric_array[percentile_index.ceil]
                               lower + ((upper - lower) * (percentile_index - percentile_index.floor))
                             end

          compare_percentile_result(percentile_value, params)

        when "count"
          # Checks if count of array elements meets threshold
          # expected_value can be numeric or hash with comparison operators
          return false unless actual_value.is_a?(Array)

          count_value = actual_value.size
          compare_aggregation_result(count_value, expected_value)

        # DATE/TIME OPERATORS
        when "before_date"
          # Checks if date is before specified date
          compare_dates(actual_value, expected_value, :<)

        when "after_date"
          # Checks if date is after specified date
          compare_dates(actual_value, expected_value, :>)

        when "within_days"
          # Checks if date is within N days from now (past or future)
          # expected_value is number of days
          return false unless actual_value
          return false unless expected_value.is_a?(Numeric)

          date = parse_date(actual_value)
          return false unless date

          now = Time.now
          diff_days = ((date - now) / 86_400).abs # 86400 seconds in a day
          diff_days <= expected_value

        when "day_of_week"
          # Checks if date falls on specified day of week
          # expected_value can be: "monday", "tuesday", etc. or 0-6 (Sunday=0)
          return false unless actual_value

          date = parse_date(actual_value)
          return false unless date

          expected_day = normalize_day_of_week(expected_value)
          return false unless expected_day

          date.wday == expected_day

        # DURATION CALCULATIONS
        when "duration_seconds"
          # Calculates duration between two dates in seconds
          # expected_value: {end: "field.path", max: 3600} or {end: "now", min: 60}
          return false unless actual_value

          start_date = parse_date(actual_value)
          return false unless start_date

          params = parse_duration_params(expected_value)
          return false unless params

          end_date = params[:end] == "now" ? Time.now : parse_date(get_nested_value(context_hash, params[:end]))
          return false unless end_date

          duration = (end_date - start_date).abs
          compare_duration_result(duration, params)

        when "duration_minutes"
          # Calculates duration between two dates in minutes
          return false unless actual_value

          start_date = parse_date(actual_value)
          return false unless start_date

          params = parse_duration_params(expected_value)
          return false unless params

          end_date = params[:end] == "now" ? Time.now : parse_date(get_nested_value(context_hash, params[:end]))
          return false unless end_date

          duration = ((end_date - start_date).abs / 60.0)
          compare_duration_result(duration, params)

        when "duration_hours"
          # Calculates duration between two dates in hours
          return false unless actual_value

          start_date = parse_date(actual_value)
          return false unless start_date

          params = parse_duration_params(expected_value)
          return false unless params

          end_date = params[:end] == "now" ? Time.now : parse_date(get_nested_value(context_hash, params[:end]))
          return false unless end_date

          duration = ((end_date - start_date).abs / 3600.0)
          compare_duration_result(duration, params)

        when "duration_days"
          # Calculates duration between two dates in days
          return false unless actual_value

          start_date = parse_date(actual_value)
          return false unless start_date

          params = parse_duration_params(expected_value)
          return false unless params

          end_date = params[:end] == "now" ? Time.now : parse_date(get_nested_value(context_hash, params[:end]))
          return false unless end_date

          duration = ((end_date - start_date).abs / 86_400.0)
          compare_duration_result(duration, params)

        # DATE ARITHMETIC
        when "add_days"
          # Adds days to a date and compares
          # expected_value: {days: 7, compare: "lt", target: "now"} or {days: 7, eq: target_date}
          return false unless actual_value

          start_date = parse_date(actual_value)
          return false unless start_date

          params = parse_date_arithmetic_params(expected_value)
          return false unless params

          result_date = start_date + (params[:days] * 86_400)
          target_date = params[:target] == "now" ? Time.now : parse_date(get_nested_value(context_hash, params[:target]))
          return false unless target_date

          compare_date_result?(result_date, target_date, params)

        when "subtract_days"
          # Subtracts days from a date and compares
          return false unless actual_value

          start_date = parse_date(actual_value)
          return false unless start_date

          params = parse_date_arithmetic_params(expected_value)
          return false unless params

          result_date = start_date - (params[:days] * 86_400)
          target_date = params[:target] == "now" ? Time.now : parse_date(get_nested_value(context_hash, params[:target]))
          return false unless target_date

          compare_date_result?(result_date, target_date, params)

        when "add_hours"
          # Adds hours to a date and compares
          return false unless actual_value

          start_date = parse_date(actual_value)
          return false unless start_date

          params = parse_date_arithmetic_params(expected_value, :hours)
          return false unless params

          result_date = start_date + (params[:hours] * 3600)
          target_date = params[:target] == "now" ? Time.now : parse_date(get_nested_value(context_hash, params[:target]))
          return false unless target_date

          compare_date_result?(result_date, target_date, params)

        when "subtract_hours"
          # Subtracts hours from a date and compares
          return false unless actual_value

          start_date = parse_date(actual_value)
          return false unless start_date

          params = parse_date_arithmetic_params(expected_value, :hours)
          return false unless params

          result_date = start_date - (params[:hours] * 3600)
          target_date = params[:target] == "now" ? Time.now : parse_date(get_nested_value(context_hash, params[:target]))
          return false unless target_date

          compare_date_result?(result_date, target_date, params)

        when "add_minutes"
          # Adds minutes to a date and compares
          return false unless actual_value

          start_date = parse_date(actual_value)
          return false unless start_date

          params = parse_date_arithmetic_params(expected_value, :minutes)
          return false unless params

          result_date = start_date + (params[:minutes] * 60)
          target_date = params[:target] == "now" ? Time.now : parse_date(get_nested_value(context_hash, params[:target]))
          return false unless target_date

          compare_date_result?(result_date, target_date, params)

        when "subtract_minutes"
          # Subtracts minutes from a date and compares
          return false unless actual_value

          start_date = parse_date(actual_value)
          return false unless start_date

          params = parse_date_arithmetic_params(expected_value, :minutes)
          return false unless params

          result_date = start_date - (params[:minutes] * 60)
          target_date = params[:target] == "now" ? Time.now : parse_date(get_nested_value(context_hash, params[:target]))
          return false unless target_date

          compare_date_result?(result_date, target_date, params)

        # TIME COMPONENT EXTRACTION
        when "hour_of_day"
          # Extracts hour of day (0-23) and compares
          return false unless actual_value

          date = parse_date(actual_value)
          return false unless date

          hour = date.hour
          compare_numeric_result(hour, expected_value)

        when "day_of_month"
          # Extracts day of month (1-31) and compares
          return false unless actual_value

          date = parse_date(actual_value)
          return false unless date

          day = date.day
          compare_numeric_result(day, expected_value)

        when "month"
          # Extracts month (1-12) and compares
          return false unless actual_value

          date = parse_date(actual_value)
          return false unless date

          month = date.month
          compare_numeric_result(month, expected_value)

        when "year"
          # Extracts year and compares
          return false unless actual_value

          date = parse_date(actual_value)
          return false unless date

          year = date.year
          compare_numeric_result(year, expected_value)

        when "week_of_year"
          # Extracts week of year (1-52) and compares
          return false unless actual_value

          date = parse_date(actual_value)
          return false unless date

          week = date.strftime("%U").to_i + 1 # %U returns 0-53, we want 1-53
          compare_numeric_result(week, expected_value)

        # RATE CALCULATIONS
        when "rate_per_second"
          # Calculates rate per second from array of timestamps
          # expected_value: {max: 10} or {min: 5, max: 100}
          return false unless actual_value.is_a?(Array)
          return false if actual_value.empty?

          timestamps = actual_value.map { |ts| parse_date(ts) }.compact
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

          timestamps = actual_value.map { |ts| parse_date(ts) }.compact
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

          timestamps = actual_value.map { |ts| parse_date(ts) }.compact
          return false if timestamps.size < 2

          sorted_timestamps = timestamps.sort
          time_span = sorted_timestamps.last - sorted_timestamps.first
          return false if time_span <= 0

          rate = (timestamps.size.to_f / time_span) * 3600.0
          compare_rate_result(rate, expected_value)

        # MOVING WINDOW CALCULATIONS
        when "moving_average"
          # Calculates moving average over window
          # expected_value: {window: 5, threshold: 100} or {window: 5, gt: 100}
          return false unless actual_value.is_a?(Array)
          return false if actual_value.empty?

          # OPTIMIZE: filter once and reuse
          numeric_array = actual_value.select { |v| v.is_a?(Numeric) }
          return false if numeric_array.empty?

          params = parse_moving_window_params(expected_value)
          return false unless params

          window = [params[:window], numeric_array.size].min
          return false if window < 1

          # OPTIMIZE: use slice instead of last for better performance
          window_array = numeric_array.slice(-window, window)
          moving_avg = window_array.sum.to_f / window
          compare_moving_window_result(moving_avg, params)

        when "moving_sum"
          # Calculates moving sum over window
          return false unless actual_value.is_a?(Array)
          return false if actual_value.empty?

          numeric_array = actual_value.select { |v| v.is_a?(Numeric) }
          return false if numeric_array.empty?

          params = parse_moving_window_params(expected_value)
          return false unless params

          window = [params[:window], numeric_array.size].min
          return false if window < 1

          # OPTIMIZE: use slice instead of last
          window_array = numeric_array.slice(-window, window)
          moving_sum = window_array.sum
          compare_moving_window_result(moving_sum, params)

        when "moving_max"
          # Calculates moving max over window
          return false unless actual_value.is_a?(Array)
          return false if actual_value.empty?

          numeric_array = actual_value.select { |v| v.is_a?(Numeric) }
          return false if numeric_array.empty?

          params = parse_moving_window_params(expected_value)
          return false unless params

          window = [params[:window], numeric_array.size].min
          return false if window < 1

          # OPTIMIZE: use slice instead of last, iterate directly for max
          window_array = numeric_array.slice(-window, window)
          moving_max = window_array.max
          compare_moving_window_result(moving_max, params)

        when "moving_min"
          # Calculates moving min over window
          return false unless actual_value.is_a?(Array)
          return false if actual_value.empty?

          numeric_array = actual_value.select { |v| v.is_a?(Numeric) }
          return false if numeric_array.empty?

          params = parse_moving_window_params(expected_value)
          return false unless params

          window = [params[:window], numeric_array.size].min
          return false if window < 1

          # OPTIMIZE: use slice instead of last
          window_array = numeric_array.slice(-window, window)
          moving_min = window_array.min
          compare_moving_window_result(moving_min, params)

        # FINANCIAL CALCULATIONS
        when "compound_interest"
          # Calculates compound interest: A = P(1 + r/n)^(nt)
          # expected_value: {rate: 0.05, periods: 12, result: 1050} or {rate: 0.05, periods: 12, compare: "gt", threshold: 1000}
          return false unless actual_value.is_a?(Numeric)

          params = parse_compound_interest_params(expected_value)
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
          # expected_value: {rate: 0.05, periods: 10, result: 613.91}
          return false unless actual_value.is_a?(Numeric)

          params = parse_present_value_params(expected_value)
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
          # expected_value: {rate: 0.05, periods: 10, result: 1628.89}
          return false unless actual_value.is_a?(Numeric)

          params = parse_future_value_params(expected_value)
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
          # expected_value: {rate: 0.05, periods: 12, result: 100}
          return false unless actual_value.is_a?(Numeric)

          params = parse_payment_params(expected_value)
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

        # STRING AGGREGATIONS
        when "join"
          # Joins array of strings with separator
          # expected_value: {separator: ",", result: "a,b,c"} or {separator: ",", contains: "a"}
          return false unless actual_value.is_a?(Array)
          return false if actual_value.empty?

          string_array = actual_value.map(&:to_s)
          params = parse_join_params(expected_value)
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
          # expected_value: {max: 500} or {min: 10, max: 100}
          return false if actual_value.nil?

          length_value = if actual_value.is_a?(String) || actual_value.is_a?(Array)
                           actual_value.length
                         else
                           return false
                         end

          compare_length_result(length_value, expected_value)

        # COLLECTION OPERATORS
        when "contains_all"
          # Checks if array contains all specified elements
          # expected_value should be an array
          return false unless actual_value.is_a?(Array)
          return false unless expected_value.is_a?(Array)
          return true if expected_value.empty?

          # OPTIMIZE: Use Set for O(1) lookups instead of O(n) include?
          # For small arrays, Set overhead is minimal; for large arrays, huge win
          actual_set = actual_value.to_set
          expected_value.all? { |item| actual_set.include?(item) }

        when "contains_any"
          # Checks if array contains any of the specified elements
          # expected_value should be an array
          return false unless actual_value.is_a?(Array)
          return false unless expected_value.is_a?(Array)
          return false if expected_value.empty?

          # OPTIMIZE: Use Set for O(1) lookups instead of O(n) include?
          # Early exit on first match for better performance
          actual_set = actual_value.to_set
          expected_value.any? { |item| actual_set.include?(item) }

        when "intersects"
          # Checks if two arrays have any common elements
          # expected_value should be an array
          return false unless actual_value.is_a?(Array)
          return false unless expected_value.is_a?(Array)
          return false if actual_value.empty? || expected_value.empty?

          # OPTIMIZE: Use Set intersection for O(n) instead of array & which creates intermediate array
          # Check smaller array against larger set for better performance
          if actual_value.size <= expected_value.size
            expected_set = expected_value.to_set
            actual_value.any? { |item| expected_set.include?(item) }
          else
            actual_set = actual_value.to_set
            expected_value.any? { |item| actual_set.include?(item) }
          end

        when "subset_of"
          # Checks if array is a subset of another array
          # All elements in actual_value must be in expected_value
          return false unless actual_value.is_a?(Array)
          return false unless expected_value.is_a?(Array)
          return true if actual_value.empty?

          # OPTIMIZE: Use Set for O(1) lookups instead of O(n) include?
          expected_set = expected_value.to_set
          actual_value.all? { |item| expected_set.include?(item) }

        # GEOSPATIAL OPERATORS
        when "within_radius"
          # Checks if point is within radius of center point
          # actual_value: {lat: y, lon: x} or [lat, lon]
          # expected_value: {center: {lat: y, lon: x}, radius: distance_in_km}
          point = parse_coordinates(actual_value)
          return false unless point

          params = parse_radius_params(expected_value)
          return false unless params

          # Cache geospatial distance calculations
          distance = get_cached_distance(point, params[:center])
          distance <= params[:radius]

        when "in_polygon"
          # Checks if point is inside a polygon using ray casting algorithm
          # actual_value: {lat: y, lon: x} or [lat, lon]
          # expected_value: array of vertices [{lat: y, lon: x}, ...] or [[lat, lon], ...]
          point = parse_coordinates(actual_value)
          return false unless point

          polygon = parse_polygon(expected_value)
          return false unless polygon
          return false if polygon.size < 3 # Need at least 3 vertices

          point_in_polygon?(point, polygon)

        when "fetch_from_api"
          # Fetches data from external API and enriches context
          # expected_value: { endpoint: :endpoint_name, params: {...}, mapping: {...} }
          return false unless expected_value.is_a?(Hash)
          return false unless expected_value[:endpoint] || expected_value["endpoint"]

          begin
            endpoint_name = (expected_value[:endpoint] || expected_value["endpoint"]).to_sym
            params = expand_template_params(expected_value[:params] || expected_value["params"] || {}, context_hash)
            mapping = expected_value[:mapping] || expected_value["mapping"] || {}

            # Get data enrichment client
            client = DecisionAgent.data_enrichment_client

            # Fetch data from API
            response_data = client.fetch(endpoint_name, params: params, use_cache: true)

            # Apply mapping if provided and merge into context_hash
            if mapping.any?
              mapped_data = apply_mapping(response_data, mapping)
              # Merge mapped data into context_hash for subsequent conditions
              mapped_data.each do |key, value|
                context_hash[key] = value
              end
              # Return true if fetch succeeded and mapping applied
              mapped_data.any?
            else
              # Return true if fetch succeeded
              !response_data.nil?
            end
          rescue StandardError => e
            # Log error but return false (fail-safe)
            warn "Data enrichment error: #{e.message}" if ENV["DEBUG"]
            false
          end

        else
          # Unknown operator - returns false (fail-safe)
          # Note: Validation should catch this earlier
          false
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      # Retrieves nested values from a hash using dot notation
      #
      # Examples:
      #   get_nested_value({user: {role: "admin"}}, "user.role") # => "admin"
      #   get_nested_value({user: {role: "admin"}}, "user.missing") # => nil
      #   get_nested_value({user: nil}, "user.role") # => nil
      #
      # Supports both string and symbol keys in the hash
      def self.get_nested_value(hash, key_path)
        keys = get_cached_path(key_path)
        keys.reduce(hash) do |memo, key|
          return nil unless memo.is_a?(Hash)

          # OPTIMIZE: try symbol first (most common), then string
          # Check key existence first to avoid double lookup
          key_sym = key.to_sym
          if memo.key?(key_sym)
            memo[key_sym]
          elsif memo.key?(key)
            memo[key]
          end
        end
      end

      # Checks if two values can be compared with <, >, <=, >=
      # Allows comparison between numeric types (Float, Integer, etc.) or same string types
      def self.comparable?(val1, val2)
        # Both are numeric - allow comparison between different numeric types
        # (e.g., Integer and Float are comparable in Ruby)
        return true if val1.is_a?(Numeric) && val2.is_a?(Numeric)

        # Both are strings - require exact same type
        return val1.instance_of?(val2.class) if val1.is_a?(String) && val2.is_a?(String)

        false
      end

      # Helper methods for new operators

      # Expand template parameters (e.g., "{{customer.ssn}}") from context
      def self.expand_template_params(params, context_hash)
        return {} unless params.is_a?(Hash)

        params.transform_values do |value|
          expand_template_value(value, context_hash)
        end
      end

      # Expand a single template value
      def self.expand_template_value(value, context_hash)
        return value unless value.is_a?(String)
        return value unless value.match?(/\{\{.*\}\}/)

        # Extract path from {{path}} syntax
        value.gsub(/\{\{([^}]+)\}\}/) do |_match|
          path = Regexp.last_match(1).strip
          get_nested_value(context_hash, path) || value
        end
      end

      # Apply mapping to API response data
      # Mapping format: { source_key: "target_key" }
      # Example: { score: "credit_score" } means map response[:score] to context["credit_score"]
      def self.apply_mapping(response_data, mapping)
        return {} unless response_data.is_a?(Hash)
        return {} unless mapping.is_a?(Hash)

        mapping.each_with_object({}) do |(source_key, target_key), result|
          source_value = get_nested_value(response_data, source_key.to_s)
          result[target_key.to_s] = source_value unless source_value.nil?
        end
      end

      # String operator validation
      def self.string_operator?(actual_value, expected_value)
        actual_value.is_a?(String) && expected_value.is_a?(String)
      end

      # Parse range for 'between' operator
      # Accepts [min, max] or {min: x, max: y}
      def self.parse_range(value)
        # Generate cache key from normalized value
        cache_key = normalize_param_cache_key(value, "range")

        # Fast path: check cache without lock
        cached = @param_cache[cache_key]
        return cached if cached

        # Slow path: parse and cache
        @param_cache_mutex.synchronize do
          @param_cache[cache_key] ||= parse_range_impl(value)
        end
      end

      def self.parse_range_impl(value)
        if value.is_a?(Array) && value.size == 2
          { min: value[0], max: value[1] }
        elsif value.is_a?(Hash)
          # Normalize keys to symbols for consistency
          min = value["min"] || value[:min]
          max = value["max"] || value[:max]
          return nil unless min && max

          { min: min, max: max }
        end
      end

      # Parse modulo parameters
      # Accepts [divisor, remainder] or {divisor: x, remainder: y}
      def self.parse_modulo_params(value)
        # Generate cache key from normalized value
        cache_key = normalize_param_cache_key(value, "modulo")

        # Fast path: check cache without lock
        cached = @param_cache[cache_key]
        return cached if cached

        # Slow path: parse and cache
        @param_cache_mutex.synchronize do
          @param_cache[cache_key] ||= parse_modulo_params_impl(value)
        end
      end

      def self.parse_modulo_params_impl(value)
        if value.is_a?(Array) && value.size == 2
          { divisor: value[0], remainder: value[1] }
        elsif value.is_a?(Hash)
          # Normalize keys to symbols for consistency
          divisor = value["divisor"] || value[:divisor]
          remainder = value["remainder"] || value[:remainder]
          return nil unless divisor && !remainder.nil?

          { divisor: divisor, remainder: remainder }
        end
      end

      # Parse power parameters
      # Accepts [exponent, result] or {exponent: x, result: y}
      def self.parse_power_params(value)
        if value.is_a?(Array) && value.size == 2
          { exponent: value[0], result: value[1] }
        elsif value.is_a?(Hash)
          exponent = value["exponent"] || value[:exponent]
          result = value["result"] || value[:result]
          return nil unless exponent && !result.nil?

          { exponent: exponent, result: result }
        end
      end

      # Parse date from string, Time, Date, or DateTime (with caching)
      def self.parse_date(value)
        case value
        when Time, Date, DateTime
          value
        when String
          get_cached_date(value)
        end
      rescue ArgumentError
        nil
      end

      # Compare two dates with given operator
      # Optimized: Early return if values are already Time/Date objects
      def self.compare_dates(actual_value, expected_value, operator)
        return false unless actual_value && expected_value

        # Fast path: Both are already Time/Date objects (no parsing needed)
        actual_is_date = actual_value.is_a?(Time) || actual_value.is_a?(Date) || actual_value.is_a?(DateTime)
        expected_is_date = expected_value.is_a?(Time) || expected_value.is_a?(Date) || expected_value.is_a?(DateTime)
        return actual_value.send(operator, expected_value) if actual_is_date && expected_is_date

        # Slow path: Parse dates (with caching)
        actual_date = parse_date(actual_value)
        expected_date = parse_date(expected_value)

        return false unless actual_date && expected_date

        actual_date.send(operator, expected_date)
      end

      # Normalize day of week to 0-6 (Sunday=0)
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

      # Parse coordinates from hash or array
      # Accepts {lat: y, lon: x}, {latitude: y, longitude: x}, or [lat, lon]
      def self.parse_coordinates(value)
        case value
        when Hash
          lat = value["lat"] || value[:lat] || value["latitude"] || value[:latitude]
          lon = value["lon"] || value[:lon] || value["lng"] || value[:lng] ||
                value["longitude"] || value[:longitude]
          return nil unless lat && lon

          { lat: lat.to_f, lon: lon.to_f }
        when Array
          return nil unless value.size == 2

          { lat: value[0].to_f, lon: value[1].to_f }
        end
      end

      # Parse radius parameters
      # expected_value: {center: {lat: y, lon: x}, radius: distance_in_km}
      def self.parse_radius_params(value)
        return nil unless value.is_a?(Hash)

        center_data = value["center"] || value[:center]
        radius = value["radius"] || value[:radius]

        return nil unless center_data && radius

        center = parse_coordinates(center_data)
        return nil unless center

        { center: center, radius: radius.to_f }
      end

      # Parse polygon vertices
      # Accepts array of coordinate hashes or arrays
      def self.parse_polygon(value)
        return nil unless value.is_a?(Array)

        value.map { |vertex| parse_coordinates(vertex) }.compact
      end

      # Calculate distance between two points using Haversine formula
      # Returns distance in kilometers
      def self.haversine_distance(point1, point2)
        earth_radius_km = 6371.0

        lat1_rad = (point1[:lat] * Math::PI) / 180
        lat2_rad = (point2[:lat] * Math::PI) / 180
        delta_lat = ((point2[:lat] - point1[:lat]) * Math::PI) / 180
        delta_lon = ((point2[:lon] - point1[:lon]) * Math::PI) / 180

        a = (Math.sin(delta_lat / 2)**2) +
            (Math.cos(lat1_rad) * Math.cos(lat2_rad) *
            (Math.sin(delta_lon / 2)**2))

        c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

        earth_radius_km * c
      end

      # Get cached distance between two points (with precision rounding for cache key)
      def self.get_cached_distance(point1, point2)
        # Round coordinates to 4 decimal places (~11m precision) for cache key
        # This balances cache hit rate with precision
        key = [
          point1[:lat].round(4),
          point1[:lon].round(4),
          point2[:lat].round(4),
          point2[:lon].round(4)
        ].join(",")

        # Fast path: check cache without lock
        cached = @geospatial_cache[key]
        return cached if cached

        # Slow path: calculate and cache
        @geospatial_cache_mutex.synchronize do
          @geospatial_cache[key] ||= haversine_distance(point1, point2)
        end
      end

      # Check if point is inside polygon using ray casting algorithm
      def self.point_in_polygon?(point, polygon)
        x = point[:lon]
        y = point[:lat]
        inside = false

        j = polygon.size - 1
        polygon.size.times do |i|
          xi = polygon[i][:lon]
          yi = polygon[i][:lat]
          xj = polygon[j][:lon]
          yj = polygon[j][:lat]

          intersect = ((yi > y) != (yj > y)) &&
                      (x < ((((xj - xi) * (y - yi)) / (yj - yi)) + xi))
          inside = !inside if intersect

          j = i
        end

        inside
      end

      # Helper methods for new operators

      # Compare aggregation result with expected value (supports hash with comparison operators)
      # rubocop:disable Metrics/PerceivedComplexity
      def self.compare_aggregation_result(actual, expected)
        if expected.is_a?(Hash)
          result = true
          result &&= (actual >= expected[:min]) if expected[:min]
          result &&= (actual <= expected[:max]) if expected[:max]
          result &&= (actual > expected[:gt]) if expected[:gt]
          result &&= (actual < expected[:lt]) if expected[:lt]
          result &&= (actual >= expected[:gte]) if expected[:gte]
          result &&= (actual <= expected[:lte]) if expected[:lte]
          result &&= (actual == expected[:eq]) if expected[:eq]
          result
        else
          actual == expected
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity

      # Parse percentile parameters
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

      # Compare percentile result
      def self.compare_percentile_result(actual, params)
        result = true
        result &&= (actual >= params[:threshold]) if params[:threshold]
        result &&= (actual > params[:gt]) if params[:gt]
        result &&= (actual < params[:lt]) if params[:lt]
        result &&= (actual >= params[:gte]) if params[:gte]
        result &&= (actual <= params[:lte]) if params[:lte]
        result &&= (actual == params[:eq]) if params[:eq]
        result
      end

      # Parse duration parameters
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

      # Parse date arithmetic parameters
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

      # Compare numeric result (for time component extraction)
      # rubocop:disable Metrics/PerceivedComplexity
      def self.compare_numeric_result(actual, expected)
        if expected.is_a?(Hash)
          result = true
          result &&= (actual >= expected[:min]) if expected[:min]
          result &&= (actual <= expected[:max]) if expected[:max]
          result &&= (actual > expected[:gt]) if expected[:gt]
          result &&= (actual < expected[:lt]) if expected[:lt]
          result &&= (actual >= expected[:gte]) if expected[:gte]
          result &&= (actual <= expected[:lte]) if expected[:lte]
          result &&= (actual == expected[:eq]) if expected[:eq]
          result
        else
          actual == expected
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity

      # Compare rate result
      def self.compare_rate_result(actual, expected)
        compare_aggregation_result(actual, expected)
      end

      # Parse moving window parameters
      def self.parse_moving_window_params(value)
        return nil unless value.is_a?(Hash)

        window = value["window"] || value[:window]
        return nil unless window.is_a?(Numeric) && window.positive?

        {
          window: window.to_i,
          threshold: value["threshold"] || value[:threshold],
          gt: value["gt"] || value[:gt],
          lt: value["lt"] || value[:lt],
          gte: value["gte"] || value[:gte],
          lte: value["lte"] || value[:lte],
          eq: value["eq"] || value[:eq]
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
        result &&= (actual == params[:eq]) if params[:eq]
        result
      end

      # Parse compound interest parameters
      def self.parse_compound_interest_params(value)
        return nil unless value.is_a?(Hash)

        rate = value["rate"] || value[:rate]
        periods = value["periods"] || value[:periods]
        return nil unless rate && periods

        {
          rate: rate.to_f,
          periods: periods.to_i,
          result: value["result"] || value[:result],
          threshold: value["threshold"] || value[:threshold],
          gt: value["gt"] || value[:gt],
          lt: value["lt"] || value[:lt]
        }
      end

      # Parse present value parameters
      def self.parse_present_value_params(value)
        return nil unless value.is_a?(Hash)

        rate = value["rate"] || value[:rate]
        periods = value["periods"] || value[:periods]
        return nil unless rate && periods

        {
          rate: rate.to_f,
          periods: periods.to_i,
          result: value["result"] || value[:result],
          threshold: value["threshold"] || value[:threshold]
        }
      end

      # Parse future value parameters
      def self.parse_future_value_params(value)
        parse_present_value_params(value)
      end

      # Parse payment parameters
      def self.parse_payment_params(value)
        parse_compound_interest_params(value)
      end

      # Compare financial result
      def self.compare_financial_result(actual, params)
        result = true
        result &&= (actual >= params[:threshold]) if params[:threshold]
        result &&= (actual > params[:gt]) if params[:gt]
        result &&= (actual < params[:lt]) if params[:lt]
        result
      end

      # Parse join parameters
      def self.parse_join_params(value)
        return nil unless value.is_a?(Hash)

        separator = value["separator"] || value[:separator] || ","
        {
          separator: separator.to_s,
          result: value["result"] || value[:result],
          contains: value["contains"] || value[:contains]
        }
      end

      # Compare length result
      def self.compare_length_result(actual, expected)
        compare_aggregation_result(actual, expected)
      end

      # Cache management methods

      # Get or compile regex with caching
      def self.get_cached_regex(pattern)
        return pattern if pattern.is_a?(Regexp)

        # Fast path: check cache without lock
        cached = @regex_cache[pattern]
        return cached if cached

        # Slow path: compile and cache
        @regex_cache_mutex.synchronize do
          @regex_cache[pattern] ||= Regexp.new(pattern.to_s)
        end
      end

      # Get cached split path
      def self.get_cached_path(key_path)
        # Fast path: check cache without lock
        cached = @path_cache[key_path]
        return cached if cached

        # Slow path: split and cache
        @path_cache_mutex.synchronize do
          @path_cache[key_path] ||= key_path.to_s.split(".").freeze
        end
      end

      # Get cached parsed date with fast-path for common formats
      def self.get_cached_date(date_string)
        # Fast path: check cache without lock
        cached = @date_cache[date_string]
        return cached if cached

        # Slow path: parse and cache
        @date_cache_mutex.synchronize do
          @date_cache[date_string] ||= parse_date_fast(date_string)
        end
      end

      # Fast-path date parsing for common formats (ISO8601, etc.)
      # Falls back to Time.parse for other formats
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

      # Clear all caches (useful for testing or memory management)
      def self.clear_caches!
        @regex_cache_mutex.synchronize { @regex_cache.clear }
        @path_cache_mutex.synchronize { @path_cache.clear }
        @date_cache_mutex.synchronize { @date_cache.clear }
        @geospatial_cache_mutex.synchronize { @geospatial_cache.clear }
        @param_cache_mutex.synchronize { @param_cache.clear }
      end

      # Get cache statistics
      def self.cache_stats
        {
          regex_cache_size: @regex_cache.size,
          path_cache_size: @path_cache.size,
          date_cache_size: @date_cache.size,
          geospatial_cache_size: @geospatial_cache.size,
          param_cache_size: @param_cache.size
        }
      end

      # Normalize parameter value for cache key generation
      # Converts hash keys to symbols for consistency
      def self.normalize_param_cache_key(value, prefix)
        case value
        when Array
          "#{prefix}:#{value.inspect}"
        when Hash
          # Normalize keys to symbols and sort for consistent cache keys
          normalized = value.each_with_object({}) do |(k, v), h|
            key = k.is_a?(String) ? k.to_sym : k
            h[key] = v
          end
          sorted_keys = normalized.keys.sort
          "#{prefix}:#{sorted_keys.map { |k| "#{k}:#{normalized[k]}" }.join(',')}"
        else
          "#{prefix}:#{value.inspect}"
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
