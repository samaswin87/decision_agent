# frozen_string_literal: true

require_relative "../testing/test_scenario"
require_relative "../evaluators/dmn_evaluator"
require_relative "parser"

module DecisionAgent
  module Dmn
    # DMN Testing Framework
    # Provides testing capabilities for DMN models
    class DmnTester
      attr_reader :model, :test_scenarios, :test_results

      def initialize(model)
        @model = model
        @test_scenarios = []
        @test_results = []
      end

      # Add a test scenario
      def add_scenario(decision_id:, inputs:, expected_output:, description: nil)
        scenario = {
          decision_id: decision_id,
          inputs: inputs,
          expected_output: expected_output,
          description: description || "Test #{@test_scenarios.size + 1}"
        }

        @test_scenarios << scenario
        scenario
      end

      # Run all test scenarios
      def run_all_tests
        @test_results = []

        @test_scenarios.each_with_index do |scenario, idx|
          result = run_test(scenario, idx)
          @test_results << result
        end

        generate_test_report
      end

      # Run a single test scenario
      def run_test(scenario, index = nil)
        decision = @model.find_decision(scenario[:decision_id])

        unless decision
          return {
            index: index,
            scenario: scenario,
            status: :error,
            error: "Decision '#{scenario[:decision_id]}' not found",
            passed: false
          }
        end

        begin
          # Create evaluator for this decision
          evaluator = Evaluators::DmnEvaluator.new(
            dmn_model: @model,
            decision_id: scenario[:decision_id]
          )

          # Evaluate with test inputs
          context = Context.new(scenario[:inputs])
          result = evaluator.evaluate(context: context)

          # Compare result with expected output
          actual_output = result.decision
          expected_output = scenario[:expected_output]

          passed = outputs_match?(actual_output, expected_output)

          {
            index: index,
            scenario: scenario,
            status: :completed,
            actual_output: actual_output,
            expected_output: expected_output,
            passed: passed,
            result: result
          }
        rescue StandardError => e
          {
            index: index,
            scenario: scenario,
            status: :error,
            error: e.message,
            passed: false
          }
        end
      end

      # Generate test coverage report
      def generate_coverage_report
        coverage = {
          total_decisions: @model.decisions.size,
          tested_decisions: Set.new,
          untested_decisions: [],
          decision_coverage: {}
        }

        # Track which decisions are tested
        @test_scenarios.each do |scenario|
          coverage[:tested_decisions].add(scenario[:decision_id])
        end

        # Find untested decisions
        @model.decisions.each do |decision|
          unless coverage[:tested_decisions].include?(decision.id)
            coverage[:untested_decisions] << decision.id
          end

          # Calculate coverage for each decision
          decision_tests = @test_scenarios.select { |s| s[:decision_id] == decision.id }
          coverage[:decision_coverage][decision.id] = {
            test_count: decision_tests.size,
            tested: !decision_tests.empty?
          }

          # For decision tables, calculate rule coverage
          if decision.decision_table
            rule_coverage = calculate_rule_coverage(decision, decision_tests)
            coverage[:decision_coverage][decision.id][:rule_coverage] = rule_coverage
          end
        end

        coverage[:coverage_percentage] = if coverage[:total_decisions].positive?
                                            (coverage[:tested_decisions].size.to_f / coverage[:total_decisions] * 100).round(2)
                                          else
                                            0
                                          end

        coverage
      end

      # Import test scenarios from CSV
      def import_scenarios_from_csv(file_path)
        require "csv"

        CSV.foreach(file_path, headers: true) do |row|
          inputs = {}
          row.headers.each do |header|
            next if %w[decision_id expected_output description].include?(header)

            inputs[header] = parse_value(row[header])
          end

          add_scenario(
            decision_id: row["decision_id"],
            inputs: inputs,
            expected_output: parse_value(row["expected_output"]),
            description: row["description"]
          )
        end

        @test_scenarios.size
      end

      # Export test scenarios to CSV
      def export_scenarios_to_csv(file_path)
        require "csv"

        return if @test_scenarios.empty?

        # Collect all unique input keys
        input_keys = @test_scenarios.flat_map { |s| s[:inputs].keys }.uniq.sort

        CSV.open(file_path, "w") do |csv|
          # Write headers
          headers = ["decision_id"] + input_keys + ["expected_output", "description"]
          csv << headers

          # Write scenarios
          @test_scenarios.each do |scenario|
            row = [scenario[:decision_id]]
            input_keys.each { |key| row << scenario[:inputs][key] }
            row << scenario[:expected_output]
            row << scenario[:description]
            csv << row
          end
        end

        @test_scenarios.size
      end

      # Clear all test scenarios
      def clear_scenarios
        @test_scenarios = []
        @test_results = []
      end

      private

      def outputs_match?(actual, expected)
        # Handle nil cases
        return true if actual.nil? && expected.nil?
        return false if actual.nil? || expected.nil?

        # For simple values, do direct comparison
        if actual.is_a?(Hash) && expected.is_a?(Hash)
          actual.all? { |k, v| expected[k] == v }
        else
          actual.to_s == expected.to_s
        end
      end

      def calculate_rule_coverage(decision, tests)
        table = decision.decision_table
        return { coverage: 0, tested_rules: [], untested_rules: [] } unless table

        tested_rules = Set.new

        # Run each test and track which rules matched
        tests.each do |test|
          evaluator = Evaluators::DmnEvaluator.new(
            dmn_model: @model,
            decision_id: decision.id
          )

          context = Context.new(test[:inputs])

          begin
            # This would need to be enhanced to track which rule matched
            evaluator.evaluate(context: context)
            # In a full implementation, we'd track the matched rule
          rescue StandardError
            # Ignore errors for coverage calculation
          end
        end

        untested_rules = table.rules.map(&:id).reject { |rid| tested_rules.include?(rid) }

        {
          total_rules: table.rules.size,
          tested_rules: tested_rules.size,
          untested_rules: untested_rules,
          coverage_percentage: if table.rules.size.positive?
                                  (tested_rules.size.to_f / table.rules.size * 100).round(2)
                                else
                                  0
                                end
        }
      end

      def generate_test_report
        total = @test_results.size
        passed = @test_results.count { |r| r[:passed] }
        failed = @test_results.count { |r| !r[:passed] }
        errors = @test_results.count { |r| r[:status] == :error }

        {
          summary: {
            total: total,
            passed: passed,
            failed: failed,
            errors: errors,
            pass_rate: total.positive? ? (passed.to_f / total * 100).round(2) : 0
          },
          results: @test_results,
          coverage: generate_coverage_report
        }
      end

      def parse_value(value)
        return nil if value.nil? || value.empty?

        # Try to parse as number
        return value.to_i if value.match?(/^\d+$/)
        return value.to_f if value.match?(/^\d+\.\d+$/)

        # Try to parse as boolean
        return true if value.downcase == "true"
        return false if value.downcase == "false"

        # Return as string
        value
      end
    end

    # Test Suite for organizing multiple DMN models' tests
    class DmnTestSuite
      attr_reader :models, :testers

      def initialize
        @models = {}
        @testers = {}
      end

      # Add a model to the test suite
      def add_model(model_id, model)
        @models[model_id] = model
        @testers[model_id] = DmnTester.new(model)
      end

      # Get tester for a model
      def tester_for(model_id)
        @testers[model_id]
      end

      # Run all tests for all models
      def run_all
        results = {}

        @testers.each do |model_id, tester|
          results[model_id] = tester.run_all_tests
        end

        generate_suite_report(results)
      end

      # Generate overall suite report
      def generate_suite_report(results)
        total_tests = results.values.sum { |r| r[:summary][:total] }
        total_passed = results.values.sum { |r| r[:summary][:passed] }
        total_failed = results.values.sum { |r| r[:summary][:failed] }

        {
          models_tested: results.size,
          total_tests: total_tests,
          total_passed: total_passed,
          total_failed: total_failed,
          overall_pass_rate: total_tests.positive? ? (total_passed.to_f / total_tests * 100).round(2) : 0,
          model_results: results
        }
      end
    end
  end
end
