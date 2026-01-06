module DecisionAgent
  module Explainability
    # Represents the trace of a rule evaluation including all conditions
    class RuleTrace
      attr_reader :rule_id, :matched, :condition_traces, :decision, :weight, :reason

      def initialize(rule_id:, matched:, condition_traces: [], decision: nil, weight: nil, reason: nil)
        @rule_id = rule_id.to_s.freeze
        @matched = matched
        @condition_traces = Array(condition_traces).freeze
        @decision = decision ? decision.to_s.freeze : nil
        @weight = weight
        @reason = reason ? reason.to_s.freeze : nil
        freeze
      end

      def passed_conditions
        @condition_traces.select(&:passed?)
      end

      def failed_conditions
        @condition_traces.select(&:failed?)
      end

      def to_h
        {
          rule_id: @rule_id,
          matched: @matched,
          decision: @decision,
          weight: @weight,
          reason: @reason,
          condition_traces: @condition_traces.map(&:to_h),
          passed_conditions: passed_conditions.map(&:description),
          failed_conditions: failed_conditions.map(&:description)
        }
      end
    end
  end
end

