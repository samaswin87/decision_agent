module DecisionAgent
  module Dsl
    module Operators
      # Handles statistical aggregation operators: min, max, sum, average, median, stddev, variance, percentile, count
      module StatisticalAggregations
        def self.handle(op, actual_value, expected_value, param_cache: nil, param_cache_mutex: nil)
          case op
          when "min"
            # Checks if min(field_value) equals expected_value
            return false unless actual_value.is_a?(Array)
            return false if actual_value.empty?
            return false unless expected_value.is_a?(Numeric)

            actual_value.min == expected_value

          when "max"
            # Checks if max(field_value) equals expected_value
            return false unless actual_value.is_a?(Array)
            return false if actual_value.empty?
            return false unless expected_value.is_a?(Numeric)

            actual_value.max == expected_value

          when "sum"
            # Checks if sum of numeric array equals expected_value
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

            Base.compare_aggregation_result(sum_value, expected_value)

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
            Base.compare_aggregation_result(avg_value, expected_value)

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
            Base.compare_aggregation_result(median_value, expected_value)

          when "stddev", "standard_deviation"
            # Checks if standard deviation of numeric array equals expected_value
            return false unless actual_value.is_a?(Array)
            return false if actual_value.size < 2

            numeric_array = actual_value.select { |v| v.is_a?(Numeric) }
            return false if numeric_array.size < 2

            mean = numeric_array.sum.to_f / numeric_array.size
            variance = numeric_array.sum { |v| (v - mean)**2 } / numeric_array.size
            stddev_value = Math.sqrt(variance)
            Base.compare_aggregation_result(stddev_value, expected_value)

          when "variance"
            # Checks if variance of numeric array equals expected_value
            return false unless actual_value.is_a?(Array)
            return false if actual_value.size < 2

            numeric_array = actual_value.select { |v| v.is_a?(Numeric) }
            return false if numeric_array.size < 2

            mean = numeric_array.sum.to_f / numeric_array.size
            variance_value = numeric_array.sum { |v| (v - mean)**2 } / numeric_array.size
            Base.compare_aggregation_result(variance_value, expected_value)

          when "percentile"
            # Checks if Nth percentile of numeric array meets threshold
            return false unless actual_value.is_a?(Array)
            return false if actual_value.empty?

            numeric_array = actual_value.select { |v| v.is_a?(Numeric) }.sort
            return false if numeric_array.empty?

            params = parse_percentile_params(expected_value, param_cache: param_cache, param_cache_mutex: param_cache_mutex)
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
            return false unless actual_value.is_a?(Array)

            count_value = actual_value.size
            Base.compare_aggregation_result(count_value, expected_value)

          else
            nil # Not handled by this module
          end
        end

        # Parse percentile parameters
        def self.parse_percentile_params(value, param_cache: nil, param_cache_mutex: nil)
          return nil unless value.is_a?(Hash)

          # Normalize to hash (already a hash, but normalize keys)
          normalized = Base.normalize_params_to_hash(value, [])

          cache = param_cache
          mutex = param_cache_mutex
          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@param_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@param_cache_mutex)
          end

          cache_key = Base.normalize_param_cache_key(normalized, "percentile")
          cached = cache[cache_key]
          return cached if cached

          mutex.synchronize do
            cache[cache_key] ||= parse_percentile_params_impl(normalized)
          end
        end

        def self.parse_percentile_params_impl(value)
          percentile = value[:percentile] || value["percentile"]
          return nil unless percentile.is_a?(Numeric) && percentile >= 0 && percentile <= 100

          {
            percentile: percentile.to_f,
            threshold: value[:threshold] || value["threshold"],
            gt: value[:gt] || value["gt"],
            lt: value[:lt] || value["lt"],
            gte: value[:gte] || value["gte"],
            lte: value[:lte] || value["lte"],
            eq: value[:eq] || value["eq"]
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
      end
    end
  end
end
