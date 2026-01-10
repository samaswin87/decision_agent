require "set"

# Operator mixins
require_relative "operators/base"
require_relative "operators/basic_comparison_operators"
require_relative "operators/string_operators"
require_relative "operators/numeric_operators"
require_relative "operators/mathematical_operators"
require_relative "operators/statistical_aggregations"
require_relative "operators/date_time_operators"
require_relative "operators/duration_operators"
require_relative "operators/date_arithmetic_operators"
require_relative "operators/time_component_operators"
require_relative "operators/rate_operators"
require_relative "operators/moving_window_operators"
require_relative "operators/financial_operators"
require_relative "operators/string_aggregations"
require_relative "operators/collection_operators"
require_relative "operators/geospatial_operators"

# Helper modules
require_relative "helpers/cache_helpers"
require_relative "helpers/date_helpers"
require_relative "helpers/geospatial_helpers"
require_relative "helpers/template_helpers"
require_relative "helpers/parameter_parsing_helpers"
require_relative "helpers/comparison_helpers"
require_relative "helpers/operator_evaluation_helpers"
require_relative "helpers/utility_helpers"

module DecisionAgent
  module Dsl
    # Evaluates conditions in the rule DSL against a context
    #
    # Supports:
    # - Field conditions with various operators
    # - Nested field access via dot notation (e.g., "user.profile.role")
    # - Logical operators (all/any)
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

      def self.evaluate(condition, context, enriched_context_hash: nil, trace_collector: nil)
        return false unless condition.is_a?(Hash)

        # Use enriched context hash if provided, otherwise create mutable copy
        # This ensures all conditions in the same evaluation share the same enriched hash
        enriched = enriched_context_hash
        enriched ||= context.to_h.dup

        if condition.key?("all")
          evaluate_all(condition["all"], context, enriched_context_hash: enriched, trace_collector: trace_collector)
        elsif condition.key?("any")
          evaluate_any(condition["any"], context, enriched_context_hash: enriched, trace_collector: trace_collector)
        elsif condition.key?("field")
          evaluate_field_condition(condition, context, enriched_context_hash: enriched, trace_collector: trace_collector)
        else
          false
        end
      end

      # Evaluates 'all' condition - returns true only if ALL sub-conditions are true
      # Empty array returns true (vacuous truth)
      def self.evaluate_all(conditions, context, enriched_context_hash: nil, trace_collector: nil)
        return true if conditions.is_a?(Array) && conditions.empty?
        return false unless conditions.is_a?(Array)

        # Use enriched context hash if provided, otherwise create mutable copy
        # All conditions share the same enriched hash so data enrichment persists
        enriched = enriched_context_hash
        enriched ||= context.to_h.dup

        conditions.all? { |cond| evaluate(cond, context, enriched_context_hash: enriched, trace_collector: trace_collector) }
      end

      # Evaluates 'any' condition - returns true if AT LEAST ONE sub-condition is true
      # Empty array returns false (no options to match)
      def self.evaluate_any(conditions, context, enriched_context_hash: nil, trace_collector: nil)
        return false unless conditions.is_a?(Array)

        # Use enriched context hash if provided, otherwise create mutable copy
        # All conditions share the same enriched hash so data enrichment persists
        enriched = enriched_context_hash
        enriched ||= context.to_h.dup

        conditions.any? { |cond| evaluate(cond, context, enriched_context_hash: enriched, trace_collector: trace_collector) }
      end

      def self.evaluate_field_condition(condition, context, enriched_context_hash: nil, trace_collector: nil)
        field = condition["field"]
        op = condition["op"]
        expected_value = condition["value"]

        # Special handling for "don't care" conditions (from DMN "-" entries)
        result = handle_dont_care_condition(field, op, expected_value, trace_collector)
        return result if result == true

        # Use enriched context hash if provided, otherwise create mutable copy
        # This ensures all conditions in the same evaluation share the same enriched hash
        context_hash = enriched_context_hash || context.to_h.dup
        actual_value = get_nested_value(context_hash, field)

        # Try operator mixins to handle the operator
        result = evaluate_operator(op, actual_value, expected_value, context_hash)

        # Add trace if collector is provided
        trace_collector&.add_trace(Explainability::ConditionTrace.new(
          field: field,
          operator: op,
          expected_value: expected_value,
          actual_value: actual_value,
          result: result
        ))

        result
      end

      # Evaluates operator using mixins (in order of most common to least common)
      # Returns the result from the first mixin that handles the operator, or false if unknown
      def self.evaluate_operator(op, actual_value, expected_value, context_hash)
        Helpers::OperatorEvaluationHelpers.evaluate_operator(
          op, actual_value, expected_value, context_hash,
          regex_cache: @regex_cache,
          regex_cache_mutex: @regex_cache_mutex,
          param_cache: @param_cache,
          param_cache_mutex: @param_cache_mutex,
          geospatial_cache: @geospatial_cache,
          geospatial_cache_mutex: @geospatial_cache_mutex
        )
      end
      private_class_method :evaluate_operator

      # Handles "don't care" conditions from DMN "-" entries
      # Returns true if this is a "don't care" condition, nil otherwise
      def self.handle_dont_care_condition(field, op, expected_value, trace_collector)
        return nil unless field == "__always_match__" && op == "eq" && expected_value == true

        trace_collector&.add_trace(Explainability::ConditionTrace.new(
          field: field,
          operator: op,
          expected_value: expected_value,
          actual_value: true,
          result: true
        ))
        true
      end
      private_class_method :handle_dont_care_condition

      # Retrieves nested values from a hash using dot notation
      #
      # Examples:
      #   get_nested_value({user: {role: "admin"}}, "user.role") # => "admin"
      #   get_nested_value({user: {role: "admin"}}, "user.missing") # => nil
      #   get_nested_value({user: nil}, "user.role") # => nil
      #
      # Supports both string and symbol keys in the hash
      def self.get_nested_value(hash, key_path)
        Helpers::UtilityHelpers.get_nested_value(
          hash, key_path,
          get_cached_path: method(:get_cached_path)
        )
      end

      # Checks if two values can be compared with <, >, <=, >=
      # Allows comparison between numeric types (Float, Integer, etc.) or same string types
      def self.comparable?(val1, val2)
        Helpers::UtilityHelpers.comparable?(val1, val2)
      end

      # Floating point comparison with epsilon threshold
      def self.epsilon_equal?(value1, value2, epsilon = 1e-10)
        Helpers::UtilityHelpers.epsilon_equal?(value1, value2, epsilon)
      end

      # Expand template parameters (e.g., "{{customer.ssn}}") from context
      def self.expand_template_params(params, context_hash)
        Helpers::TemplateHelpers.expand_template_params(
          params, context_hash,
          get_nested_value: method(:get_nested_value)
        )
      end

      # Expand a single template value
      def self.expand_template_value(value, context_hash)
        Helpers::TemplateHelpers.expand_template_value(
          value, context_hash,
          get_nested_value: method(:get_nested_value)
        )
      end

      # String operator validation
      def self.string_operator?(actual_value, expected_value)
        Helpers::UtilityHelpers.string_operator?(actual_value, expected_value)
      end

      # Parse range for 'between' operator
      # Accepts [min, max] or {min: x, max: y}
      # Normalizes arrays to hash for better performance with large params
      def self.parse_range(value)
        Helpers::ParameterParsingHelpers.parse_range(
          value,
          param_cache: @param_cache,
          param_cache_mutex: @param_cache_mutex
        )
      end

      def self.parse_range_impl(value)
        Helpers::ParameterParsingHelpers.parse_range_impl(value)
      end

      # Parse modulo parameters
      # Accepts [divisor, remainder] or {divisor: x, remainder: y}
      # Normalizes arrays to hash for better performance with large params
      def self.parse_modulo_params(value)
        Helpers::ParameterParsingHelpers.parse_modulo_params(
          value,
          param_cache: @param_cache,
          param_cache_mutex: @param_cache_mutex
        )
      end

      def self.parse_modulo_params_impl(value)
        Helpers::ParameterParsingHelpers.parse_modulo_params_impl(value)
      end

      # Parse power parameters
      # Accepts [exponent, result] or {exponent: x, result: y}
      # Normalizes arrays to hash for better performance with large params
      def self.parse_power_params(value)
        Helpers::ParameterParsingHelpers.parse_power_params(value)
      end

      # Parse atan2 parameters
      # Accepts [y, result] or {y: x, result: y}
      # Normalizes arrays to hash for better performance with large params
      def self.parse_atan2_params(value)
        Helpers::ParameterParsingHelpers.parse_atan2_params(value)
      end

      # Parse gcd/lcm parameters
      # Accepts [other, result] or {other: x, result: y}
      # Normalizes arrays to hash for better performance with large params
      def self.parse_gcd_lcm_params(value)
        Helpers::ParameterParsingHelpers.parse_gcd_lcm_params(value)
      end

      # Parse date from string, Time, Date, or DateTime (with caching)
      def self.parse_date(value)
        Helpers::DateHelpers.parse_date(
          value,
          get_cached_date: ->(date_string) { get_cached_date(date_string) }
        )
      end

      # Compare two dates with given operator
      # Optimized: Early return if values are already Time/Date objects
      def self.compare_dates(actual_value, expected_value, operator)
        Helpers::DateHelpers.compare_dates(
          actual_value, expected_value, operator,
          parse_date: method(:parse_date)
        )
      end

      # Normalize day of week to 0-6 (Sunday=0)
      def self.normalize_day_of_week(value)
        Helpers::DateHelpers.normalize_day_of_week(value)
      end

      # Parse coordinates from hash or array
      # Accepts {lat: y, lon: x}, {latitude: y, longitude: x}, or [lat, lon]
      def self.parse_coordinates(value)
        Helpers::GeospatialHelpers.parse_coordinates(value)
      end

      # Parse radius parameters
      # expected_value: {center: {lat: y, lon: x}, radius: distance_in_km}
      def self.parse_radius_params(value)
        Helpers::GeospatialHelpers.parse_radius_params(
          value,
          parse_coordinates: method(:parse_coordinates)
        )
      end

      # Parse polygon vertices
      # Accepts array of coordinate hashes or arrays
      def self.parse_polygon(value)
        Helpers::GeospatialHelpers.parse_polygon(
          value,
          parse_coordinates: method(:parse_coordinates)
        )
      end

      # Calculate distance between two points using Haversine formula
      # Returns distance in kilometers
      def self.haversine_distance(point1, point2)
        Helpers::GeospatialHelpers.haversine_distance(point1, point2)
      end

      # Get cached distance between two points (with precision rounding for cache key)
      def self.get_cached_distance(point1, point2)
        Helpers::CacheHelpers.get_cached_distance(
          point1, point2,
          geospatial_cache: @geospatial_cache,
          geospatial_cache_mutex: @geospatial_cache_mutex,
          haversine_distance: method(:haversine_distance)
        )
      end

      # Check if point is inside polygon using ray casting algorithm
      def self.point_in_polygon?(point, polygon)
        Helpers::GeospatialHelpers.point_in_polygon?(point, polygon)
      end

      # Helper methods for new operators

      # Compare aggregation result with expected value (supports hash with comparison operators)
      # Delegates to Base utilities for consistency
      def self.compare_aggregation_result(actual, expected)
        Operators::Base.compare_aggregation_result(actual, expected)
      end

      # Parse percentile parameters
      def self.parse_percentile_params(value)
        Helpers::ParameterParsingHelpers.parse_percentile_params(value)
      end

      # Compare percentile result
      def self.compare_percentile_result(actual, params)
        Helpers::ComparisonHelpers.compare_percentile_result(actual, params)
      end

      # Parse duration parameters
      def self.parse_duration_params(value)
        Helpers::ParameterParsingHelpers.parse_duration_params(value)
      end

      # Compare duration result
      def self.compare_duration_result(actual, params)
        Helpers::ComparisonHelpers.compare_duration_result(actual, params)
      end

      # Parse date arithmetic parameters
      def self.parse_date_arithmetic_params(value, unit = :days)
        Helpers::ParameterParsingHelpers.parse_date_arithmetic_params(value, unit)
      end

      # Compare date result
      def self.compare_date_result?(actual, target, params)
        Helpers::ComparisonHelpers.compare_date_result?(actual, target, params)
      end

      # Compare numeric result (for time component extraction)
      def self.compare_numeric_result(actual, expected)
        return actual == expected unless expected.is_a?(Hash)

        Helpers::ComparisonHelpers.compare_numeric_with_hash(actual, expected)
      end
      private_class_method :compare_numeric_result

      # Compare rate result
      def self.compare_rate_result(actual, expected)
        compare_aggregation_result(actual, expected)
      end

      # Parse moving window parameters
      def self.parse_moving_window_params(value)
        Helpers::ParameterParsingHelpers.parse_moving_window_params(value)
      end

      # Compare moving window result
      def self.compare_moving_window_result(actual, params)
        Helpers::ComparisonHelpers.compare_moving_window_result(actual, params)
      end

      # Parse compound interest parameters
      def self.parse_compound_interest_params(value)
        Helpers::ParameterParsingHelpers.parse_compound_interest_params(value)
      end

      # Parse present value parameters
      def self.parse_present_value_params(value)
        Helpers::ParameterParsingHelpers.parse_present_value_params(value)
      end

      # Parse future value parameters
      def self.parse_future_value_params(value)
        Helpers::ParameterParsingHelpers.parse_future_value_params(value)
      end

      # Parse payment parameters
      def self.parse_payment_params(value)
        Helpers::ParameterParsingHelpers.parse_payment_params(value)
      end

      # Compare financial result
      def self.compare_financial_result(actual, params)
        Helpers::ComparisonHelpers.compare_financial_result(actual, params)
      end

      # Parse join parameters
      def self.parse_join_params(value)
        Helpers::ParameterParsingHelpers.parse_join_params(value)
      end

      # Compare length result
      def self.compare_length_result(actual, expected)
        compare_aggregation_result(actual, expected)
      end

      # Cache management methods

      # Get or compile regex with caching
      def self.get_cached_regex(pattern)
        Helpers::CacheHelpers.get_cached_regex(
          pattern,
          regex_cache: @regex_cache,
          regex_cache_mutex: @regex_cache_mutex
        )
      end

      # Get cached split path
      def self.get_cached_path(key_path)
        Helpers::CacheHelpers.get_cached_path(
          key_path,
          path_cache: @path_cache,
          path_cache_mutex: @path_cache_mutex
        )
      end

      # Get cached parsed date with fast-path for common formats
      def self.get_cached_date(date_string)
        Helpers::CacheHelpers.get_cached_date(
          date_string,
          date_cache: @date_cache,
          date_cache_mutex: @date_cache_mutex,
          parse_date_fast: ->(str) { Helpers::DateHelpers.parse_date_fast(str) }
        )
      end

      # Fast-path date parsing for common formats (ISO8601, etc.)
      # Falls back to Time.parse for other formats
      def self.parse_date_fast(date_string)
        Helpers::DateHelpers.parse_date_fast(date_string)
      end

      # Clear all caches (useful for testing or memory management)
      def self.clear_caches!
        Helpers::CacheHelpers.clear_caches!(
          regex_cache: @regex_cache,
          path_cache: @path_cache,
          date_cache: @date_cache,
          geospatial_cache: @geospatial_cache,
          param_cache: @param_cache
        )
      end

      # Get cache statistics
      def self.cache_stats
        stats = Helpers::CacheHelpers.cache_stats(
          regex_cache: @regex_cache,
          path_cache: @path_cache,
          date_cache: @date_cache,
          geospatial_cache: @geospatial_cache,
          param_cache: @param_cache
        )
        {
          regex_cache_size: stats[:regex],
          path_cache_size: stats[:path],
          date_cache_size: stats[:date],
          geospatial_cache_size: stats[:geospatial],
          param_cache_size: stats[:param]
        }
      end

      # Normalize parameter value for cache key generation
      # Converts hash keys to symbols for consistency
      # Delegates to Base utilities for consistency
      def self.normalize_param_cache_key(value, prefix)
        Operators::Base.normalize_param_cache_key(value, prefix)
      end
    end
  end
end
