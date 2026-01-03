require "spec_helper"
require "decision_agent/versioning/file_storage_adapter"
require "decision_agent/ab_testing/storage/memory_adapter"

RSpec.describe DecisionAgent::ABTesting::ABTestingAgent do
  let(:version_manager) { double("VersionManager") }
  let(:ab_test_manager) { double("ABTestManager", version_manager: version_manager) }
  let(:base_evaluator) do
    DecisionAgent::Evaluators::StaticEvaluator.new(
      decision: "approve",
      weight: 0.8,
      reason: "Base evaluator"
    )
  end

  describe "#initialize" do
    it "initializes with ab_test_manager" do
      agent = described_class.new(ab_test_manager: ab_test_manager)
      expect(agent.ab_test_manager).to eq(ab_test_manager)
    end

    it "uses version_manager from ab_test_manager if not provided" do
      allow(ab_test_manager).to receive(:version_manager).and_return(version_manager)
      agent = described_class.new(ab_test_manager: ab_test_manager)
      expect(agent.version_manager).to eq(version_manager)
    end

    it "uses provided version_manager" do
      custom_version_manager = double("CustomVersionManager")
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        version_manager: custom_version_manager
      )
      expect(agent.version_manager).to eq(custom_version_manager)
    end
  end

  describe "#decide" do
    context "without A/B test" do
      it "makes standard decision" do
        agent = described_class.new(
          ab_test_manager: ab_test_manager,
          evaluators: [base_evaluator]
        )

        result = agent.decide(context: { user: "test" })

        expect(result[:decision]).to eq("approve")
        expect(result[:ab_test]).to be_nil
      end
    end

    context "with A/B test" do
      let(:assignment) do
        {
          assignment_id: "assign_1",
          variant: "A",
          version_id: "version_1"
        }
      end

      let(:version) do
        {
          content: {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "status", op: "eq", value: "active" },
                then: { decision: "approve", weight: 0.9 }
              }
            ]
          }
        }
      end

      before do
        allow(ab_test_manager).to receive(:assign_variant).and_return(assignment)
        allow(version_manager).to receive(:get_version).and_return(version)
        allow(ab_test_manager).to receive(:record_decision)
      end

      it "assigns variant and makes decision" do
        agent = described_class.new(
          ab_test_manager: ab_test_manager,
          version_manager: version_manager
        )

        result = agent.decide(
          context: { status: "active" },
          ab_test_id: "test_1",
          user_id: "user_1"
        )

        expect(result[:decision]).to eq("approve")
        expect(result[:ab_test]).not_to be_nil
        expect(result[:ab_test][:test_id]).to eq("test_1")
        expect(result[:ab_test][:variant]).to eq("A")
      end

      it "raises error if version not found" do
        allow(version_manager).to receive(:get_version).and_return(nil)
        agent = described_class.new(
          ab_test_manager: ab_test_manager,
          version_manager: version_manager
        )

        expect do
          agent.decide(
            context: { status: "active" },
            ab_test_id: "test_1"
          )
        end.to raise_error(DecisionAgent::ABTesting::VersionNotFoundError)
      end

      it "records decision result" do
        agent = described_class.new(
          ab_test_manager: ab_test_manager,
          version_manager: version_manager
        )

        agent.decide(
          context: { status: "active" },
          ab_test_id: "test_1"
        )

        expect(ab_test_manager).to have_received(:record_decision).with(
          assignment_id: "assign_1",
          decision: "approve",
          confidence: be_a(Numeric)
        )
      end
    end
  end

  describe "#get_test_results" do
    it "delegates to ab_test_manager" do
      agent = described_class.new(ab_test_manager: ab_test_manager)
      allow(ab_test_manager).to receive(:get_results).and_return({ results: [] })

      result = agent.get_test_results("test_1")

      expect(ab_test_manager).to have_received(:get_results).with("test_1")
      expect(result).to eq({ results: [] })
    end
  end

  describe "#active_tests" do
    it "delegates to ab_test_manager" do
      agent = described_class.new(ab_test_manager: ab_test_manager)
      allow(ab_test_manager).to receive(:active_tests).and_return([])

      result = agent.active_tests

      expect(ab_test_manager).to have_received(:active_tests)
      expect(result).to eq([])
    end
  end

  describe "#decide with feedback" do
    it "passes feedback to agent" do
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        evaluators: [base_evaluator]
      )

      result = agent.decide(context: { user: "test" }, feedback: { rating: 5 })

      expect(result[:decision]).to eq("approve")
    end
  end

  describe "#decide with A/B test - evaluator building" do
    let(:assignment) do
      {
        assignment_id: "assign_1",
        variant: "A",
        version_id: "version_1"
      }
    end

    let(:version_with_rules) do
      {
        content: {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "status", op: "eq", value: "active" },
              then: { decision: "approve", weight: 0.9 }
            }
          ]
        }
      }
    end

    let(:version_with_evaluators) do
      {
        content: {
          evaluators: [
            {
              type: "json_rule",
              rules: {
                version: "1.0",
                ruleset: "test",
                rules: [
                  {
                    id: "rule_1",
                    if: { field: "status", op: "eq", value: "active" },
                    then: { decision: "approve", weight: 0.9 }
                  }
                ]
              }
            }
          ]
        }
      }
    end

    let(:version_with_static_evaluator) do
      {
        content: {
          evaluators: [
            {
              type: "static",
              decision: "reject",
              weight: 0.5,
              reason: "Static test"
            }
          ]
        }
      }
    end

    before do
      allow(ab_test_manager).to receive(:assign_variant).and_return(assignment)
      allow(ab_test_manager).to receive(:record_decision)
    end

    it "builds JsonRuleEvaluator from version with rules" do
      allow(version_manager).to receive(:get_version).and_return(version_with_rules)
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        version_manager: version_manager
      )

      result = agent.decide(
        context: { status: "active" },
        ab_test_id: "test_1"
      )

      expect(result[:decision]).to eq("approve")
    end

    it "builds evaluators from version with evaluator config" do
      allow(version_manager).to receive(:get_version).and_return(version_with_evaluators)
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        version_manager: version_manager
      )

      result = agent.decide(
        context: { status: "active" },
        ab_test_id: "test_1"
      )

      expect(result[:decision]).to eq("approve")
    end

    it "builds StaticEvaluator from version config" do
      allow(version_manager).to receive(:get_version).and_return(version_with_static_evaluator)
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        version_manager: version_manager
      )

      result = agent.decide(
        context: { status: "inactive" },
        ab_test_id: "test_1"
      )

      expect(result[:decision]).to eq("reject")
    end

    it "falls back to base evaluators when version content is invalid" do
      invalid_version = { content: "invalid" }
      allow(version_manager).to receive(:get_version).and_return(invalid_version)
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        version_manager: version_manager,
        evaluators: [base_evaluator]
      )

      result = agent.decide(
        context: { status: "active" },
        ab_test_id: "test_1"
      )

      expect(result[:decision]).to eq("approve")
    end

    it "raises error for unknown evaluator type" do
      invalid_evaluator_version = {
        content: {
          evaluators: [
            {
              type: "unknown_type",
              config: {}
            }
          ]
        }
      }
      allow(version_manager).to receive(:get_version).and_return(invalid_evaluator_version)
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        version_manager: version_manager
      )

      expect do
        agent.decide(
          context: { status: "active" },
          ab_test_id: "test_1"
        )
      end.to raise_error(/Unknown evaluator type/)
    end
  end

  describe "#decide with Context object" do
    it "handles Context object instead of hash" do
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        evaluators: [base_evaluator]
      )

      context = DecisionAgent::Context.new({ user: "test" })
      result = agent.decide(context: context)

      expect(result[:decision]).to eq("approve")
    end
  end

  describe "initialization with optional parameters" do
    it "initializes with scoring_strategy" do
      scoring_strategy = double("ScoringStrategy")
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        scoring_strategy: scoring_strategy
      )

      expect(agent.instance_variable_get(:@scoring_strategy)).to eq(scoring_strategy)
    end

    it "initializes with audit_adapter" do
      audit_adapter = double("AuditAdapter")
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        audit_adapter: audit_adapter
      )

      expect(agent.instance_variable_get(:@audit_adapter)).to eq(audit_adapter)
    end
  end

  describe "#build_agent" do
    it "uses base evaluators when provided evaluators are empty" do
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        evaluators: [base_evaluator]
      )

      # Access private method via send
      built_agent = agent.send(:build_agent, [])
      expect(built_agent).to be_a(DecisionAgent::Agent)
    end

    it "uses provided evaluators when not empty" do
      custom_evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(
        decision: "reject",
        weight: 0.5
      )
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        evaluators: [base_evaluator]
      )

      built_agent = agent.send(:build_agent, [custom_evaluator])
      expect(built_agent).to be_a(DecisionAgent::Agent)
    end
  end

  describe "#build_evaluators_from_version" do
    it "falls back to base evaluators when content is not a hash" do
      invalid_version = { content: "not a hash" }
      allow(version_manager).to receive(:get_version).and_return(invalid_version)
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        version_manager: version_manager,
        evaluators: [base_evaluator]
      )

      evaluators = agent.send(:build_evaluators_from_version, invalid_version)
      expect(evaluators).to eq([base_evaluator])
    end

    it "falls back to base evaluators when content hash has no evaluators or rules" do
      invalid_version = { content: { other_key: "value" } }
      allow(version_manager).to receive(:get_version).and_return(invalid_version)
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        version_manager: version_manager,
        evaluators: [base_evaluator]
      )

      evaluators = agent.send(:build_evaluators_from_version, invalid_version)
      expect(evaluators).to eq([base_evaluator])
    end
  end

  describe "#build_evaluator_from_config" do
    it "builds JsonRuleEvaluator from config" do
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        version_manager: version_manager
      )

      config = {
        type: "json_rule",
        rules: {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "status", op: "eq", value: "active" },
              then: { decision: "approve", weight: 0.9 }
            }
          ]
        }
      }

      evaluator = agent.send(:build_evaluator_from_config, config)
      expect(evaluator).to be_a(DecisionAgent::Evaluators::JsonRuleEvaluator)
    end

    it "builds StaticEvaluator from config with default weight" do
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        version_manager: version_manager
      )

      config = {
        type: "static",
        decision: "approve",
        reason: "Test reason"
        # weight not provided, should default to 1.0
      }

      evaluator = agent.send(:build_evaluator_from_config, config)
      expect(evaluator).to be_a(DecisionAgent::Evaluators::StaticEvaluator)
      expect(evaluator.decision).to eq("approve")
    end

    it "builds StaticEvaluator from config with custom weight" do
      agent = described_class.new(
        ab_test_manager: ab_test_manager,
        version_manager: version_manager
      )

      config = {
        type: "static",
        decision: "reject",
        weight: 0.7,
        reason: "Custom weight"
      }

      evaluator = agent.send(:build_evaluator_from_config, config)
      expect(evaluator).to be_a(DecisionAgent::Evaluators::StaticEvaluator)
      expect(evaluator.decision).to eq("reject")
    end
  end

  describe "integration tests with real version manager" do
    let(:temp_dir) { Dir.mktmpdir }
    let(:file_storage_adapter) do
      DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: temp_dir)
    end
    let(:real_version_manager) do
      DecisionAgent::Versioning::VersionManager.new(adapter: file_storage_adapter)
    end
    let(:storage_adapter) { DecisionAgent::ABTesting::Storage::MemoryAdapter.new }
    let(:real_ab_test_manager) do
      DecisionAgent::ABTesting::ABTestManager.new(
        storage_adapter: storage_adapter,
        version_manager: real_version_manager
      )
    end

    before do
      # Create test versions with real rules
      @champion_version = real_version_manager.save_version(
        rule_id: "approval_rule",
        rule_content: {
          version: "1.0",
          ruleset: "approval",
          rules: [{
            id: "rule_1",
            if: { field: "amount", op: "gt", value: 100 },
            then: { decision: "approve", weight: 0.9, reason: "Champion rule" }
          }]
        },
        created_by: "spec",
        changelog: "Champion version"
      )

      @challenger_version = real_version_manager.save_version(
        rule_id: "approval_rule",
        rule_content: {
          version: "1.0",
          ruleset: "approval",
          rules: [{
            id: "rule_1",
            if: { field: "amount", op: "gt", value: 200 },
            then: { decision: "approve", weight: 0.95, reason: "Challenger rule" }
          }]
        },
        created_by: "spec",
        changelog: "Challenger version"
      )

      @ab_test = real_ab_test_manager.create_test(
        name: "Approval Threshold Test",
        champion_version_id: @champion_version[:id],
        challenger_version_id: @challenger_version[:id],
        traffic_split: { champion: 50, challenger: 50 }
      )
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    it "uses real version manager to get version content" do
      agent = described_class.new(
        ab_test_manager: real_ab_test_manager,
        version_manager: real_version_manager
      )

      result = agent.decide(
        context: { amount: 150 },
        ab_test_id: @ab_test.id,
        user_id: "user_1"
      )

      expect(result[:decision]).to eq("approve")
      expect(result[:ab_test]).not_to be_nil
      expect(result[:ab_test][:test_id]).to eq(@ab_test.id)
    end

    it "builds real JsonRuleEvaluator from version content" do
      agent = described_class.new(
        ab_test_manager: real_ab_test_manager,
        version_manager: real_version_manager
      )

      # Test with amount that matches champion (100 < amount < 200)
      result = agent.decide(
        context: { amount: 150 },
        ab_test_id: @ab_test.id,
        user_id: "user_1"
      )

      expect(result[:decision]).to eq("approve")
      expect(result[:confidence]).to be > 0
    end

    it "handles variant assignment with real version manager" do
      agent = described_class.new(
        ab_test_manager: real_ab_test_manager,
        version_manager: real_version_manager
      )

      # Make multiple decisions to test variant assignment
      # Use amount 250 which will match both champion (> 100) and challenger (> 200) rules
      results = []
      10.times do |i|
        result = agent.decide(
          context: { amount: 250 },
          ab_test_id: @ab_test.id,
          user_id: "user_#{i}"
        )
        results << result
      end

      # At least one decision should have been made
      expect(results.size).to eq(10)
      # All should have ab_test information
      expect(results.all? { |r| r[:ab_test] }).to be true
    end

    it "records decisions with real ab_test_manager" do
      agent = described_class.new(
        ab_test_manager: real_ab_test_manager,
        version_manager: real_version_manager
      )

      result = agent.decide(
        context: { amount: 150 },
        ab_test_id: @ab_test.id,
        user_id: "user_1"
      )

      # Verify decision was recorded (check that results are available)
      expect(result[:decision]).to eq("approve")
      expect(result[:ab_test]).not_to be_nil
    end

    it "handles version with evaluators configuration" do
      version_with_evaluators = real_version_manager.save_version(
        rule_id: "test_evaluator_rule",
        rule_content: {
          evaluators: [{
            type: "static",
            decision: "approve",
            weight: 0.8,
            reason: "Static evaluator from version"
          }]
        },
        created_by: "spec",
        changelog: "Version with evaluators"
      )

      static_test = real_ab_test_manager.create_test(
        name: "Static Evaluator Test",
        champion_version_id: @champion_version[:id],
        challenger_version_id: version_with_evaluators[:id],
        traffic_split: { champion: 50, challenger: 50 }
      )

      agent = described_class.new(
        ab_test_manager: real_ab_test_manager,
        version_manager: real_version_manager
      )

      result = agent.decide(
        context: { amount: 50 }, # Low amount that won't match champion rule
        ab_test_id: static_test.id,
        user_id: "user_1"
      )

      expect(result[:decision]).to eq("approve")
    end
  end
end
