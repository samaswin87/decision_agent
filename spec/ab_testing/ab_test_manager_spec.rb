require "spec_helper"
require "decision_agent/ab_testing/ab_test_manager"
require "decision_agent/ab_testing/storage/memory_adapter"
require "decision_agent/versioning/file_storage_adapter"

RSpec.describe DecisionAgent::ABTesting::ABTestManager do
  let(:version_manager) do
    DecisionAgent::Versioning::VersionManager.new(
      adapter: DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: "/tmp/spec_ab_test_versions")
    )
  end

  let(:storage_adapter) { DecisionAgent::ABTesting::Storage::MemoryAdapter.new }
  let(:manager) { described_class.new(storage_adapter: storage_adapter, version_manager: version_manager) }

  before do
    # Create test versions
    @champion = version_manager.save_version(
      rule_id: "test_rule",
      rule_content: { rules: [{ decision: "approve", weight: 1.0 }] },
      created_by: "spec"
    )

    @challenger = version_manager.save_version(
      rule_id: "test_rule",
      rule_content: { rules: [{ decision: "reject", weight: 1.0 }] },
      created_by: "spec"
    )
  end

  after do
    FileUtils.rm_rf("/tmp/spec_ab_test_versions")
  end

  describe "#create_test" do
    it "creates a new A/B test" do
      test = manager.create_test(
        name: "Test A vs B",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id]
      )

      expect(test).to be_a(DecisionAgent::ABTesting::ABTest)
      expect(test.name).to eq("Test A vs B")
      expect(test.id).not_to be_nil
    end

    it "validates that champion version exists" do
      expect do
        manager.create_test(
          name: "Test",
          champion_version_id: "nonexistent",
          challenger_version_id: @challenger[:id]
        )
      end.to raise_error(DecisionAgent::ABTesting::VersionNotFoundError, /Champion/)
    end

    it "validates that challenger version exists" do
      expect do
        manager.create_test(
          name: "Test",
          champion_version_id: @champion[:id],
          challenger_version_id: "nonexistent"
        )
      end.to raise_error(DecisionAgent::ABTesting::VersionNotFoundError, /Challenger/)
    end

    it "accepts custom traffic split" do
      test = manager.create_test(
        name: "Custom Split",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id],
        traffic_split: { champion: 70, challenger: 30 }
      )

      expect(test.traffic_split).to eq({ champion: 70, challenger: 30 })
    end
  end

  describe "#get_test" do
    it "retrieves a test by ID" do
      created_test = manager.create_test(
        name: "Test",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id]
      )

      retrieved_test = manager.get_test(created_test.id)

      expect(retrieved_test).not_to be_nil
      expect(retrieved_test.id).to eq(created_test.id)
      expect(retrieved_test.name).to eq("Test")
    end

    it "returns nil for nonexistent test" do
      test = manager.get_test(99999)
      expect(test).to be_nil
    end
  end

  describe "#assign_variant" do
    let(:test) do
      manager.create_test(
        name: "Test",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id],
        start_date: Time.now.utc + 3600
      )
    end

    before do
      manager.start_test(test.id)
    end

    it "assigns a variant and returns assignment details" do
      assignment = manager.assign_variant(test_id: test.id, user_id: "user_123")

      expect(assignment[:test_id]).to eq(test.id)
      expect([:champion, :challenger]).to include(assignment[:variant])
      expect([@champion[:id], @challenger[:id]]).to include(assignment[:version_id])
      expect(assignment[:assignment_id]).not_to be_nil
    end

    it "assigns same variant to same user" do
      user_id = "consistent_user"
      assignment1 = manager.assign_variant(test_id: test.id, user_id: user_id)
      assignment2 = manager.assign_variant(test_id: test.id, user_id: user_id)

      expect(assignment1[:variant]).to eq(assignment2[:variant])
    end

    it "raises error for nonexistent test" do
      expect do
        manager.assign_variant(test_id: 99999)
      end.to raise_error(DecisionAgent::ABTesting::TestNotFoundError)
    end
  end

  describe "#record_decision" do
    let(:test) do
      test = manager.create_test(
        name: "Test",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id],
        start_date: Time.now.utc + 3600
      )
      manager.start_test(test.id)
      test
    end

    it "records decision result for an assignment" do
      assignment = manager.assign_variant(test_id: test.id)

      expect do
        manager.record_decision(
          assignment_id: assignment[:assignment_id],
          decision: "approve",
          confidence: 0.95
        )
      end.not_to raise_error
    end
  end

  describe "#get_results" do
    let(:test) do
      test = manager.create_test(
        name: "Test",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id],
        start_date: Time.now.utc + 3600
      )
      manager.start_test(test.id)
      test
    end

    it "returns results with statistics" do
      # Create some assignments and record decisions
      10.times do |i|
        assignment = manager.assign_variant(test_id: test.id, user_id: "user_#{i}")
        manager.record_decision(
          assignment_id: assignment[:assignment_id],
          decision: "approve",
          confidence: 0.8 + (rand * 0.2)
        )
      end

      results = manager.get_results(test.id)

      expect(results[:test]).to be_a(Hash)
      expect(results[:champion]).to be_a(Hash)
      expect(results[:challenger]).to be_a(Hash)
      expect(results[:comparison]).to be_a(Hash)
      expect(results[:total_assignments]).to eq(10)
    end

    it "handles tests with no assignments" do
      results = manager.get_results(test.id)

      expect(results[:total_assignments]).to eq(0)
      expect(results[:champion][:decisions_recorded]).to eq(0)
      expect(results[:challenger][:decisions_recorded]).to eq(0)
    end
  end

  describe "#active_tests" do
    it "returns only running tests" do
      test1 = manager.create_test(
        name: "Running Test",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id],
        start_date: Time.now.utc + 3600
      )
      manager.start_test(test1.id)

      test2 = manager.create_test(
        name: "Scheduled Test",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id],
        start_date: Time.now.utc + 3600
      )

      active = manager.active_tests

      expect(active.size).to eq(1)
      expect(active.first.id).to eq(test1.id)
    end

    it "caches active tests for performance" do
      test = manager.create_test(
        name: "Test",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id],
        start_date: Time.now.utc + 3600
      )
      manager.start_test(test.id)

      # First call
      manager.active_tests

      # Expect storage adapter not to be called again (cached)
      expect(storage_adapter).not_to receive(:list_tests)
      manager.active_tests
    end
  end

  describe "test lifecycle" do
    let(:test) do
      manager.create_test(
        name: "Test",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id],
        start_date: Time.now.utc + 3600
      )
    end

    it "starts a scheduled test" do
      manager.start_test(test.id)
      updated_test = manager.get_test(test.id)

      expect(updated_test.status).to eq("running")
    end

    it "completes a running test" do
      manager.start_test(test.id)
      manager.complete_test(test.id)
      updated_test = manager.get_test(test.id)

      expect(updated_test.status).to eq("completed")
    end

    it "cancels a test" do
      manager.cancel_test(test.id)
      updated_test = manager.get_test(test.id)

      expect(updated_test.status).to eq("cancelled")
    end
  end

  describe "statistical analysis" do
    let(:test) do
      test = manager.create_test(
        name: "Statistical Test",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id],
        traffic_split: { champion: 50, challenger: 50 },
        start_date: Time.now.utc + 3600
      )
      manager.start_test(test.id)
      test
    end

    it "calculates improvement percentage" do
      # Create assignments with different confidence levels
      50.times do |i|
        assignment = manager.assign_variant(test_id: test.id, user_id: "user_#{i}")

        # Champion: avg 0.7, Challenger: avg 0.9
        confidence = assignment[:variant] == :champion ? 0.7 : 0.9

        manager.record_decision(
          assignment_id: assignment[:assignment_id],
          decision: "approve",
          confidence: confidence
        )
      end

      results = manager.get_results(test.id)

      # Challenger should have higher avg confidence (0.9 vs 0.7)
      expect(results[:comparison][:improvement_percentage]).to be > 0
      expect(%w[champion challenger inconclusive]).to include(results[:comparison][:winner])
    end

    it "indicates insufficient data when sample is too small" do
      # Create only a few assignments
      5.times do |i|
        assignment = manager.assign_variant(test_id: test.id, user_id: "user_#{i}")
        manager.record_decision(
          assignment_id: assignment[:assignment_id],
          decision: "approve",
          confidence: 0.8
        )
      end

      results = manager.get_results(test.id)

      expect(results[:comparison][:statistical_significance]).to eq("not_significant")
    end
  end
end
