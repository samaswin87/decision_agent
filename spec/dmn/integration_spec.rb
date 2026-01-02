require "spec_helper"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/dmn/exporter"
require "decision_agent/evaluators/dmn_evaluator"
require "tempfile"
require "fileutils"

RSpec.describe "DMN Integration" do
  let(:simple_dmn_path) { File.expand_path("../fixtures/dmn/simple_decision.dmn", __dir__) }
  let(:complex_dmn_path) { File.expand_path("../fixtures/dmn/complex_decision.dmn", __dir__) }
  let(:invalid_dmn_path) { File.expand_path("../fixtures/dmn/invalid_structure.dmn", __dir__) }

  # Create temporary directory for file storage adapter
  let(:temp_dir) { Dir.mktmpdir }
  let(:version_manager) do
    DecisionAgent::Versioning::VersionManager.new(
      adapter: DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: temp_dir)
    )
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "import and execute simple decision" do
    it "imports DMN file and makes decisions" do
      # Import
      importer = DecisionAgent::Dmn::Importer.new(version_manager: version_manager)
      result = importer.import(simple_dmn_path, created_by: "test")

      expect(result[:decisions_imported]).to eq(1)
      expect(result[:model]).to be_a(DecisionAgent::Dmn::Model)
      expect(result[:model].decisions.size).to eq(1)

      # Create evaluator
      evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
        model: result[:model],
        decision_id: "age_check"
      )

      # Test approval case (age >= 18)
      context_approve = DecisionAgent::Context.new({ age: 25 })
      evaluation_approve = evaluator.evaluate(context_approve)

      expect(evaluation_approve).not_to be_nil
      expect(evaluation_approve.decision).to eq("approve")
      expect(evaluation_approve.evaluator_name).to include("DmnEvaluator")

      # Test rejection case (age < 18)
      context_reject = DecisionAgent::Context.new({ age: 15 })
      evaluation_reject = evaluator.evaluate(context_reject)

      expect(evaluation_reject).not_to be_nil
      expect(evaluation_reject.decision).to eq("reject")
    end
  end

  describe "import and execute complex decision" do
    it "handles multi-input decision tables" do
      # Import
      importer = DecisionAgent::Dmn::Importer.new(version_manager: version_manager)
      result = importer.import(complex_dmn_path, created_by: "test")

      expect(result[:decisions_imported]).to eq(1)

      # Create evaluator
      evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
        model: result[:model],
        decision_id: "loan_approval"
      )

      # Test excellent case
      context_excellent = DecisionAgent::Context.new({
                                                       credit_score: 800,
                                                       income: 75000,
                                                       loan_amount: 150000
                                                     })
      evaluation_excellent = evaluator.evaluate(context_excellent)

      expect(evaluation_excellent).not_to be_nil
      expect(evaluation_excellent.decision).to eq("approve")

      # Test good case
      context_good = DecisionAgent::Context.new({
                                                  credit_score: 700,
                                                  income: 45000,
                                                  loan_amount: 100000
                                                })
      evaluation_good = evaluator.evaluate(context_good)

      expect(evaluation_good).not_to be_nil
      expect(evaluation_good.decision).to eq("conditional_approve")

      # Test rejection case
      context_reject = DecisionAgent::Context.new({
                                                    credit_score: 500,
                                                    income: 25000,
                                                    loan_amount: 100000
                                                  })
      evaluation_reject = evaluator.evaluate(context_reject)

      expect(evaluation_reject).not_to be_nil
      expect(evaluation_reject.decision).to eq("reject")
    end
  end

  describe "invalid DMN handling" do
    it "validates and rejects invalid DMN structure" do
      importer = DecisionAgent::Dmn::Importer.new(version_manager: version_manager)

      expect do
        importer.import(invalid_dmn_path, created_by: "test")
      end.to raise_error(DecisionAgent::Dmn::InvalidDmnModelError, /Expected 1 input entries, got 2/)
    end
  end

  describe "round-trip conversion" do
    it "preserves structure through import-export-import cycle" do
      # Import original
      importer = DecisionAgent::Dmn::Importer.new(version_manager: version_manager)
      original = importer.import(simple_dmn_path, ruleset_name: "age_check_v1", created_by: "test")

      expect(original[:decisions_imported]).to eq(1)

      # Export
      exporter = DecisionAgent::Dmn::Exporter.new(version_manager: version_manager)
      exported_xml = exporter.export("age_check_v1")

      expect(exported_xml).to include('xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"')
      expect(exported_xml).to include("<decision")
      expect(exported_xml).to include("<decisionTable")

      # Re-import
      reimported = importer.import_from_xml(exported_xml, ruleset_name: "age_check_v2", created_by: "test")

      # Compare structures
      expect(reimported[:model].decisions.size).to eq(original[:model].decisions.size)
      expect(reimported[:decisions_imported]).to eq(original[:decisions_imported])

      # Verify it still works
      evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
        model: reimported[:model],
        decision_id: reimported[:model].decisions.first.id
      )

      context = DecisionAgent::Context.new({ age: 25 })
      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("approve")
    end
  end

  describe "combining with JSON evaluators" do
    it "works alongside JsonRuleEvaluator in same agent" do
      # Load DMN
      importer = DecisionAgent::Dmn::Importer.new(version_manager: version_manager)
      dmn_result = importer.import(simple_dmn_path, created_by: "test")

      dmn_evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
        model: dmn_result[:model],
        decision_id: "age_check"
      )

      # Create JSON evaluator
      json_rules = {
        version: "1.0",
        ruleset: "json_rules",
        rules: [
          {
            id: "priority_rule",
            if: { field: "priority", op: "eq", value: "high" },
            then: { decision: "escalate", weight: 0.9, reason: "High priority escalation" }
          }
        ]
      }

      json_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(
        rules_json: json_rules
      )

      # Use both in agent
      agent = DecisionAgent::Agent.new(
        evaluators: [dmn_evaluator, json_evaluator]
      )

      # Test with context matching both evaluators
      decision = agent.decide(
        context: { age: 25, priority: "high" }
      )

      expect(["approve", "escalate"]).to include(decision.decision)
      expect(decision.evaluations.size).to eq(2)
      expect(decision.evaluations.map(&:evaluator_name)).to include(
        match(/DmnEvaluator/),
        match(/JsonRuleEvaluator/)
      )
    end
  end

  describe "versioning integration" do
    it "stores and retrieves DMN models from versioning system" do
      importer = DecisionAgent::Dmn::Importer.new(version_manager: version_manager)

      # Import first version
      v1 = importer.import(simple_dmn_path, ruleset_name: "age_check", created_by: "test_user")

      expect(v1[:versions].size).to eq(1)
      expect(v1[:versions].first[:rule_id]).to eq("age_check")

      # Get active version
      active = version_manager.get_active_version(rule_id: "age_check")
      expect(active).not_to be_nil
      expect(active[:content]).to be_a(Hash)
      # Content may have string or symbol keys depending on storage adapter
      rules = active[:content]["rules"] || active[:content][:rules]
      expect(rules).to be_an(Array)

      # Get version history
      versions = version_manager.get_versions(rule_id: "age_check")
      expect(versions.size).to eq(1)
      expect(versions.first[:created_by]).to eq("test_user")
    end
  end
end
