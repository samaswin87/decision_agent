module DecisionAgent
  module Dsl
    module Helpers
      # Comparison helpers for ConditionEvaluator
      module ComparisonHelpers
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

        def self.compare_moving_window_result(actual, params)
          result = true
          result &&= (actual >= params[:threshold]) if params[:threshold]
          result &&= (actual > params[:gt]) if params[:gt]
          result &&= (actual < params[:lt]) if params[:lt]
          result &&= (actual >= params[:gte]) if params[:gte]
          result &&= (actual <= params[:lte]) if params[:lte]
          result
        end

        def self.compare_financial_result(actual, params)
          result = true
          result &&= (actual >= params[:threshold]) if params[:threshold]
          result &&= (actual > params[:gt]) if params[:gt]
          result &&= (actual < params[:lt]) if params[:lt]
          result
        end

        def self.compare_numeric_with_hash(actual, expected)
          comparisons = [
            [:min, ->(val, threshold) { val >= threshold }],
            [:max, ->(val, threshold) { val <= threshold }],
            [:gt, ->(val, threshold) { val > threshold }],
            [:lt, ->(val, threshold) { val < threshold }],
            [:gte, ->(val, threshold) { val >= threshold }],
            [:lte, ->(val, threshold) { val <= threshold }],
            [:eq, ->(val, threshold) { val == threshold }]
          ]

          comparisons.all? do |key, comparison|
            threshold = expected[key] || expected[key.to_s]
            threshold.nil? || comparison.call(actual, threshold)
          end
        end
      end
    end
  end
end
