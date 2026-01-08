module DecisionAgent
  module Dsl
    module Helpers
      # Operator evaluation helpers for ConditionEvaluator
      module OperatorEvaluationHelpers
        # Evaluates operator using mixins (in order of most common to least common)
        # Returns the result from the first mixin that handles the operator, or false if unknown
        def self.evaluate_operator(op, actual_value, expected_value, context_hash, regex_cache:, regex_cache_mutex:, param_cache:,
                                   param_cache_mutex:, geospatial_cache:, geospatial_cache_mutex:)
          # Try basic operators first (most common)
          result = try_basic_operators(
            op, actual_value, expected_value,
            regex_cache: regex_cache,
            regex_cache_mutex: regex_cache_mutex,
            param_cache: param_cache,
            param_cache_mutex: param_cache_mutex
          )
          return result unless result.nil?

          # Try mathematical and statistical operators
          result = try_math_and_statistical_operators(
            op, actual_value, expected_value,
            param_cache: param_cache,
            param_cache_mutex: param_cache_mutex
          )
          return result unless result.nil?

          # Try date/time operators
          result = try_datetime_operators(
            op, actual_value, expected_value, context_hash,
            param_cache: param_cache,
            param_cache_mutex: param_cache_mutex
          )
          return result unless result.nil?

          # Try advanced operators (rate, moving window, financial)
          result = try_advanced_operators(
            op, actual_value, expected_value,
            param_cache: param_cache,
            param_cache_mutex: param_cache_mutex
          )
          return result unless result.nil?

          # Try collection and aggregation operators
          result = try_collection_and_aggregation_operators(
            op, actual_value, expected_value,
            param_cache: param_cache,
            param_cache_mutex: param_cache_mutex
          )
          return result unless result.nil?

          # Try special operators (geospatial, data enrichment)
          result = try_special_operators(
            op, actual_value, expected_value, context_hash,
            geospatial_cache: geospatial_cache,
            geospatial_cache_mutex: geospatial_cache_mutex
          )
          return result unless result.nil?

          # Unknown operator - returns false (fail-safe)
          # Note: Validation should catch this earlier
          false
        end

        def self.try_basic_operators(op, actual_value, expected_value, regex_cache:, regex_cache_mutex:, param_cache:, param_cache_mutex:)
          result = Operators::BasicComparisonOperators.handle(op, actual_value, expected_value)
          return result unless result.nil?

          result = Operators::StringOperators.handle(
            op, actual_value, expected_value,
            regex_cache: regex_cache,
            regex_cache_mutex: regex_cache_mutex
          )
          return result unless result.nil?

          Operators::NumericOperators.handle(
            op, actual_value, expected_value,
            param_cache: param_cache,
            param_cache_mutex: param_cache_mutex
          )
        end

        def self.try_math_and_statistical_operators(op, actual_value, expected_value, param_cache:, param_cache_mutex:)
          result = Operators::MathematicalOperators.handle(
            op, actual_value, expected_value,
            param_cache: param_cache,
            param_cache_mutex: param_cache_mutex
          )
          return result unless result.nil?

          Operators::StatisticalAggregations.handle(
            op, actual_value, expected_value,
            param_cache: param_cache,
            param_cache_mutex: param_cache_mutex
          )
        end

        def self.try_datetime_operators(op, actual_value, expected_value, context_hash, param_cache:, param_cache_mutex:)
          result = Operators::DateTimeOperators.handle(op, actual_value, expected_value)
          return result unless result.nil?

          result = Operators::DurationOperators.handle(
            op, actual_value, expected_value, context_hash,
            param_cache: param_cache,
            param_cache_mutex: param_cache_mutex
          )
          return result unless result.nil?

          result = Operators::DateArithmeticOperators.handle(
            op, actual_value, expected_value, context_hash,
            param_cache: param_cache,
            param_cache_mutex: param_cache_mutex
          )
          return result unless result.nil?

          Operators::TimeComponentOperators.handle(op, actual_value, expected_value)
        end

        def self.try_advanced_operators(op, actual_value, expected_value, param_cache:, param_cache_mutex:)
          result = Operators::RateOperators.handle(op, actual_value, expected_value)
          return result unless result.nil?

          result = Operators::MovingWindowOperators.handle(
            op, actual_value, expected_value,
            param_cache: param_cache,
            param_cache_mutex: param_cache_mutex
          )
          return result unless result.nil?

          Operators::FinancialOperators.handle(
            op, actual_value, expected_value,
            param_cache: param_cache,
            param_cache_mutex: param_cache_mutex
          )
        end

        def self.try_collection_and_aggregation_operators(op, actual_value, expected_value, param_cache:, param_cache_mutex:)
          result = Operators::StringAggregations.handle(
            op, actual_value, expected_value,
            param_cache: param_cache,
            param_cache_mutex: param_cache_mutex
          )
          return result unless result.nil?

          Operators::CollectionOperators.handle(op, actual_value, expected_value)
        end

        def self.try_special_operators(op, actual_value, expected_value, context_hash, geospatial_cache:, geospatial_cache_mutex:)
          result = Operators::GeospatialOperators.handle(
            op, actual_value, expected_value,
            geospatial_cache: geospatial_cache,
            geospatial_cache_mutex: geospatial_cache_mutex
          )
          return result unless result.nil?

          Operators::DataEnrichmentOperators.handle(
            op, actual_value, expected_value, context_hash
          )
        end
      end
    end
  end
end
