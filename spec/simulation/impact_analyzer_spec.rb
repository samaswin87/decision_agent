require "spec_helper"

RSpec.describe DecisionAgent::Simulation::ImpactAnalyzer do
  let(:version_manager) { DecisionAgent::Versioning::VersionManager.new }
  let(:analyzer) { described_class.new(version_manager: version_manager) }

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
      expect(results[:risk_level]).to be_in(%w[low medium high critical])
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
end

