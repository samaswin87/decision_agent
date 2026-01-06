module DecisionAgent
  module Explainability
    # Container for all explainability data from a decision evaluation
    class ExplainabilityResult
      attr_reader :rule_traces, :evaluator_name

      def initialize(evaluator_name:, rule_traces: [])
        @evaluator_name = evaluator_name.to_s.freeze
        @rule_traces = Array(rule_traces).freeze
        freeze
      end

      def matched_rules
        @rule_traces.select(&:matched)
      end

      def evaluated_rules
        @rule_traces
      end

      def all_passed_conditions
        @rule_traces.flat_map(&:passed_conditions)
      end

      def all_failed_conditions
        @rule_traces.flat_map(&:failed_conditions)
      end

      def because(verbose: false)
        if verbose
          all_passed_conditions.map(&:description)
        else
          all_passed_conditions.map(&:description)
        end
      end

      def failed_conditions(verbose: false)
        if verbose
          all_failed_conditions.map(&:to_h)
        else
          all_failed_conditions.map(&:description)
        end
      end

      def to_h(verbose: false)
        {
          evaluator_name: @evaluator_name,
          rule_traces: @rule_traces.map(&:to_h), # Always include full rule traces for reconstruction
          because: because(verbose: verbose),
          failed_conditions: failed_conditions(verbose: verbose)
        }
      end
    end
  end
end

