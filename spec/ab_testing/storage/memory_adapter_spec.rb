require "spec_helper"
require "decision_agent/ab_testing/storage/memory_adapter"
require "decision_agent/ab_testing/ab_test"
require "decision_agent/ab_testing/ab_test_assignment"

RSpec.describe DecisionAgent::ABTesting::Storage::MemoryAdapter do
  let(:adapter) { described_class.new }

  describe "#initialize" do
    it "initializes with empty storage" do
      expect(adapter.test_count).to eq(0)
      expect(adapter.assignment_count).to eq(0)
    end
  end

  describe "#save_test" do
    it "saves a test and assigns an ID" do
      test = DecisionAgent::ABTesting::ABTest.new(
        name: "Test 1",
        champion_version_id: "v1",
        challenger_version_id: "v2"
      )

      saved = adapter.save_test(test)
      expect(saved.id).to eq(1)
      expect(saved.name).to eq("Test 1")
    end

    it "increments the test counter" do
      test1 = DecisionAgent::ABTesting::ABTest.new(
        name: "Test 1",
        champion_version_id: "v1",
        challenger_version_id: "v2"
      )
      test2 = DecisionAgent::ABTesting::ABTest.new(
        name: "Test 2",
        champion_version_id: "v1",
        challenger_version_id: "v2"
      )

      adapter.save_test(test1)
      adapter.save_test(test2)

      expect(adapter.test_count).to eq(2)
    end
  end

  describe "#get_test" do
    it "returns nil for non-existent test" do
      expect(adapter.get_test(999)).to be_nil
    end

    it "returns the saved test" do
      test = DecisionAgent::ABTesting::ABTest.new(
        name: "Test 1",
        champion_version_id: "v1",
        challenger_version_id: "v2"
      )
      saved = adapter.save_test(test)

      retrieved = adapter.get_test(saved.id)
      expect(retrieved).to be_a(DecisionAgent::ABTesting::ABTest)
      expect(retrieved.id).to eq(saved.id)
      expect(retrieved.name).to eq("Test 1")
    end

    it "converts string IDs to integers" do
      test = DecisionAgent::ABTesting::ABTest.new(
        name: "Test 1",
        champion_version_id: "v1",
        challenger_version_id: "v2"
      )
      saved = adapter.save_test(test)

      retrieved = adapter.get_test(saved.id.to_s)
      expect(retrieved).not_to be_nil
      expect(retrieved.id).to eq(saved.id)
    end
  end

  describe "#update_test" do
    let(:saved_test) do
      test = DecisionAgent::ABTesting::ABTest.new(
        name: "Original Name",
        champion_version_id: "v1",
        challenger_version_id: "v2",
        status: "scheduled"
      )
      adapter.save_test(test)
    end

    it "updates test attributes" do
      updated = adapter.update_test(saved_test.id, { status: "running" })
      expect(updated.status).to eq("running")
      expect(updated.name).to eq("Original Name") # Other attributes unchanged
    end

    it "raises error when test not found" do
      expect do
        adapter.update_test(999, { status: "running" })
      end.to raise_error(DecisionAgent::ABTesting::TestNotFoundError, /Test not found: 999/)
    end

    it "persists the update" do
      adapter.update_test(saved_test.id, { status: "running" })
      retrieved = adapter.get_test(saved_test.id)
      expect(retrieved.status).to eq("running")
    end
  end

  describe "#list_tests" do
    before do
      adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                          name: "Scheduled Test",
                          champion_version_id: "v1",
                          challenger_version_id: "v2",
                          status: "scheduled"
                        ))
      adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                          name: "Running Test",
                          champion_version_id: "v1",
                          challenger_version_id: "v2",
                          status: "running"
                        ))
      adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                          name: "Another Running",
                          champion_version_id: "v1",
                          challenger_version_id: "v2",
                          status: "running"
                        ))
    end

    it "returns all tests when no filters" do
      tests = adapter.list_tests
      expect(tests.size).to eq(3)
    end

    it "filters by status" do
      tests = adapter.list_tests(status: "running")
      expect(tests.size).to eq(2)
      expect(tests.all? { |t| t.status == "running" }).to be true
    end

    it "returns empty array when no tests match status" do
      tests = adapter.list_tests(status: "completed")
      expect(tests).to eq([])
    end

    it "respects limit parameter" do
      tests = adapter.list_tests(limit: 2)
      expect(tests.size).to eq(2)
    end

    it "returns last N tests when limit specified" do
      tests = adapter.list_tests(limit: 2)
      # Should return the last 2 tests (most recently added)
      expect(tests.map(&:name)).to include("Running Test", "Another Running")
    end

    it "filters by status and limit together" do
      tests = adapter.list_tests(status: "running", limit: 1)
      expect(tests.size).to eq(1)
      expect(tests.first.status).to eq("running")
    end
  end

  describe "#save_assignment" do
    it "saves an assignment and assigns an ID" do
      assignment = DecisionAgent::ABTesting::ABTestAssignment.new(
        ab_test_id: 1,
        variant: :champion,
        version_id: "v1"
      )

      saved = adapter.save_assignment(assignment)
      expect(saved.id).to eq(1)
      expect(saved.ab_test_id).to eq(1)
      expect(saved.variant).to eq(:champion)
    end

    it "increments the assignment counter" do
      assignment1 = DecisionAgent::ABTesting::ABTestAssignment.new(
        ab_test_id: 1,
        variant: :champion,
        version_id: "v1"
      )
      assignment2 = DecisionAgent::ABTesting::ABTestAssignment.new(
        ab_test_id: 1,
        variant: :challenger,
        version_id: "v2"
      )

      adapter.save_assignment(assignment1)
      adapter.save_assignment(assignment2)

      expect(adapter.assignment_count).to eq(2)
    end
  end

  describe "#update_assignment" do
    let(:saved_assignment) do
      assignment = DecisionAgent::ABTesting::ABTestAssignment.new(
        ab_test_id: 1,
        variant: :champion,
        version_id: "v1"
      )
      adapter.save_assignment(assignment)
    end

    it "updates assignment attributes" do
      updated = adapter.update_assignment(saved_assignment.id, {
                                            decision_result: "approve",
                                            confidence: 0.85
                                          })
      expect(updated.decision_result).to eq("approve")
      expect(updated.confidence).to eq(0.85)
    end

    it "raises error when assignment not found" do
      expect do
        adapter.update_assignment(999, { decision_result: "approve" })
      end.to raise_error(StandardError, /Assignment not found: 999/)
    end

    it "persists the update" do
      adapter.update_assignment(saved_assignment.id, { decision_result: "reject" })
      # Get via get_assignments to verify persistence
      assignments = adapter.get_assignments(1)
      updated = assignments.find { |a| a.id == saved_assignment.id }
      expect(updated.decision_result).to eq("reject")
    end
  end

  describe "#get_assignments" do
    before do
      test1 = adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                                  name: "Test 1",
                                  champion_version_id: "v1",
                                  challenger_version_id: "v2"
                                ))
      test2 = adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                                  name: "Test 2",
                                  champion_version_id: "v1",
                                  challenger_version_id: "v2"
                                ))

      adapter.save_assignment(DecisionAgent::ABTesting::ABTestAssignment.new(
                                ab_test_id: test1.id,
                                variant: :champion,
                                version_id: "v1"
                              ))
      adapter.save_assignment(DecisionAgent::ABTesting::ABTestAssignment.new(
                                ab_test_id: test1.id,
                                variant: :challenger,
                                version_id: "v2"
                              ))
      adapter.save_assignment(DecisionAgent::ABTesting::ABTestAssignment.new(
                                ab_test_id: test2.id,
                                variant: :champion,
                                version_id: "v1"
                              ))
    end

    it "returns assignments for a specific test" do
      assignments = adapter.get_assignments(1)
      expect(assignments.size).to eq(2)
      expect(assignments.all? { |a| a.ab_test_id == 1 }).to be true
    end

    it "returns empty array when no assignments for test" do
      assignments = adapter.get_assignments(999)
      expect(assignments).to eq([])
    end
  end

  describe "#delete_test" do
    let(:test) do
      adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                          name: "Test 1",
                          champion_version_id: "v1",
                          challenger_version_id: "v2"
                        ))
    end

    before do
      adapter.save_assignment(DecisionAgent::ABTesting::ABTestAssignment.new(
                                ab_test_id: test.id,
                                variant: :champion,
                                version_id: "v1"
                              ))
      adapter.save_assignment(DecisionAgent::ABTesting::ABTestAssignment.new(
                                ab_test_id: test.id,
                                variant: :challenger,
                                version_id: "v2"
                              ))
      # Assignment for another test
      other_test = adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                                       name: "Test 2",
                                       champion_version_id: "v1",
                                       challenger_version_id: "v2"
                                     ))
      adapter.save_assignment(DecisionAgent::ABTesting::ABTestAssignment.new(
                                ab_test_id: other_test.id,
                                variant: :champion,
                                version_id: "v1"
                              ))
    end

    it "deletes the test" do
      expect(adapter.get_test(test.id)).not_to be_nil
      adapter.delete_test(test.id)
      expect(adapter.get_test(test.id)).to be_nil
    end

    it "deletes all assignments for the test" do
      expect(adapter.get_assignments(test.id).size).to eq(2)
      adapter.delete_test(test.id)
      expect(adapter.get_assignments(test.id).size).to eq(0)
    end

    it "does not delete assignments for other tests" do
      other_assignments_count = adapter.assignment_count - adapter.get_assignments(test.id).size
      adapter.delete_test(test.id)
      expect(adapter.assignment_count).to eq(other_assignments_count)
    end

    it "returns true" do
      result = adapter.delete_test(test.id)
      expect(result).to be true
    end

    it "converts string IDs to integers" do
      adapter.delete_test(test.id.to_s)
      expect(adapter.get_test(test.id)).to be_nil
    end
  end

  describe "#clear!" do
    before do
      adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                          name: "Test 1",
                          champion_version_id: "v1",
                          challenger_version_id: "v2"
                        ))
      adapter.save_assignment(DecisionAgent::ABTesting::ABTestAssignment.new(
                                ab_test_id: 1,
                                variant: :champion,
                                version_id: "v1"
                              ))
    end

    it "clears all tests" do
      expect(adapter.test_count).to eq(1)
      adapter.clear!
      expect(adapter.test_count).to eq(0)
    end

    it "clears all assignments" do
      expect(adapter.assignment_count).to eq(1)
      adapter.clear!
      expect(adapter.assignment_count).to eq(0)
    end

    it "resets test counter" do
      adapter.clear!
      test = adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                                 name: "New Test",
                                 champion_version_id: "v1",
                                 challenger_version_id: "v2"
                               ))
      expect(test.id).to eq(1)
    end

    it "resets assignment counter" do
      adapter.clear!
      assignment = adapter.save_assignment(DecisionAgent::ABTesting::ABTestAssignment.new(
                                             ab_test_id: 1,
                                             variant: :champion,
                                             version_id: "v1"
                                           ))
      expect(assignment.id).to eq(1)
    end
  end

  describe "#test_count" do
    it "returns zero initially" do
      expect(adapter.test_count).to eq(0)
    end

    it "returns correct count after saving tests" do
      adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                          name: "Test 1",
                          champion_version_id: "v1",
                          challenger_version_id: "v2"
                        ))
      expect(adapter.test_count).to eq(1)

      adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                          name: "Test 2",
                          champion_version_id: "v1",
                          challenger_version_id: "v2"
                        ))
      expect(adapter.test_count).to eq(2)
    end

    it "reflects deletions" do
      test = adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                                 name: "Test 1",
                                 champion_version_id: "v1",
                                 challenger_version_id: "v2"
                               ))
      adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                          name: "Test 2",
                          champion_version_id: "v1",
                          challenger_version_id: "v2"
                        ))
      adapter.delete_test(test.id)
      expect(adapter.test_count).to eq(1)
    end
  end

  describe "#assignment_count" do
    it "returns zero initially" do
      expect(adapter.assignment_count).to eq(0)
    end

    it "returns correct count after saving assignments" do
      adapter.save_assignment(DecisionAgent::ABTesting::ABTestAssignment.new(
                                ab_test_id: 1,
                                variant: :champion,
                                version_id: "v1"
                              ))
      expect(adapter.assignment_count).to eq(1)

      adapter.save_assignment(DecisionAgent::ABTesting::ABTestAssignment.new(
                                ab_test_id: 1,
                                variant: :challenger,
                                version_id: "v2"
                              ))
      expect(adapter.assignment_count).to eq(2)
    end

    it "reflects deletions" do
      test = adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                                 name: "Test 1",
                                 champion_version_id: "v1",
                                 challenger_version_id: "v2"
                               ))
      adapter.save_assignment(DecisionAgent::ABTesting::ABTestAssignment.new(
                                ab_test_id: test.id,
                                variant: :champion,
                                version_id: "v1"
                              ))
      adapter.save_assignment(DecisionAgent::ABTesting::ABTestAssignment.new(
                                ab_test_id: test.id,
                                variant: :challenger,
                                version_id: "v2"
                              ))
      adapter.delete_test(test.id) # This deletes all assignments for the test
      expect(adapter.assignment_count).to eq(0)
    end
  end

  describe "thread safety" do
    it "handles concurrent access safely" do
      threads = []
      10.times do
        threads << Thread.new do
          10.times do
            test = adapter.save_test(DecisionAgent::ABTesting::ABTest.new(
                                       name: "Test",
                                       champion_version_id: "v1",
                                       challenger_version_id: "v2"
                                     ))
            adapter.get_test(test.id)
            adapter.list_tests
          end
        end
      end

      threads.each(&:join)
      expect(adapter.test_count).to eq(100)
    end
  end
end
