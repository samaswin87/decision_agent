module DecisionAgent
  module Dsl
    # Evaluates conditions in the rule DSL against a context
    #
    # Supports:
    # - Field conditions with various operators
    # - Nested field access via dot notation (e.g., "user.profile.role")
    # - Logical operators (all/any)
    class ConditionEvaluator
      def self.evaluate(condition, context)
        return false unless condition.is_a?(Hash)

        if condition.key?("all")
          evaluate_all(condition["all"], context)
        elsif condition.key?("any")
          evaluate_any(condition["any"], context)
        elsif condition.key?("field")
          evaluate_field_condition(condition, context)
        else
          false
        end
      end

      # Evaluates 'all' condition - returns true only if ALL sub-conditions are true
      # Empty array returns true (vacuous truth)
      def self.evaluate_all(conditions, context)
        return true if conditions.is_a?(Array) && conditions.empty?
        return false unless conditions.is_a?(Array)

        conditions.all? { |cond| evaluate(cond, context) }
      end

      # Evaluates 'any' condition - returns true if AT LEAST ONE sub-condition is true
      # Empty array returns false (no options to match)
      def self.evaluate_any(conditions, context)
        return false unless conditions.is_a?(Array)

        conditions.any? { |cond| evaluate(cond, context) }
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def self.evaluate_field_condition(condition, context)
        field = condition["field"]
        op = condition["op"]
        expected_value = condition["value"]

        actual_value = get_nested_value(context.to_h, field)

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
            regex = expected_value.is_a?(Regexp) ? expected_value : Regexp.new(expected_value.to_s)
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

        # COLLECTION OPERATORS
        when "contains_all"
          # Checks if array contains all specified elements
          # expected_value should be an array
          return false unless actual_value.is_a?(Array)
          return false unless expected_value.is_a?(Array)

          expected_value.all? { |item| actual_value.include?(item) }

        when "contains_any"
          # Checks if array contains any of the specified elements
          # expected_value should be an array
          return false unless actual_value.is_a?(Array)
          return false unless expected_value.is_a?(Array)

          expected_value.any? { |item| actual_value.include?(item) }

        when "intersects"
          # Checks if two arrays have any common elements
          # expected_value should be an array
          return false unless actual_value.is_a?(Array)
          return false unless expected_value.is_a?(Array)

          !(actual_value & expected_value).empty?

        when "subset_of"
          # Checks if array is a subset of another array
          # All elements in actual_value must be in expected_value
          return false unless actual_value.is_a?(Array)
          return false unless expected_value.is_a?(Array)

          actual_value.all? { |item| expected_value.include?(item) }

        # GEOSPATIAL OPERATORS
        when "within_radius"
          # Checks if point is within radius of center point
          # actual_value: {lat: y, lon: x} or [lat, lon]
          # expected_value: {center: {lat: y, lon: x}, radius: distance_in_km}
          point = parse_coordinates(actual_value)
          return false unless point

          params = parse_radius_params(expected_value)
          return false unless params

          distance = haversine_distance(point, params[:center])
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
        keys = key_path.to_s.split(".")
        keys.reduce(hash) do |memo, key|
          return nil unless memo.is_a?(Hash)

          memo[key] || memo[key.to_sym]
        end
      end

      # Checks if two values can be compared with <, >, <=, >=
      # Only allows comparison between values of the same type
      def self.comparable?(val1, val2)
        (val1.is_a?(Numeric) || val1.is_a?(String)) &&
          (val2.is_a?(Numeric) || val2.is_a?(String)) &&
          val1.instance_of?(val2.class)
      end

      # Helper methods for new operators

      # String operator validation
      def self.string_operator?(actual_value, expected_value)
        actual_value.is_a?(String) && expected_value.is_a?(String)
      end

      # Parse range for 'between' operator
      # Accepts [min, max] or {min: x, max: y}
      def self.parse_range(value)
        if value.is_a?(Array) && value.size == 2
          { min: value[0], max: value[1] }
        elsif value.is_a?(Hash)
          min = value["min"] || value[:min]
          max = value["max"] || value[:max]
          return nil unless min && max

          { min: min, max: max }
        end
      end

      # Parse modulo parameters
      # Accepts [divisor, remainder] or {divisor: x, remainder: y}
      def self.parse_modulo_params(value)
        if value.is_a?(Array) && value.size == 2
          { divisor: value[0], remainder: value[1] }
        elsif value.is_a?(Hash)
          divisor = value["divisor"] || value[:divisor]
          remainder = value["remainder"] || value[:remainder]
          return nil unless divisor && !remainder.nil?

          { divisor: divisor, remainder: remainder }
        end
      end

      # Parse date from string, Time, Date, or DateTime
      def self.parse_date(value)
        case value
        when Time, Date, DateTime
          value
        when String
          Time.parse(value)
        end
      rescue ArgumentError
        nil
      end

      # Compare two dates with given operator
      def self.compare_dates(actual_value, expected_value, operator)
        return false unless actual_value && expected_value

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
    end
  end
end
