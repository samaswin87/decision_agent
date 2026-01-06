require "spec_helper"

RSpec.describe DecisionAgent::Simulation::ShadowTestEngine do
  let(:production_evaluator) do
    DecisionAgent::Evaluators::JsonRuleEvaluator.new(
      rules_json: {
        version: "1.0",
        ruleset: "production_rules",
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
  let(:production_agent) { DecisionAgent::Agent.new(evaluators: [production_evaluator]) }
  let(:version_manager) { DecisionAgent::Versioning::VersionManager.new }
  let(:engine) { described_class.new(production_agent: production_agent, version_manager: version_manager) }

  describe "#initialize" do
    it "creates a shadow test engine with production agent" do
      expect(engine.production_agent).to eq(production_agent)
      expect(engine.version_manager).to eq(version_manager)
    end
  end

  describe "#test" do
    let(:context) { { amount: 1500 } }
    let(:shadow_version) do
      version_manager.save_version(
        rule_id: "test_rule",
        rule_content: {
          version: "1.0",
          ruleset: "shadow_rules",
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

    it "executes shadow test and compares with production" do
      result = engine.test(context: context, shadow_version: shadow_version[:id])

      expect(result[:production_decision]).to eq("approve")
      expect(result[:shadow_decision]).to be_a(String)
      expect(result[:matches]).to be_in([true, false])
      expect(result[:confidence_delta]).to be_a(Numeric)
    end

    it "tracks differences when decisions don't match" do
      result = engine.test(
        context: context,
        shadow_version: shadow_version[:id],
        options: { track_differences: true }
      )

      if !result[:matches]
        expect(result[:differences]).to be_a(Hash)
        expect(result[:differences][:decision_mismatch]).to be true
      end
    end
  end

  describe "#batch_test" do
    let(:contexts) do
      [
        { amount: 1500 },
        { amount: 500 },
        { amount: 2500 }
      ]
    end

    let(:shadow_version) do
      version_manager.save_version(
        rule_id: "test_rule",
        rule_content: {
          version: "1.0",
          ruleset: "shadow_rules",
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

    it "executes batch shadow tests" do
      results = engine.batch_test(
        contexts: contexts,
        shadow_version: shadow_version[:id]
      )

      expect(results[:total_tests]).to eq(3)
      expect(results[:matches]).to be >= 0
      expect(results[:mismatches]).to be >= 0
      expect(results[:match_rate]).to be >= 0
      expect(results[:match_rate]).to be <= 1.0
    end

    it "calculates decision distributions" do
      results = engine.batch_test(
        contexts: contexts,
        shadow_version: shadow_version[:id]
      )

      expect(results[:decision_distribution]).to be_a(Hash)
      expect(results[:decision_distribution][:production]).to be_a(Hash)
      expect(results[:decision_distribution][:shadow]).to be_a(Hash)
    end
  end
end

