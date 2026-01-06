require "spec_helper"
require "json"

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

      results[:field_sensitivity].each_value do |data|
        expect(data[:impact]).to be >= 0
        expect(data[:impact]).to be <= 1.0
        expect(data[:results]).to be_an(Array)
      end
    end
  end

  describe "#visualize_decision_boundaries" do
    let(:base_scenario) { { name: "Test User", amount: 500 } }

    context "with 1D visualization" do
      let(:parameters) do
        {
          amount: { min: 0, max: 2000, steps: 50 }
        }
      end

      it "generates 1D boundary visualization data" do
        result = analyzer.visualize_decision_boundaries(
          base_scenario: base_scenario,
          parameters: parameters
        )

        expect(result[:type]).to eq("1d_boundary")
        expect(result[:parameter]).to eq(:amount)
        expect(result[:range]).to eq({ min: 0, max: 2000 })
        expect(result[:points]).to be_an(Array)
        expect(result[:points].size).to eq(51) # 0 to 50 inclusive
        expect(result[:points].first).to include(:parameter, :value, :decision, :confidence)
        expect(result[:boundaries]).to be_an(Array)
        expect(result[:decision_distribution]).to be_a(Hash)
      end

      it "identifies boundary points where decisions change" do
        result = analyzer.visualize_decision_boundaries(
          base_scenario: base_scenario,
          parameters: parameters
        )

        # Should have at least one boundary at amount = 1000
        if result[:boundaries].any?
          boundary_values = result[:boundaries].map { |b| b[:value] }
          # Check that boundary is near 1000 (within reasonable range)
          expect(boundary_values.any? { |v| (v - 1000).abs < 50 }).to be true
        end
      end

      it "generates HTML output when requested" do
        result = analyzer.visualize_decision_boundaries(
          base_scenario: base_scenario,
          parameters: parameters,
          options: { output_format: "html" }
        )

        expect(result).to be_a(String)
        expect(result).to include("<!DOCTYPE html>")
        expect(result).to include("Decision Boundary Visualization")
        expect(result).to include("<svg")
      end

      it "generates JSON output when requested" do
        result = analyzer.visualize_decision_boundaries(
          base_scenario: base_scenario,
          parameters: parameters,
          options: { output_format: "json" }
        )

        expect(result).to be_a(String)
        parsed = JSON.parse(result)
        expect(parsed["type"]).to eq("1d_boundary")
      end
    end

    context "with 2D visualization" do
      let(:evaluator_2d) do
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
                if: { field: "credit_score", op: "gte", value: 700 },
                then: { decision: "approve", weight: 0.8, reason: "High credit" }
              },
              {
                id: "rule_3",
                if: { all: [
                  { field: "amount", op: "lte", value: 1000 },
                  { field: "credit_score", op: "lt", value: 700 }
                ] },
                then: { decision: "reject", weight: 0.9, reason: "Low criteria" }
              },
              {
                id: "rule_4",
                if: { field: "amount", op: "present", value: true },
                then: { decision: "approve", weight: 0.5, reason: "Default approval" }
              }
            ]
          }
        )
      end
      let(:agent_2d) { DecisionAgent::Agent.new(evaluators: [evaluator_2d]) }
      let(:analyzer_2d) { described_class.new(agent: agent_2d, version_manager: version_manager) }

      let(:parameters_2d) do
        {
          amount: { min: 0, max: 2000 },
          credit_score: { min: 500, max: 900 }
        }
      end

      it "generates 2D boundary visualization data" do
        result = analyzer_2d.visualize_decision_boundaries(
          base_scenario: base_scenario,
          parameters: parameters_2d,
          options: { resolution: 20 }
        )

        expect(result[:type]).to eq("2d_boundary")
        expect(result[:parameter1]).to eq(:amount)
        expect(result[:parameter2]).to eq(:credit_score)
        expect(result[:range1]).to eq({ min: 0, max: 2000 })
        expect(result[:range2]).to eq({ min: 500, max: 900 })
        expect(result[:resolution]).to eq(20)
        expect(result[:grid]).to be_an(Array)
        expect(result[:grid].size).to eq(21) # 0 to 20 inclusive
        expect(result[:grid].first.size).to eq(21)
        expect(result[:grid].first.first).to include(:param1, :param2, :decision, :confidence)
        expect(result[:boundaries]).to be_an(Array)
        expect(result[:decision_distribution]).to be_a(Hash)
      end

      it "uses default resolution when not specified" do
        result = analyzer_2d.visualize_decision_boundaries(
          base_scenario: base_scenario,
          parameters: parameters_2d
        )

        expect(result[:resolution]).to eq(30) # default for 2D
      end

      it "generates HTML output for 2D visualization" do
        result = analyzer_2d.visualize_decision_boundaries(
          base_scenario: base_scenario,
          parameters: parameters_2d,
          options: { output_format: "html", resolution: 10 }
        )

        expect(result).to be_a(String)
        expect(result).to include("<!DOCTYPE html>")
        expect(result).to include("2D Boundary Visualization")
        expect(result).to include("<svg")
      end
    end

    context "with validation" do
      it "raises error for zero parameters" do
        expect do
          analyzer.visualize_decision_boundaries(
            base_scenario: base_scenario,
            parameters: {}
          )
        end.to raise_error(ArgumentError, /Must specify 1 or 2 parameters/)
      end

      it "raises error for more than 2 parameters" do
        expect do
          analyzer.visualize_decision_boundaries(
            base_scenario: base_scenario,
            parameters: {
              param1: { min: 0, max: 100 },
              param2: { min: 0, max: 100 },
              param3: { min: 0, max: 100 }
            }
          )
        end.to raise_error(ArgumentError, /Must specify 1 or 2 parameters/)
      end

      it "raises error when min/max not provided" do
        expect do
          analyzer.visualize_decision_boundaries(
            base_scenario: base_scenario,
            parameters: {
              amount: { steps: 50 }
            }
          )
        end.to raise_error(ArgumentError, /must include :min and :max/)
      end
    end
  end
end
