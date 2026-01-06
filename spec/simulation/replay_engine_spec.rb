require "spec_helper"
require "tempfile"

RSpec.describe DecisionAgent::Simulation::ReplayEngine do
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
  let(:engine) { described_class.new(agent: agent, version_manager: version_manager) }

  describe "#initialize" do
    it "creates a replay engine with agent and version manager" do
      expect(engine.agent).to eq(agent)
      expect(engine.version_manager).to eq(version_manager)
    end
  end

  describe "#replay" do
    let(:historical_data) do
      [
        { amount: 1500 },
        { amount: 500 },
        { amount: 2000 }
      ]
    end

    it "replays historical decisions" do
      results = engine.replay(historical_data: historical_data)

      expect(results[:total_decisions]).to eq(3)
      expect(results[:results].size).to eq(3)
      expect(results[:results][0][:replay_decision]).to eq("approve")
      expect(results[:results][1][:replay_decision]).to eq("reject")
    end

    it "compares with baseline version when provided" do
      # Create baseline version with different rules
      baseline_version = version_manager.save_version(
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

      results = engine.replay(
        historical_data: historical_data,
        compare_with: baseline_version[:id]
      )

      expect(results[:has_baseline]).to be true
      expect(results[:changed_decisions]).to be > 0
    end

    it "loads historical data from CSV file" do
      csv_file = Tempfile.new(["historical", ".csv"])
      CSV.open(csv_file.path, "w") do |csv|
        csv << ["amount"]
        csv << ["1500"]
        csv << ["500"]
      end

      results = engine.replay(historical_data: csv_file.path)
      expect(results[:total_decisions]).to eq(2)

      csv_file.close
      csv_file.unlink
    end

    it "loads historical data from JSON file" do
      json_file = Tempfile.new(["historical", ".json"])
      json_file.write([{ amount: 1500 }, { amount: 500 }].to_json)
      json_file.close

      results = engine.replay(historical_data: json_file.path)
      expect(results[:total_decisions]).to eq(2)

      json_file.unlink
    end

    it "raises error for unsupported file format" do
      txt_file = Tempfile.new(["historical", ".txt"])
      txt_file.write("test")
      txt_file.close

      expect do
        engine.replay(historical_data: txt_file.path)
      end.to raise_error(DecisionAgent::Simulation::InvalidHistoricalDataError)

      txt_file.unlink
    end
  end

  describe "#backtest" do
    let(:historical_data) { [{ amount: 1500 }, { amount: 500 }] }

    it "backtests proposed version against baseline" do
      # Create versions
      baseline_version = version_manager.save_version(
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

      proposed_version = version_manager.save_version(
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

      results = engine.backtest(
        historical_data: historical_data,
        proposed_version: proposed_version[:id],
        baseline_version: baseline_version[:id]
      )

      expect(results[:has_baseline]).to be true
      expect(results[:change_rate]).to be >= 0
    end
  end
end

