module DecisionAgent
  module Testing
    # Comparison result for a single test scenario
    class ComparisonResult
      attr_reader :scenario_id, :match, :decision_match, :confidence_match, :differences, :actual, :expected

      # rubocop:disable Metrics/ParameterLists
      def initialize(scenario_id:, match:, decision_match:, confidence_match:, differences:, actual:, expected:)
        @scenario_id = scenario_id.to_s.freeze
        @match = match
        @decision_match = decision_match
        @confidence_match = confidence_match
        @differences = differences.freeze
        @actual = actual
        @expected = expected

        freeze
      end
      # rubocop:enable Metrics/ParameterLists

      def to_h
        {
          scenario_id: @scenario_id,
          match: @match,
          decision_match: @decision_match,
          confidence_match: @confidence_match,
          differences: @differences,
          actual: {
            decision: @actual[:decision],
            confidence: @actual[:confidence]
          },
          expected: {
            decision: @expected[:decision],
            confidence: @expected[:confidence]
          }
        }
      end
    end

    # Compares test results with expected outcomes
    class TestResultComparator
      attr_reader :comparison_results

      def initialize(options = {})
        @options = {
          confidence_tolerance: 0.01, # 1% tolerance for confidence comparison
          fuzzy_match: false # Whether to do fuzzy matching on decisions
        }.merge(options)
        @comparison_results = []
      end

      # Compare test results with expected results from scenarios
      # @param results [Array<TestResult>] Actual test results
      # @param scenarios [Array<TestScenario>] Test scenarios with expected results
      # @return [Hash] Comparison summary with accuracy metrics
      def compare(results, scenarios)
        @comparison_results = []

        # Create a map of scenario_id -> scenario for quick lookup
        scenarios.each_with_object({}) do |scenario, map|
          map[scenario.id] = scenario
        end

        # Create a map of scenario_id -> result for quick lookup
        result_map = results.each_with_object({}) do |result, map|
          map[result.scenario_id] = result
        end

        # Compare each scenario with its result
        scenarios.each do |scenario|
          next unless scenario.expected_result?

          result = result_map[scenario.id]
          # Only compare if we have a result (skip if result is missing)
          next unless result

          comparison = compare_single(scenario, result)
          @comparison_results << comparison
        end

        generate_summary
      end

      # Generate a summary report
      # @return [Hash] Summary with accuracy metrics and mismatches
      def generate_summary
        return empty_summary if @comparison_results.empty?

        total = @comparison_results.size
        matches = @comparison_results.count(&:match)
        mismatches = total - matches

        {
          total: total,
          matches: matches,
          mismatches: mismatches,
          accuracy_rate: matches.to_f / total,
          decision_accuracy: @comparison_results.count(&:decision_match).to_f / total,
          confidence_accuracy: @comparison_results.count(&:confidence_match).to_f / total,
          mismatches_detail: @comparison_results.reject(&:match).map(&:to_h)
        }
      end

      # Export comparison results to CSV
      # @param file_path [String] Path to output CSV file
      def export_csv(file_path)
        require "csv"

        CSV.open(file_path, "w") do |csv|
          csv << %w[scenario_id match decision_match confidence_match expected_decision actual_decision expected_confidence
                    actual_confidence differences]
          @comparison_results.each do |result|
            csv << [
              result.scenario_id,
              result.match,
              result.decision_match,
              result.confidence_match,
              result.expected[:decision],
              result.actual[:decision],
              result.expected[:confidence],
              result.actual[:confidence],
              result.differences.join("; ")
            ]
          end
        end
      end

      # Export comparison results to JSON
      # @param file_path [String] Path to output JSON file
      def export_json(file_path)
        require "json"

        File.write(file_path, JSON.pretty_generate({
                                                     summary: generate_summary,
                                                     results: @comparison_results.map(&:to_h)
                                                   }))
      end

      private

      # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
      def compare_single(scenario, result)
        differences = []
        confidence_match = false

        if result.nil? || !result.success?
          differences << "Test execution failed: #{result&.error&.message || 'No result'}"
          return ComparisonResult.new(
            scenario_id: scenario.id,
            match: false,
            decision_match: false,
            confidence_match: false,
            differences: differences,
            actual: { decision: nil, confidence: nil },
            expected: {
              decision: scenario.expected_decision,
              confidence: scenario.expected_confidence
            }
          )
        end

        # Compare decision
        expected_decision = scenario.expected_decision&.to_s
        actual_decision = result.decision&.to_s

        decision_match = if expected_decision.nil?
                           true # No expectation, so it matches
                         elsif @options[:fuzzy_match]
                           fuzzy_decision_match?(expected_decision, actual_decision)
                         else
                           expected_decision == actual_decision
                         end

        differences << "Decision mismatch: expected '#{expected_decision}', got '#{actual_decision}'" unless decision_match

        # Compare confidence
        expected_confidence = scenario.expected_confidence
        actual_confidence = result.confidence

        if expected_confidence.nil?
          confidence_match = true # No expectation, so it matches
        elsif actual_confidence.nil?
          confidence_match = false
          differences << "Confidence missing in actual result"
        else
          tolerance = @options[:confidence_tolerance]
          confidence_match = (expected_confidence - actual_confidence).abs <= tolerance
          unless confidence_match
            diff = (expected_confidence - actual_confidence).abs.round(4)
            differences << "Confidence mismatch: expected #{expected_confidence}, got #{actual_confidence} (diff: #{diff})"
          end
        end

        match = decision_match && confidence_match

        ComparisonResult.new(
          scenario_id: scenario.id,
          match: match,
          decision_match: decision_match,
          confidence_match: confidence_match,
          differences: differences,
          actual: {
            decision: actual_decision,
            confidence: actual_confidence
          },
          expected: {
            decision: expected_decision,
            confidence: expected_confidence
          }
        )
      end
      # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity

      def fuzzy_decision_match?(expected, actual)
        return true if expected == actual
        return true if expected&.downcase == actual&.downcase
        return true if expected&.strip == actual&.strip

        false
      end

      def empty_summary
        {
          total: 0,
          matches: 0,
          mismatches: 0,
          accuracy_rate: 0.0,
          decision_accuracy: 0.0,
          confidence_accuracy: 0.0,
          mismatches_detail: []
        }
      end
    end
  end
end
