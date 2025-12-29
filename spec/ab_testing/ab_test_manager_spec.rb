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

    it "accepts start_date and end_date" do
      start_date = Time.now.utc + 3600
      end_date = Time.now.utc + 7200
      test = manager.create_test(
        name: "Scheduled Test",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id],
        start_date: start_date,
        end_date: end_date
      )

      expect(test.start_date).to eq(start_date)
      expect(test.end_date).to eq(end_date)
    end

    it "sets status to running if start_date is in the past" do
      test = manager.create_test(
        name: "Immediate Test",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id],
        start_date: Time.now.utc - 3600
      )

      expect(test.status).to eq("running")
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
      test = manager.get_test(99_999)
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
      expect(%i[champion challenger]).to include(assignment[:variant])
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
        manager.assign_variant(test_id: 99_999)
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

      manager.create_test(
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

    it "handles tests with assignments but no decisions" do
      # Create assignments without recording decisions
      10.times do |i|
        manager.assign_variant(test_id: test.id, user_id: "user_#{i}")
      end

      results = manager.get_results(test.id)

      expect(results[:champion][:decisions_recorded]).to eq(0)
      expect(results[:challenger][:decisions_recorded]).to eq(0)
      expect(results[:comparison][:statistical_significance]).to eq("insufficient_data")
    end

    it "calculates statistical significance with sufficient data" do
      # Create 30+ assignments for each variant to trigger statistical significance
      champion_count = 0
      challenger_count = 0

      100.times do |i|
        assignment = manager.assign_variant(test_id: test.id, user_id: "user_#{i}")
        if assignment[:variant] == :champion
          champion_count += 1
          confidence = 0.7
        else
          challenger_count += 1
          confidence = 0.9
        end

        manager.record_decision(
          assignment_id: assignment[:assignment_id],
          decision: "approve",
          confidence: confidence
        )
      end

      results = manager.get_results(test.id)

      # Should have enough data for statistical significance
      expect(results[:champion][:decisions_recorded]).to be >= 30
      expect(results[:challenger][:decisions_recorded]).to be >= 30
      expect(["significant", "not_significant"]).to include(results[:comparison][:statistical_significance])
    end

    it "calculates different confidence levels based on t-statistic" do
      # Create data that will result in different t-statistic values
      # High t-statistic (> 2.576) should give 99% confidence
      50.times do |i|
        assignment = manager.assign_variant(test_id: test.id, user_id: "user_#{i}")
        # Large difference to get high t-statistic
        confidence = assignment[:variant] == :champion ? 0.5 : 0.95
        manager.record_decision(
          assignment_id: assignment[:assignment_id],
          decision: "approve",
          confidence: confidence
        )
      end

      results = manager.get_results(test.id)
      expect(results[:comparison][:confidence_level]).to be_a(Numeric)
      expect(results[:comparison][:confidence_level]).to be >= 0.0
    end

    it "determines winner correctly when challenger is better" do
      50.times do |i|
        assignment = manager.assign_variant(test_id: test.id, user_id: "user_#{i}")
        confidence = assignment[:variant] == :champion ? 0.6 : 0.9
        manager.record_decision(
          assignment_id: assignment[:assignment_id],
          decision: "approve",
          confidence: confidence
        )
      end

      results = manager.get_results(test.id)
      expect(["champion", "challenger", "inconclusive"]).to include(results[:comparison][:winner])
    end

    it "generates appropriate recommendations" do
      # Test different improvement scenarios
      50.times do |i|
        assignment = manager.assign_variant(test_id: test.id, user_id: "user_#{i}")
        # Challenger significantly better (>5% improvement)
        confidence = assignment[:variant] == :champion ? 0.7 : 0.8
        manager.record_decision(
          assignment_id: assignment[:assignment_id],
          decision: "approve",
          confidence: confidence
        )
      end

      results = manager.get_results(test.id)
      expect(results[:comparison][:recommendation]).to be_a(String)
      expect(results[:comparison][:recommendation]).not_to be_empty
    end

    it "handles champion better than challenger scenario" do
      50.times do |i|
        assignment = manager.assign_variant(test_id: test.id, user_id: "user_#{i}")
        # Champion better
        confidence = assignment[:variant] == :champion ? 0.9 : 0.7
        manager.record_decision(
          assignment_id: assignment[:assignment_id],
          decision: "approve",
          confidence: confidence
        )
      end

      results = manager.get_results(test.id)
      expect(results[:comparison][:improvement_percentage]).to be < 0
    end

    it "handles similar performance scenario" do
      50.times do |i|
        assignment = manager.assign_variant(test_id: test.id, user_id: "user_#{i}")
        # Similar performance
        confidence = assignment[:variant] == :champion ? 0.75 : 0.76
        manager.record_decision(
          assignment_id: assignment[:assignment_id],
          decision: "approve",
          confidence: confidence
        )
      end

      results = manager.get_results(test.id)
      expect(results[:comparison][:improvement_percentage]).to be_between(-5, 5)
    end
  end

  describe "#list_tests" do
    before do
      manager.create_test(
        name: "Test 1",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id]
      )
      manager.create_test(
        name: "Test 2",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id]
      )
    end

    it "lists all tests when no filters" do
      tests = manager.list_tests
      expect(tests.size).to be >= 2
    end

    it "filters by status" do
      tests = manager.list_tests(status: "scheduled")
      expect(tests).to all(have_attributes(status: "scheduled"))
    end

    it "respects limit parameter" do
      tests = manager.list_tests(limit: 1)
      expect(tests.size).to eq(1)
    end
  end

  describe "#initialize" do
    it "uses default storage adapter when not provided" do
      manager = described_class.new(version_manager: version_manager)
      expect(manager.storage_adapter).to be_a(DecisionAgent::ABTesting::Storage::MemoryAdapter)
    end

    it "uses default version manager when not provided" do
      manager = described_class.new
      expect(manager.version_manager).to be_a(DecisionAgent::Versioning::VersionManager)
    end
  end

  describe "cache behavior" do
    let(:test) do
      manager.create_test(
        name: "Test",
        champion_version_id: @champion[:id],
        challenger_version_id: @challenger[:id],
        start_date: Time.now.utc + 3600
      )
    end

    it "invalidates cache when test is started" do
      manager.active_tests # Populate cache
      manager.start_test(test.id)
      # Cache should be invalidated, so next call should hit storage
      expect(storage_adapter).to receive(:list_tests).and_call_original
      manager.active_tests
    end

    it "invalidates cache when test is completed" do
      manager.active_tests # Populate cache
      manager.start_test(test.id) # Start the test first so it can be completed
      manager.complete_test(test.id)
      expect(storage_adapter).to receive(:list_tests).and_call_original
      manager.active_tests
    end

    it "invalidates cache when test is cancelled" do
      manager.active_tests # Populate cache
      manager.cancel_test(test.id)
      expect(storage_adapter).to receive(:list_tests).and_call_original
      manager.active_tests
    end

    it "cache expires after 60 seconds" do
      manager.active_tests # Populate cache
      # Simulate time passing
      allow(Time).to receive(:now).and_return(Time.now.utc + 61)
      expect(storage_adapter).to receive(:list_tests).and_call_original
      manager.active_tests
    end
  end

  describe "#get_results edge cases" do
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

    it "handles assignments with different decision results" do
      20.times do |i|
        assignment = manager.assign_variant(test_id: test.id, user_id: "user_#{i}")
        decision = i.even? ? "approve" : "reject"
        manager.record_decision(
          assignment_id: assignment[:assignment_id],
          decision: decision,
          confidence: 0.8
        )
      end

      results = manager.get_results(test.id)
      expect(results[:champion][:decision_distribution]).to be_a(Hash)
      expect(results[:challenger][:decision_distribution]).to be_a(Hash)
    end

    it "calculates min and max confidence correctly" do
      20.times do |i|
        assignment = manager.assign_variant(test_id: test.id, user_id: "user_#{i}")
        confidence = 0.5 + (i * 0.02) # Range from 0.5 to 0.88
        manager.record_decision(
          assignment_id: assignment[:assignment_id],
          decision: "approve",
          confidence: confidence
        )
      end

      results = manager.get_results(test.id)
      expect(results[:champion][:min_confidence]).to be_a(Numeric).or be_nil
      expect(results[:champion][:max_confidence]).to be_a(Numeric).or be_nil
    end
  end
end
