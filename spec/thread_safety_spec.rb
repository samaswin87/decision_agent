# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Thread-Safety" do
  describe "Agent with shared evaluators" do
    let(:rules_json) do
      {
        version: "1.0",
        ruleset: "approval_rules",
        rules: [
          {
            id: "approve_high",
            if: { field: "amount", op: "gt", value: 1000 },
            then: { decision: "approve", weight: 0.9, reason: "High value" }
          },
          {
            id: "reject_low",
            if: { field: "amount", op: "lte", value: 1000 },
            then: { decision: "reject", weight: 0.8, reason: "Low value" }
          }
        ]
      }
    end

    let(:evaluator) { DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules_json) }
    let(:agent) { DecisionAgent::Agent.new(evaluators: [evaluator]) }

    it "handles concurrent decisions from multiple threads safely" do
      threads = []
      results = Array.new(50)

      # Create 50 threads making concurrent decisions
      50.times do |i|
        threads << Thread.new do
          context = { amount: i.even? ? 1500 : 500 }
          results[i] = agent.decide(context: context)
        end
      end

      threads.each(&:join)

      # Verify all threads completed successfully
      expect(results.compact.size).to eq(50)

      # Verify results are correct and frozen
      results.each_with_index do |decision, i|
        expect(decision).to be_frozen
        expect(decision.decision).to be_frozen
        expect(decision.explanations).to be_frozen
        expect(decision.evaluations).to be_frozen
        expect(decision.audit_payload).to be_frozen

        # Verify correctness based on input
        if i.even?
          expect(decision.decision).to eq("approve")
        else
          expect(decision.decision).to eq("reject")
        end
      end
    end

    it "prevents modification of shared evaluator ruleset" do
      # Verify the ruleset is frozen
      expect(evaluator.instance_variable_get(:@ruleset)).to be_frozen

      # Attempt to modify should raise error
      expect do
        evaluator.instance_variable_get(:@ruleset)["rules"] << { id: "new_rule" }
      end.to raise_error(FrozenError)
    end

    it "prevents modification of evaluators array in Agent" do
      expect(agent.evaluators).to be_frozen

      expect do
        agent.evaluators << DecisionAgent::Evaluators::StaticEvaluator.new(decision: true, weight: 1.0)
      end.to raise_error(FrozenError)
    end
  end

  describe "Multiple agents sharing evaluators" do
    let(:evaluator) do
      DecisionAgent::Evaluators::JsonRuleEvaluator.new(
        rules_json: {
          version: "1.0",
          ruleset: "shared_rules",
          rules: [
            {
              id: "rule1",
              if: { field: "value", op: "eq", value: "yes" },
              then: { decision: "approve", weight: 1.0, reason: "Match" }
            }
          ]
        }
      )
    end

    it "allows multiple agents to safely share the same evaluator instance" do
      agent1 = DecisionAgent::Agent.new(evaluators: [evaluator])
      agent2 = DecisionAgent::Agent.new(evaluators: [evaluator])
      agent3 = DecisionAgent::Agent.new(evaluators: [evaluator])

      results = []
      mutex = Mutex.new

      # Each agent makes decisions in parallel
      threads = [agent1, agent2, agent3].map do |agent|
        Thread.new do
          10.times do
            decision = agent.decide(context: { value: "yes" })
            mutex.synchronize { results << decision }
          end
        end
      end

      threads.each(&:join)

      # All 30 decisions should succeed
      expect(results.size).to eq(30)
      results.each do |decision|
        expect(decision.decision).to eq("approve")
        expect(decision).to be_frozen
      end
    end
  end

  describe "Evaluation immutability" do
    it "ensures evaluations are deeply frozen" do
      evaluation = DecisionAgent::Evaluation.new(
        decision: "approve",
        weight: 0.8,
        reason: "Test reason",
        evaluator_name: "TestEvaluator",
        metadata: { key: "value" }
      )

      expect(evaluation).to be_frozen
      expect(evaluation.decision).to be_frozen
      expect(evaluation.reason).to be_frozen
      expect(evaluation.evaluator_name).to be_frozen
      expect(evaluation.metadata).to be_frozen
    end
  end

  describe "Decision immutability" do
    it "ensures decisions are deeply frozen" do
      evaluation = DecisionAgent::Evaluation.new(
        decision: "approve",
        weight: 1.0,
        reason: "Test",
        evaluator_name: "Test"
      )

      decision = DecisionAgent::Decision.new(
        decision: "approve",
        confidence: 0.95,
        explanations: ["Explanation 1"],
        evaluations: [evaluation],
        audit_payload: { timestamp: "2024-01-01" }
      )

      expect(decision).to be_frozen
      expect(decision.decision).to be_frozen
      expect(decision.explanations).to be_frozen
      expect(decision.evaluations).to be_frozen
      expect(decision.audit_payload).to be_frozen

      # Nested structures should also be frozen
      expect(decision.explanations.first).to be_frozen
      expect(decision.evaluations.first).to be_frozen
    end
  end

  describe "Context immutability" do
    it "freezes context data to prevent mutation" do
      context_data = { user: { id: 1, name: "Test" }, amount: 100 }
      context = DecisionAgent::Context.new(context_data)

      expect(context.to_h).to be_frozen
      expect(context.to_h[:user]).to be_frozen

      # Original data should not be affected
      expect(context_data).not_to be_frozen
    end
  end

  describe "Concurrent file storage operations" do
    let(:storage_path) { File.join(__dir__, "../tmp/thread_safety_test") }
    let(:adapter) { DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: storage_path) }

    before do
      FileUtils.rm_rf(storage_path)
    end

    after do
      FileUtils.rm_rf(storage_path)
    end

    it "handles concurrent version creation safely" do
      threads = []
      results = []
      mutex = Mutex.new

      # Create 10 versions concurrently
      10.times do |i|
        threads << Thread.new do
          version = adapter.create_version(
            rule_id: "concurrent_rule",
            content: { rule: "version_#{i}" },
            metadata: { created_by: "thread_#{i}" }
          )
          mutex.synchronize { results << version }
        end
      end

      threads.each(&:join)

      # All versions should be created successfully
      expect(results.size).to eq(10)

      # Version numbers should be unique and sequential
      version_numbers = results.map { |v| v[:version_number] }.sort
      expect(version_numbers).to eq((1..10).to_a)

      # Each thread created its version as active
      # Due to thread scheduling, all might be created as active initially
      # The last one written should be active in the file system
      final_active = adapter.get_active_version(rule_id: "concurrent_rule")
      expect(final_active).not_to be_nil
      expect(final_active[:status]).to eq("active")
    end

    it "handles concurrent read and write operations safely" do
      # Create initial version
      adapter.create_version(
        rule_id: "read_write_test",
        content: { rule: "initial" },
        metadata: { created_by: "setup" }
      )

      threads = []
      read_results = []
      write_results = []
      read_mutex = Mutex.new
      write_mutex = Mutex.new

      # Mix of read and write operations
      10.times do |i|
        threads << if i.even?
                     # Read operations
                     Thread.new do
                       versions = adapter.list_versions(rule_id: "read_write_test")
                       read_mutex.synchronize { read_results << versions }
                     end
                   else
                     # Write operations
                     Thread.new do
                       version = adapter.create_version(
                         rule_id: "read_write_test",
                         content: { rule: "version_#{i}" },
                         metadata: { created_by: "thread_#{i}" }
                       )
                       write_mutex.synchronize { write_results << version }
                     end
                   end
      end

      threads.each(&:join)

      # All operations should complete successfully
      expect(read_results.size).to eq(5)
      expect(write_results.size).to eq(5)

      # Reads should never return inconsistent data
      read_results.each do |versions|
        expect(versions).to be_an(Array)
        versions.each do |version|
          expect(version).to have_key(:id)
          expect(version).to have_key(:version_number)
          expect(version).to have_key(:status)
        end
      end
    end
  end

  describe "EvaluationValidator" do
    it "validates frozen evaluations" do
      evaluation = DecisionAgent::Evaluation.new(
        decision: "approve",
        weight: 0.8,
        reason: "Valid",
        evaluator_name: "TestEvaluator"
      )

      expect do
        DecisionAgent::EvaluationValidator.validate!(evaluation)
      end.not_to raise_error
    end

    it "raises error for unfrozen evaluations" do
      # NOTE: Evaluation objects are always frozen in their initializer.
      # To test the validator's frozen check, we need to create an unfrozen instance.
      # Using allocate allows us to bypass the initializer (which would freeze the object)
      # and manually set instance variables to create a valid but unfrozen evaluation.
      # This tests the edge case where an evaluation might not be frozen (though
      # this should never happen in practice with real Evaluation instances).
      evaluation = DecisionAgent::Evaluation.allocate
      evaluation.instance_variable_set(:@decision, "approve")
      evaluation.instance_variable_set(:@weight, 0.8)
      evaluation.instance_variable_set(:@reason, "Test")
      evaluation.instance_variable_set(:@evaluator_name, "TestEvaluator")

      # Verify it's not frozen (this is the condition we're testing)
      expect(evaluation).not_to be_frozen

      expect do
        DecisionAgent::EvaluationValidator.validate!(evaluation)
      end.to raise_error(DecisionAgent::EvaluationValidator::ValidationError, /must be frozen/)
    end

    it "validates arrays of evaluations" do
      evaluations = [
        DecisionAgent::Evaluation.new(
          decision: "approve",
          weight: 0.8,
          reason: "Valid 1",
          evaluator_name: "Evaluator1"
        ),
        DecisionAgent::Evaluation.new(
          decision: "reject",
          weight: 0.6,
          reason: "Valid 2",
          evaluator_name: "Evaluator2"
        )
      ]

      expect do
        DecisionAgent::EvaluationValidator.validate_all!(evaluations)
      end.not_to raise_error
    end
  end

  describe "Stress Testing & Extended Coverage" do
    let(:rules_json) do
      {
        version: "1.0",
        ruleset: "stress_test",
        rules: [
          {
            id: "rule1",
            if: { field: "value", op: "gt", value: 50 },
            then: { decision: "high", weight: 0.9, reason: "High value" }
          },
          {
            id: "rule2",
            if: { field: "value", op: "lte", value: 50 },
            then: { decision: "low", weight: 0.8, reason: "Low value" }
          }
        ]
      }
    end

    let(:evaluator) { DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules_json) }
    let(:agent) { DecisionAgent::Agent.new(evaluators: [evaluator]) }

    it "handles 100 threads making 100 decisions each (10,000 total)" do
      thread_count = 100
      decisions_per_thread = 100
      total_decisions = thread_count * decisions_per_thread
      results = []
      mutex = Mutex.new

      threads = thread_count.times.map do |thread_id|
        Thread.new do
          decisions_per_thread.times do |i|
            context = { value: ((thread_id * decisions_per_thread) + i) % 100 }
            decision = agent.decide(context: context)
            mutex.synchronize { results << decision }
          end
        end
      end

      threads.each(&:join)

      expect(results.size).to eq(total_decisions)
      expect(results).to all(be_frozen)
      expect(results.map(&:decision).uniq.sort).to eq(%w[high low])
    end

    it "handles rapid-fire decisions with deterministic results" do
      results = []

      1000.times do |i|
        decision = agent.decide(context: { value: i % 100 })
        results << decision
      end

      expect(results.size).to eq(1000)
      expect(results).to all(be_frozen)

      # Verify determinism - same input produces same output
      decision1 = agent.decide(context: { value: 75 })
      decision2 = agent.decide(context: { value: 75 })
      expect(decision1.decision).to eq(decision2.decision)
      expect(decision1.confidence).to eq(decision2.confidence)
    end

    it "handles concurrent decisions with complex nested contexts" do
      complex_contexts = 50.times.map do |i|
        {
          value: i,
          user: {
            id: i,
            profile: {
              age: 20 + (i % 50),
              score: 0.5 + ((i % 10) * 0.05)
            }
          },
          metadata: {
            tags: ["tag#{i % 5}", "tag#{i % 3}"],
            timestamps: [Time.now.to_i - i, Time.now.to_i]
          }
        }
      end

      results = []
      mutex = Mutex.new

      threads = complex_contexts.map do |context|
        Thread.new do
          decision = agent.decide(context: context)
          mutex.synchronize { results << decision }
        end
      end

      threads.each(&:join)

      expect(results.size).to eq(50)
      expect(results).to all(be_frozen)
      results.each do |decision|
        expect(decision.audit_payload).to be_frozen
        expect(decision.audit_payload[:context]).to be_frozen
      end
    end

    it "prevents race conditions when reading same frozen decision" do
      results = []
      mutex = Mutex.new
      decision = agent.decide(context: { value: 0 })

      # Multiple threads reading the same frozen decision
      threads = 100.times.map do
        Thread.new do
          # These reads should be safe because decision is frozen
          data = {
            decision: decision.decision,
            confidence: decision.confidence,
            evaluations_count: decision.evaluations.size
          }
          mutex.synchronize { results << data }
        end
      end

      threads.each(&:join)

      expect(results.size).to eq(100)
      # All threads should see the same values
      expect(results.map { |r| r[:decision] }.uniq).to eq(["low"])
      expect(results.map { |r| r[:evaluations_count] }.uniq).to eq([1])
    end

    it "ensures original context data is not mutated" do
      original_context = { value: 75, count: 0 }
      original_context_copy = original_context.dup

      threads = 20.times.map do
        Thread.new do
          agent.decide(context: original_context)
        end
      end

      threads.each(&:join)

      # Original context should be unchanged
      expect(original_context).to eq(original_context_copy)
      expect(original_context).not_to be_frozen
    end
  end
end
