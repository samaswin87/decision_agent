module DecisionAgent
  module Dsl
    module Operators
      # Handles string operators: contains, starts_with, ends_with, matches
      module StringOperators
        def self.handle(op, actual_value, expected_value, regex_cache: nil, regex_cache_mutex: nil)
          case op
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
            if !actual_value.is_a?(String) || expected_value.nil?
              false
            else
              begin
                regex = get_cached_regex(expected_value, regex_cache: regex_cache, regex_cache_mutex: regex_cache_mutex)
                !regex.match(actual_value).nil?
              rescue RegexpError
                false
              end
            end
          end
          # Returns nil if not handled by this module
        end

        # String operator validation
        def self.string_operator?(actual_value, expected_value)
          actual_value.is_a?(String) && expected_value.is_a?(String)
        end

        # Get or compile regex with caching
        def self.get_cached_regex(pattern, regex_cache: nil, regex_cache_mutex: nil)
          return pattern if pattern.is_a?(Regexp)

          # Use provided caches or access ConditionEvaluator class variables
          cache = regex_cache
          mutex = regex_cache_mutex

          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@regex_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@regex_cache_mutex)
          end

          # Fast path: check cache without lock
          cached = cache[pattern]
          return cached if cached

          # Slow path: compile and cache
          mutex.synchronize do
            cache[pattern] ||= Regexp.new(pattern.to_s)
          end
        end
      end
    end
  end
end
