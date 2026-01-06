require "spec_helper"

RSpec.describe DecisionAgent::Simulation::WhatIfAnalyzer do
  let(:evaluator) do
    DecisionAgent::Evaluators::JsonRuleEvaluator.new(
      rules_json: {
        version: "1.0",
        ruleset: "test_rules",
        rules: [
          {
            id: "rule_1",
            if: { field: "amount", op: "gt", value: 1000 },
            then: { decision: "approve", weight: 0.9, reason: "High amount" }
          },
          {
            id: "rule_2",
            if: { field: "amount", op: "lte", value: 1000 },
            then: { decision: "reject", weight: 0.8, reason: "Low amount" }
          }
        ]
      }
    )
  end
  let(:agent) { DecisionAgent::Agent.new(evaluators: [evaluator]) }
  let(:version_manager) { DecisionAgent::Versioning::VersionManager.new }
  let(:analyzer) { described_class.new(agent: agent, version_manager: version_manager) }

  describe "#initialize" do
    it "creates a what-if analyzer with agent and version manager" do
      expect(analyzer.agent).to eq(agent)
      expect(analyzer.version_manager).to eq(version_manager)
    end
  end

  describe "#analyze" do
    let(:scenarios) do
      [
        { amount: 1500 },
        { amount: 500 },
        { amount: 2000 }
      ]
    end

    it "analyzes multiple scenarios" do
      results = analyzer.analyze(scenarios: scenarios)

      expect(results[:total_scenarios]).to eq(3)
      expect(results[:scenarios].size).to eq(3)
      expect(results[:scenarios][0][:decision]).to eq("approve")
      expect(results[:scenarios][1][:decision]).to eq("reject")
    end

    it "calculates decision distribution" do
      results = analyzer.analyze(scenarios: scenarios)

      expect(results[:decision_distribution]).to be_a(Hash)
      expect(results[:decision_distribution]["approve"]).to eq(2)
      expect(results[:decision_distribution]["reject"]).to eq(1)
    end

    it "calculates average confidence" do
      results = analyzer.analyze(scenarios: scenarios)

      expect(results[:average_confidence]).to be > 0
      expect(results[:average_confidence]).to be <= 1.0
    end

    it "performs sensitivity analysis when requested" do
      results = analyzer.analyze(
        scenarios: scenarios,
        options: { sensitivity_analysis: true }
      )

      expect(results[:sensitivity]).to be_a(Hash)
    end
  end

  describe "#sensitivity_analysis" do
    let(:base_scenario) { { amount: 1000, credit_score: 700 } }
    let(:variations) do
      {
        amount: [500, 1000, 1500, 2000],
        credit_score: [600, 700, 800]
      }
    end

    it "performs sensitivity analysis on field variations" do
      results = analyzer.sensitivity_analysis(
        base_scenario: base_scenario,
        variations: variations
      )

      expect(results[:base_scenario]).to eq(base_scenario)
      expect(results[:field_sensitivity]).to be_a(Hash)
      expect(results[:field_sensitivity].keys).to include(:amount, :credit_score)
    end

    it "identifies most sensitive fields" do
      results = analyzer.sensitivity_analysis(
        base_scenario: base_scenario,
        variations: variations
      )

      expect(results[:most_sensitive_fields]).to be_an(Array)
    end

    it "calculates impact for each field" do
      results = analyzer.sensitivity_analysis(
        base_scenario: base_scenario,
        variations: variations
      )

      results[:field_sensitivity].each do |_field, data|
        expect(data[:impact]).to be >= 0
        expect(data[:impact]).to be <= 1.0
        expect(data[:results]).to be_an(Array)
      end
    end
  end
end

