require "spec_helper"
require "tempfile"

RSpec.describe DecisionAgent::Testing::TestResultComparator do
  let(:comparator) { DecisionAgent::Testing::TestResultComparator.new }

  describe "#compare" do
    let(:scenarios) do
      [
        DecisionAgent::Testing::TestScenario.new(
          id: "test_1",
          context: { user_id: 123 },
          expected_decision: "approve",
          expected_confidence: 0.95
        ),
        DecisionAgent::Testing::TestScenario.new(
          id: "test_2",
          context: { user_id: 456 },
          expected_decision: "reject",
          expected_confidence: 0.80
        )
      ]
    end

    let(:results) do
      [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          decision: "approve",
          confidence: 0.95
        ),
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_2",
          decision: "reject",
          confidence: 0.80
        )
      ]
    end

    it "compares results with expected outcomes" do
      summary = comparator.compare(results, scenarios)

      expect(summary[:total]).to eq(2)
      expect(summary[:matches]).to eq(2)
      expect(summary[:mismatches]).to eq(0)
      expect(summary[:accuracy_rate]).to eq(1.0)
    end

    it "identifies mismatches" do
      mismatched_results = [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          decision: "reject", # Wrong decision
          confidence: 0.95
        ),
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_2",
          decision: "reject",
          confidence: 0.50 # Wrong confidence
        )
      ]

      summary = comparator.compare(mismatched_results, scenarios)

      expect(summary[:matches]).to eq(0)
      expect(summary[:mismatches]).to eq(2)
      expect(summary[:accuracy_rate]).to eq(0.0)
      expect(summary[:mismatches_detail].size).to eq(2)
    end

    it "handles confidence tolerance" do
      comparator_with_tolerance = DecisionAgent::Testing::TestResultComparator.new(
        confidence_tolerance: 0.1
      )

      results_with_tolerance = [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          decision: "approve",
          confidence: 0.96 # Within 0.1 tolerance of 0.95
        )
      ]

      scenarios_single = [scenarios[0]]
      summary = comparator_with_tolerance.compare(results_with_tolerance, scenarios_single)

      expect(summary[:matches]).to eq(1)
      expect(summary[:confidence_accuracy]).to eq(1.0)
    end

    it "handles missing expected results" do
      scenarios_no_expected = [
        DecisionAgent::Testing::TestScenario.new(
          id: "test_1",
          context: { user_id: 123 }
          # No expected_decision
        )
      ]

      summary = comparator.compare(results, scenarios_no_expected)

      # Should not compare scenarios without expected results
      expect(summary[:total]).to eq(0)
    end

    it "handles failed test results" do
      failed_results = [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          error: StandardError.new("Test failed")
        )
      ]

      # Only compare scenarios that have expected results
      scenarios_with_expected = scenarios.select(&:has_expected_result?)
      summary = comparator.compare(failed_results, scenarios_with_expected)

      expect(summary[:mismatches]).to eq(1)
      expect(comparator.comparison_results[0].match).to be false
    end
  end

  describe "#generate_summary" do
    it "returns empty summary when no comparisons" do
      summary = comparator.generate_summary

      expect(summary[:total]).to eq(0)
      expect(summary[:matches]).to eq(0)
      expect(summary[:accuracy_rate]).to eq(0.0)
    end
  end

  describe "#export_csv" do
    it "exports comparison results to CSV" do
      scenarios = [
        DecisionAgent::Testing::TestScenario.new(
          id: "test_1",
          context: { user_id: 123 },
          expected_decision: "approve",
          expected_confidence: 0.95
        )
      ]

      results = [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          decision: "approve",
          confidence: 0.95
        )
      ]

      comparator.compare(results, scenarios)

      file = Tempfile.new(["comparison", ".csv"])
      comparator.export_csv(file.path)

      content = File.read(file.path)
      expect(content).to include("scenario_id")
      expect(content).to include("test_1")
      expect(content).to include("true") # match

      file.unlink
    end
  end

  describe "#export_json" do
    it "exports comparison results to JSON" do
      scenarios = [
        DecisionAgent::Testing::TestScenario.new(
          id: "test_1",
          context: { user_id: 123 },
          expected_decision: "approve",
          expected_confidence: 0.95
        )
      ]

      results = [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          decision: "approve",
          confidence: 0.95
        )
      ]

      comparator.compare(results, scenarios)

      file = Tempfile.new(["comparison", ".json"])
      comparator.export_json(file.path)

      content = JSON.parse(File.read(file.path))
      expect(content).to have_key("summary")
      expect(content).to have_key("results")
      expect(content["summary"]["total"]).to eq(1)

      file.unlink
    end
  end
end

