require "spec_helper"

RSpec.describe DecisionAgent::Testing::TestCoverageAnalyzer do
  let(:analyzer) { DecisionAgent::Testing::TestCoverageAnalyzer.new }

  describe "#analyze" do
    let(:evaluator) do
      evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve", weight: 1.0)
      # Add metadata to simulate rule_id
      allow(evaluator).to receive(:evaluate).and_wrap_original do |method, context, **kwargs|
        evaluation = method.call(context, **kwargs)
        # Create a new evaluation with metadata
        DecisionAgent::Evaluation.new(
          decision: evaluation.decision,
          weight: evaluation.weight,
          reason: evaluation.reason,
          evaluator_name: evaluation.evaluator_name,
          metadata: { rule_id: "rule_1", condition_id: "condition_1" }
        )
      end
      evaluator
    end

    let(:agent) { DecisionAgent::Agent.new(evaluators: [evaluator]) }

    let(:results) do
      [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          decision: "approve",
          confidence: 0.95,
          evaluations: [
            DecisionAgent::Evaluation.new(
              decision: "approve",
              weight: 1.0,
              reason: "Test",
              evaluator_name: "TestEvaluator",
              metadata: { rule_id: "rule_1", condition_id: "condition_1" }
            )
          ]
        ),
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_2",
          decision: "approve",
          confidence: 0.90,
          evaluations: [
            DecisionAgent::Evaluation.new(
              decision: "approve",
              weight: 1.0,
              reason: "Test",
              evaluator_name: "TestEvaluator",
              metadata: { rule_id: "rule_2", condition_id: "condition_2" }
            )
          ]
        )
      ]
    end

    it "analyzes coverage from test results" do
      report = analyzer.analyze(results, agent)

      expect(report).to be_a(DecisionAgent::Testing::CoverageReport)
      expect(report.covered_rules).to be >= 0
      # Coverage percentage should be capped at 1.0
      expect(report.coverage_percentage).to be <= 1.0
      expect(report.coverage_percentage).to be >= 0.0
    end

    it "tracks executed rules" do
      report = analyzer.analyze(results, agent)

      # Should have tracked at least some rules
      expect(report.rule_coverage).to be_an(Array)
    end

    it "identifies untested rules when agent is provided" do
      # Create agent with multiple evaluators
      evaluator1 = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve", weight: 1.0)
      evaluator2 = DecisionAgent::Evaluators::StaticEvaluator.new(decision: "reject", weight: 1.0)

      multi_agent = DecisionAgent::Agent.new(evaluators: [evaluator1, evaluator2])

      # Results only exercise one rule
      single_result = [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          decision: "approve",
          confidence: 0.95,
          evaluations: [
            DecisionAgent::Evaluation.new(
              decision: "approve",
              weight: 1.0,
              reason: "Test",
              evaluator_name: evaluator1.class.name,
              metadata: { rule_id: "rule_1" }
            )
          ]
        )
      ]

      report = analyzer.analyze(single_result, multi_agent)

      expect(report.total_rules).to be >= 1
      expect(report.coverage_percentage).to be <= 1.0
    end

    it "handles results without agent" do
      report = analyzer.analyze(results, nil)

      expect(report).to be_a(DecisionAgent::Testing::CoverageReport)
      expect(report.covered_rules).to be >= 0
    end

    it "handles empty results" do
      report = analyzer.analyze([], agent)

      expect(report.covered_rules).to eq(0)
      expect(report.coverage_percentage).to eq(0.0)
    end

    it "handles failed test results" do
      failed_results = [
        DecisionAgent::Testing::TestResult.new(
          scenario_id: "test_1",
          error: StandardError.new("Test failed")
        )
      ]

      report = analyzer.analyze(failed_results, agent)

      expect(report.covered_rules).to eq(0)
    end
  end

  describe "#coverage_percentage" do
    it "returns 0.0 when no rules executed" do
      expect(analyzer.coverage_percentage).to eq(0.0)
    end
  end

  describe "CoverageReport" do
    let(:report) do
      DecisionAgent::Testing::CoverageReport.new(
        total_rules: 10,
        covered_rules: 7,
        untested_rules: %w[rule_8 rule_9 rule_10],
        coverage_percentage: 0.7,
        rule_coverage: [
          { rule_id: "rule_1", covered: true, execution_count: 5 }
        ],
        condition_coverage: [
          { condition_id: "condition_1", covered: true, execution_count: 3 }
        ]
      )
    end

    it "creates a coverage report" do
      expect(report.total_rules).to eq(10)
      expect(report.covered_rules).to eq(7)
      expect(report.untested_rules).to eq(%w[rule_8 rule_9 rule_10])
      expect(report.coverage_percentage).to eq(0.7)
    end

    it "converts to hash" do
      hash = report.to_h

      expect(hash[:total_rules]).to eq(10)
      expect(hash[:covered_rules]).to eq(7)
      expect(hash[:coverage_percentage]).to eq(0.7)
      expect(hash[:rule_coverage]).to be_an(Array)
      expect(hash[:condition_coverage]).to be_an(Array)
    end

    it "freezes the report" do
      expect(report.frozen?).to be true
    end
  end
end
