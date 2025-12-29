require "set"

module DecisionAgent
  module Testing
    # Coverage report for test scenarios
    class CoverageReport
      attr_reader :total_rules, :covered_rules, :untested_rules, :coverage_percentage, :rule_coverage, :condition_coverage

      def initialize(total_rules:, covered_rules:, untested_rules:, coverage_percentage:, rule_coverage:, condition_coverage:)
        @total_rules = total_rules
        @covered_rules = covered_rules
        @untested_rules = untested_rules.freeze
        @coverage_percentage = coverage_percentage
        @rule_coverage = rule_coverage.freeze
        @condition_coverage = condition_coverage.freeze

        freeze
      end

      def to_h
        {
          total_rules: @total_rules,
          covered_rules: @covered_rules,
          untested_rules: @untested_rules,
          coverage_percentage: @coverage_percentage,
          rule_coverage: @rule_coverage,
          condition_coverage: @condition_coverage
        }
      end
    end

    # Analyzes test coverage of rules and conditions
    class TestCoverageAnalyzer
      def initialize
        @executed_rules = Set.new
        @executed_conditions = Set.new
        @rule_evaluation_count = {}
        @condition_evaluation_count = {}
      end

      # Analyze coverage from test results
      # @param results [Array<TestResult>] Test results from batch execution
      # @param agent [Agent] The agent used for testing (to get all available rules)
      # @return [CoverageReport] Coverage report
      def analyze(results, agent = nil)
        reset

        # Track which rules and conditions were executed
        results.each do |result|
          next unless result.success?

          result.evaluations.each do |evaluation|
            track_evaluation(evaluation)
          end
        end

        # Get all available rules from agent if provided
        all_rules = agent ? extract_rules_from_agent(agent) : []
        all_conditions = agent ? extract_conditions_from_agent(agent) : []

        generate_report(all_rules, all_conditions)
      end

      # Get coverage percentage
      # @return [Float] Coverage percentage (0.0 to 1.0)
      def coverage_percentage
        return 0.0 if @executed_rules.empty?

        total = @rule_evaluation_count.size
        return 0.0 if total.zero?

        @executed_rules.size.to_f / total
      end

      private

      def reset
        @executed_rules = Set.new
        @executed_conditions = Set.new
        @rule_evaluation_count = {}
        @condition_evaluation_count = {}
      end

      def track_evaluation(evaluation)
        # Extract rule identifier from evaluation
        rule_id = extract_rule_id(evaluation)
        condition_id = extract_condition_id(evaluation)

        if rule_id
          @executed_rules << rule_id
          @rule_evaluation_count[rule_id] = (@rule_evaluation_count[rule_id] || 0) + 1
        end

        return unless condition_id

        @executed_conditions << condition_id
        @condition_evaluation_count[condition_id] = (@condition_evaluation_count[condition_id] || 0) + 1
      end

      def extract_rule_id(evaluation)
        # Try to get rule_id from metadata
        return evaluation.metadata[:rule_id] if evaluation.respond_to?(:metadata) && evaluation.metadata.is_a?(Hash)

        # Fallback to evaluator_name as rule identifier
        return evaluation.evaluator_name if evaluation.respond_to?(:evaluator_name)

        nil
      end

      def extract_condition_id(evaluation)
        # Try to get condition_id from metadata
        return evaluation.metadata[:condition_id] if evaluation.respond_to?(:metadata) && evaluation.metadata.is_a?(Hash)

        nil
      end

      def extract_rules_from_agent(agent)
        rules = []

        agent.evaluators.each do |evaluator|
          # Try to extract rule information from evaluator
          if evaluator.respond_to?(:rules)
            rules.concat(Array(evaluator.rules))
          elsif evaluator.respond_to?(:rule_id)
            rules << evaluator.rule_id
          else
            # Use evaluator class name as rule identifier
            rules << evaluator.class.name
          end
        end

        rules.uniq
      end

      def extract_conditions_from_agent(agent)
        conditions = []

        agent.evaluators.each do |evaluator|
          # Try to extract condition information from evaluator
          if evaluator.respond_to?(:conditions)
            conditions.concat(Array(evaluator.conditions))
          elsif evaluator.respond_to?(:condition_id)
            conditions << evaluator.condition_id
          end
        end

        conditions.uniq
      end

      def generate_report(all_rules, all_conditions)
        total_rules = all_rules.any? ? all_rules.size : @executed_rules.size
        covered_rules = @executed_rules.size
        untested_rules = all_rules.any? ? (all_rules - @executed_rules.to_a) : []

        # Cap coverage at 1.0 (100%)
        coverage_percentage = if total_rules.positive?
                                [(covered_rules.to_f / total_rules), 1.0].min
                              else
                                0.0
                              end

        # Build rule coverage details
        rule_coverage = all_rules.map do |rule|
          {
            rule_id: rule,
            covered: @executed_rules.include?(rule),
            execution_count: @rule_evaluation_count[rule] || 0
          }
        end

        # Build condition coverage details
        condition_coverage = all_conditions.map do |condition|
          {
            condition_id: condition,
            covered: @executed_conditions.include?(condition),
            execution_count: @condition_evaluation_count[condition] || 0
          }
        end

        CoverageReport.new(
          total_rules: total_rules,
          covered_rules: covered_rules,
          untested_rules: untested_rules,
          coverage_percentage: coverage_percentage,
          rule_coverage: rule_coverage,
          condition_coverage: condition_coverage
        )
      end
    end
  end
end
