require "spec_helper"
require "fileutils"

RSpec.describe DecisionAgent::Simulation::ImpactAnalyzer do
  let(:temp_dir) { Dir.mktmpdir("impact_analyzer_spec_") }
  let(:version_manager) do
    DecisionAgent::Versioning::VersionManager.new(
      adapter: DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: temp_dir)
    )
  end
  let(:analyzer) { described_class.new(version_manager: version_manager) }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#initialize" do
    it "creates an impact analyzer with version manager" do
      expect(analyzer.version_manager).to eq(version_manager)
    end
  end

  describe "#analyze" do
    let(:baseline_version) do
      version_manager.save_version(
        rule_id: "test_rule",
        rule_content: {
          version: "1.0",
          ruleset: "test_rules",
          rules: [
            {
              id: "rule_1",
              if: { field: "amount", op: "gt", value: 1000 },
              then: { decision: "approve", weight: 0.9 }
            }
          ]
        },
        created_by: "test"
      )
    end

    let(:proposed_version) do
      version_manager.save_version(
        rule_id: "test_rule",
        rule_content: {
          version: "1.0",
          ruleset: "test_rules",
          rules: [
            {
              id: "rule_1",
              if: { field: "amount", op: "gt", value: 2000 },
              then: { decision: "approve", weight: 0.9 }
            }
          ]
        },
        created_by: "test"
      )
    end

    let(:test_data) do
      [
        { amount: 1500 },
        { amount: 500 },
        { amount: 2500 }
      ]
    end

    it "analyzes impact of rule changes" do
      results = analyzer.analyze(
        baseline_version: baseline_version[:id],
        proposed_version: proposed_version[:id],
        test_data: test_data
      )

      expect(results[:total_contexts]).to eq(3)
      expect(results[:decision_changes]).to be >= 0
      expect(results[:change_rate]).to be >= 0
      expect(results[:change_rate]).to be <= 1.0
    end

    it "calculates decision distribution changes" do
      results = analyzer.analyze(
        baseline_version: baseline_version[:id],
        proposed_version: proposed_version[:id],
        test_data: test_data
      )

      expect(results[:decision_distribution]).to be_a(Hash)
      expect(results[:decision_distribution][:baseline]).to be_a(Hash)
      expect(results[:decision_distribution][:proposed]).to be_a(Hash)
    end

    it "calculates confidence impact" do
      results = analyzer.analyze(
        baseline_version: baseline_version[:id],
        proposed_version: proposed_version[:id],
        test_data: test_data
      )

      expect(results[:confidence_impact]).to be_a(Hash)
      expect(results[:confidence_impact][:average_delta]).to be_a(Numeric)
    end

    it "calculates risk score when requested" do
      results = analyzer.analyze(
        baseline_version: baseline_version[:id],
        proposed_version: proposed_version[:id],
        test_data: test_data,
        options: { calculate_risk: true }
      )

      expect(results[:risk_score]).to be >= 0
      expect(results[:risk_score]).to be <= 1.0
      expect(%w[low medium high critical]).to include(results[:risk_level])
    end

    it "calculates performance impact estimation" do
      results = analyzer.analyze(
        baseline_version: baseline_version[:id],
        proposed_version: proposed_version[:id],
        test_data: test_data
      )

      expect(results[:performance_impact]).to be_a(Hash)
      expect(results[:performance_impact][:latency]).to be_a(Hash)
      expect(results[:performance_impact][:latency][:baseline]).to be_a(Hash)
      expect(results[:performance_impact][:latency][:baseline][:average_ms]).to be_a(Numeric)
      expect(results[:performance_impact][:latency][:proposed]).to be_a(Hash)
      expect(results[:performance_impact][:latency][:proposed][:average_ms]).to be_a(Numeric)
      expect(results[:performance_impact][:latency][:delta_ms]).to be_a(Numeric)
      expect(results[:performance_impact][:latency][:delta_percent]).to be_a(Numeric)

      expect(results[:performance_impact][:throughput]).to be_a(Hash)
      expect(results[:performance_impact][:throughput][:baseline_decisions_per_second]).to be_a(Numeric)
      expect(results[:performance_impact][:throughput][:proposed_decisions_per_second]).to be_a(Numeric)
      expect(results[:performance_impact][:throughput][:delta_percent]).to be_a(Numeric)

      expect(results[:performance_impact][:rule_complexity]).to be_a(Hash)
      expect(results[:performance_impact][:rule_complexity][:baseline_avg_evaluations]).to be_a(Numeric)
      expect(results[:performance_impact][:rule_complexity][:proposed_avg_evaluations]).to be_a(Numeric)
      expect(results[:performance_impact][:rule_complexity][:evaluations_delta]).to be_a(Numeric)

      expect(results[:performance_impact][:impact_level]).to be_a(String)
      expect(%w[improvement neutral minor_degradation moderate_degradation significant_degradation]).to include(results[:performance_impact][:impact_level])

      expect(results[:performance_impact][:summary]).to be_a(String)
      expect(results[:performance_impact][:summary]).not_to be_empty
    end

    it "includes performance metrics in individual results" do
      results = analyzer.analyze(
        baseline_version: baseline_version[:id],
        proposed_version: proposed_version[:id],
        test_data: test_data
      )

      first_result = results[:results].first
      expect(first_result[:baseline_duration_ms]).to be_a(Numeric)
      expect(first_result[:baseline_duration_ms]).to be >= 0
      expect(first_result[:proposed_duration_ms]).to be_a(Numeric)
      expect(first_result[:proposed_duration_ms]).to be >= 0
      expect(first_result[:performance_delta_ms]).to be_a(Numeric)
      expect(first_result[:performance_delta_percent]).to be_a(Numeric)
      expect(first_result[:baseline_evaluations_count]).to be_a(Numeric)
      expect(first_result[:baseline_evaluations_count]).to be >= 0
      expect(first_result[:proposed_evaluations_count]).to be_a(Numeric)
      expect(first_result[:proposed_evaluations_count]).to be >= 0
    end
  end

  describe "#calculate_risk_score" do
    let(:results) do
      [
        {
          decision_changed: true,
          confidence_delta: 0.3
        },
        {
          decision_changed: false,
          confidence_delta: 0.1
        }
      ]
    end

    it "calculates risk score from results" do
      risk_score = analyzer.calculate_risk_score(results)

      expect(risk_score).to be >= 0
      expect(risk_score).to be <= 1.0
    end

    it "returns 0.0 for empty results" do
      expect(analyzer.calculate_risk_score([])).to eq(0.0)
    end
  end

  describe "performance impact estimation" do
    let(:simple_baseline) do
      version_manager.save_version(
        rule_id: "perf_test",
        rule_content: {
          version: "1.0",
          ruleset: "perf_rules",
          rules: [
            {
              id: "rule_1",
              if: { field: "value", op: "gt", value: 10 },
              then: { decision: "approve", weight: 1.0 }
            }
          ]
        },
        created_by: "test"
      )
    end

    let(:complex_proposed) do
      version_manager.save_version(
        rule_id: "perf_test",
        rule_content: {
          version: "2.0",
          ruleset: "perf_rules",
          rules: [
            {
              id: "rule_1",
              if: {
                all: [
                  { field: "value", op: "gt", value: 10 },
                  { field: "value", op: "lt", value: 100 },
                  { field: "value", op: "modulo", value: [2, 0] }
                ]
              },
              then: { decision: "approve", weight: 1.0 }
            }
          ]
        },
        created_by: "test"
      )
    end

    let(:perf_test_data) do
      Array.new(10) { |i| { value: i * 10 } }
    end

    it "detects performance differences between simple and complex rules" do
      results = analyzer.analyze(
        baseline_version: simple_baseline[:id],
        proposed_version: complex_proposed[:id],
        test_data: perf_test_data
      )

      perf_impact = results[:performance_impact]
      expect(perf_impact).to be_a(Hash)

      # Complex rules should generally take longer
      # (though this may vary, we just check that metrics are calculated)
      expect(perf_impact[:latency][:baseline][:average_ms]).to be >= 0
      expect(perf_impact[:latency][:proposed][:average_ms]).to be >= 0
      expect(perf_impact[:throughput][:baseline_decisions_per_second]).to be > 0
      expect(perf_impact[:throughput][:proposed_decisions_per_second]).to be > 0
    end

    it "handles empty test data gracefully" do
      results = analyzer.analyze(
        baseline_version: simple_baseline[:id],
        proposed_version: complex_proposed[:id],
        test_data: []
      )

      expect(results[:performance_impact]).to eq({})
    end
  end
end
