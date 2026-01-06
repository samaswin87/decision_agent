require "spec_helper"

RSpec.describe DecisionAgent::Simulation::ScenarioEngine do
  let(:evaluator) do
    DecisionAgent::Evaluators::JsonRuleEvaluator.new(
      rules_json: {
        version: "1.0",
        ruleset: "test_rules",
        rules: [
          {
            id: "rule_1",
            if: { field: "amount", op: "gt", value: 1000 },
            then: { decision: "approve", weight: 0.9 }
          }
        ]
      }
    )
  end
  let(:agent) { DecisionAgent::Agent.new(evaluators: [evaluator]) }
  let(:version_manager) { DecisionAgent::Versioning::VersionManager.new }
  let(:engine) { described_class.new(agent: agent, version_manager: version_manager) }

  describe "#initialize" do
    it "creates a scenario engine with agent and version manager" do
      expect(engine.agent).to eq(agent)
      expect(engine.version_manager).to eq(version_manager)
    end
  end

  describe "#execute" do
    let(:scenario) do
      {
        context: { amount: 1500 },
        metadata: { type: "test" }
      }
    end

    it "executes a single scenario" do
      result = engine.execute(scenario: scenario)

      expect(result[:scenario_id]).to be_a(String)
      expect(result[:decision]).to eq("approve")
      expect(result[:confidence]).to be > 0
      expect(result[:context]).to eq({ amount: 1500 })
    end
  end

  describe "#execute_batch" do
    let(:scenarios) do
      [
        { context: { amount: 1500 } },
        { context: { amount: 500 } },
        { context: { amount: 2000 } }
      ]
    end

    it "executes multiple scenarios" do
      results = engine.execute_batch(scenarios: scenarios)

      expect(results[:total_scenarios]).to eq(3)
      expect(results[:results].size).to eq(3)
    end

    it "calculates decision distribution" do
      results = engine.execute_batch(scenarios: scenarios)

      expect(results[:decision_distribution]).to be_a(Hash)
    end

    it "calculates average confidence" do
      results = engine.execute_batch(scenarios: scenarios)

      expect(results[:average_confidence]).to be > 0
      expect(results[:average_confidence]).to be <= 1.0
    end
  end

  describe "#compare_versions" do
    let(:scenarios) do
      [
        { context: { amount: 1500 } },
        { context: { amount: 500 } }
      ]
    end

    let(:version1) do
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

    let(:version2) do
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

    it "compares scenarios across versions" do
      results = engine.compare_versions(
        scenarios: scenarios,
        versions: [version1[:id], version2[:id]]
      )

      expect(results[:results_by_version]).to be_a(Hash)
      expect(results[:comparison]).to be_a(Hash)
    end
  end
end

