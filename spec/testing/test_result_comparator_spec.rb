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

    it "handles fuzzy matching" do
      comparator_fuzzy = DecisionAgent::Testing::TestResultComparator.new(fuzzy_match: true)

      scenarios_fuzzy = [
        DecisionAgent::Testing::TestScenario.new(
          id: "test_1",
          context: { user_id: 123 },
          expected_decision: "APPROVE", # Uppercase
          expected_confidence: 0.95
        )
      ]

      results_fuzzy = [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          decision: "approve", # Lowercase - should match with fuzzy
          confidence: 0.95
        )
      ]

      summary = comparator_fuzzy.compare(results_fuzzy, scenarios_fuzzy)
      expect(summary[:matches]).to eq(1)
    end

    it "handles fuzzy matching with whitespace" do
      comparator_fuzzy = DecisionAgent::Testing::TestResultComparator.new(fuzzy_match: true)

      scenarios_fuzzy = [
        DecisionAgent::Testing::TestScenario.new(
          id: "test_1",
          context: { user_id: 123 },
          expected_decision: " approve ", # With spaces
          expected_confidence: 0.95
        )
      ]

      results_fuzzy = [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          decision: "approve", # Without spaces - should match with fuzzy
          confidence: 0.95
        )
      ]

      summary = comparator_fuzzy.compare(results_fuzzy, scenarios_fuzzy)
      expect(summary[:matches]).to eq(1)
    end

    it "handles nil expected confidence" do
      scenarios_nil_conf = [
        DecisionAgent::Testing::TestScenario.new(
          id: "test_1",
          context: { user_id: 123 },
          expected_decision: "approve",
          expected_confidence: nil
        )
      ]

      results_nil_conf = [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          decision: "approve",
          confidence: 0.95
        )
      ]

      summary = comparator.compare(results_nil_conf, scenarios_nil_conf)
      expect(summary[:matches]).to eq(1)
    end

    it "handles nil actual confidence when expected is present" do
      scenarios_with_conf = [
        DecisionAgent::Testing::TestScenario.new(
          id: "test_1",
          context: { user_id: 123 },
          expected_decision: "approve",
          expected_confidence: 0.95
        )
      ]

      results_no_conf = [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          decision: "approve",
          confidence: nil
        )
      ]

      summary = comparator.compare(results_no_conf, scenarios_with_conf)
      expect(summary[:matches]).to eq(0)
      expect(summary[:mismatches]).to eq(1)
    end

    it "handles missing results for scenarios" do
      scenarios_missing = [
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

      # Only provide result for test_1
      results_missing = [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          decision: "approve",
          confidence: 0.95
        )
      ]

      summary = comparator.compare(results_missing, scenarios_missing)
      # Should only compare test_1 since test_2 has no result
      expect(summary[:total]).to eq(1)
    end

    it "handles confidence outside tolerance" do
      comparator_strict = DecisionAgent::Testing::TestResultComparator.new(
        confidence_tolerance: 0.01
      )

      scenarios_strict = [
        DecisionAgent::Testing::TestScenario.new(
          id: "test_1",
          context: { user_id: 123 },
          expected_decision: "approve",
          expected_confidence: 0.95
        )
      ]

      results_outside = [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          decision: "approve",
          confidence: 0.98 # Outside 0.01 tolerance
        )
      ]

      summary = comparator_strict.compare(results_outside, scenarios_strict)
      expect(summary[:matches]).to eq(0)
      expect(summary[:confidence_accuracy]).to eq(0.0)
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
      scenarios_with_expected = scenarios.select(&:expected_result?)
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

    it "handles empty comparison results" do
      file = Tempfile.new(["comparison", ".csv"])
      comparator.export_csv(file.path)

      content = File.read(file.path)
      expect(content).to include("scenario_id")

      file.unlink
    end
  end

  describe "ComparisonResult" do
    let(:comparison_result) do
      DecisionAgent::Testing::ComparisonResult.new(
        scenario_id: "test_1",
        match: true,
        decision_match: true,
        confidence_match: true,
        differences: [],
        actual: { decision: "approve", confidence: 0.95 },
        expected: { decision: "approve", confidence: 0.95 }
      )
    end

    it "creates a comparison result" do
      expect(comparison_result.scenario_id).to eq("test_1")
      expect(comparison_result.match).to be true
      expect(comparison_result.decision_match).to be true
      expect(comparison_result.confidence_match).to be true
    end

    it "converts to hash" do
      hash = comparison_result.to_h

      expect(hash[:scenario_id]).to eq("test_1")
      expect(hash[:match]).to be true
      expect(hash[:actual][:decision]).to eq("approve")
      expect(hash[:expected][:decision]).to eq("approve")
    end

    it "freezes the comparison result" do
      expect(comparison_result.frozen?).to be true
    end
  end
end
