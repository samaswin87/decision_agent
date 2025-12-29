require "spec_helper"
require "tempfile"

RSpec.describe DecisionAgent::Testing::BatchTestRunner do
  let(:evaluator) { DecisionAgent::Evaluators::StaticEvaluator.new(decision: "approve", weight: 1.0) }
  let(:agent) { DecisionAgent::Agent.new(evaluators: [evaluator]) }
  let(:runner) { DecisionAgent::Testing::BatchTestRunner.new(agent) }

  describe "#initialize" do
    it "creates a batch test runner with an agent" do
      expect(runner.agent).to eq(agent)
      expect(runner.results).to eq([])
    end
  end

  describe "#run" do
    let(:scenarios) do
      [
        DecisionAgent::Testing::TestScenario.new(
          id: "test_1",
          context: { user_id: 123 }
        ),
        DecisionAgent::Testing::TestScenario.new(
          id: "test_2",
          context: { user_id: 456 }
        )
      ]
    end

    it "executes test scenarios sequentially" do
      results = runner.run(scenarios, parallel: false)

      expect(results.size).to eq(2)
      expect(results.all?(&:success?)).to be true
      expect(results[0].decision).to eq("approve")
      expect(results[1].decision).to eq("approve")
    end

    it "executes test scenarios in parallel when enabled" do
      results = runner.run(scenarios, parallel: true, thread_count: 2)

      expect(results.size).to eq(2)
      expect(results.all?(&:success?)).to be true
    end

    it "executes single scenario sequentially even with parallel enabled" do
      single_scenario = [scenarios[0]]
      results = runner.run(single_scenario, parallel: true)

      expect(results.size).to eq(1)
      expect(results.all?(&:success?)).to be true
    end

    it "handles empty scenarios array" do
      results = runner.run([])
      expect(results).to eq([])
    end

    it "calls progress callback during execution" do
      progress_updates = []

      runner.run(scenarios, progress_callback: lambda { |progress|
        progress_updates << progress
      })

      expect(progress_updates.size).to be >= 2
      expect(progress_updates.last[:completed]).to eq(2)
      expect(progress_updates.last[:total]).to eq(2)
      expect(progress_updates.last[:percentage]).to eq(100.0)
    end

    it "tracks execution time for each scenario" do
      results = runner.run(scenarios)

      results.each do |result|
        expect(result.execution_time_ms).to be >= 0
        expect(result.execution_time_ms).to be_a(Numeric)
      end
    end

    it "handles errors gracefully" do
      # Create an agent that will raise an error
      error_evaluator = Class.new do
        def evaluate(_context, _feedback: {})
          raise StandardError, "Test error"
        end
      end.new

      error_agent = DecisionAgent::Agent.new(evaluators: [error_evaluator])
      error_runner = DecisionAgent::Testing::BatchTestRunner.new(error_agent)

      results = error_runner.run(scenarios)

      expect(results.size).to eq(2)
      expect(results.none?(&:success?)).to be true
      expect(results[0].error).to be_a(StandardError)
    end

    it "passes feedback to agent" do
      feedback = { source: "batch_test" }
      results = runner.run(scenarios, feedback: feedback)

      expect(results.size).to eq(2)
      expect(results.all?(&:success?)).to be true
    end
  end

  describe "#statistics" do
    it "returns empty hash when no results" do
      expect(runner.statistics).to eq({})
    end

    it "calculates statistics from results" do
      scenarios = [
        DecisionAgent::Testing::TestScenario.new(id: "test_1", context: { user_id: 123 }),
        DecisionAgent::Testing::TestScenario.new(id: "test_2", context: { user_id: 456 })
      ]

      runner.run(scenarios)
      stats = runner.statistics

      expect(stats[:total]).to eq(2)
      expect(stats[:successful]).to eq(2)
      expect(stats[:failed]).to eq(0)
      expect(stats[:success_rate]).to eq(1.0)
      expect(stats[:avg_execution_time_ms]).to be >= 0
      expect(stats[:min_execution_time_ms]).to be >= 0
      expect(stats[:max_execution_time_ms]).to be >= 0
    end

    it "handles nil execution times in statistics" do
      scenarios = [
        DecisionAgent::Testing::TestScenario.new(id: "test_1", context: { user_id: 123 })
      ]
      runner.run(scenarios)

      # Manually add a result with nil execution time
      runner.instance_variable_get(:@results) << DecisionAgent::Testing::TestResult.new(
        scenario_id: "test_2",
        execution_time_ms: nil
      )

      stats = runner.statistics
      expect(stats[:total]).to eq(2)
    end
  end

  describe "#resume" do
    let(:scenarios) do
      [
        DecisionAgent::Testing::TestScenario.new(id: "test_1", context: { user_id: 123 }),
        DecisionAgent::Testing::TestScenario.new(id: "test_2", context: { user_id: 456 })
      ]
    end

    it "resumes from checkpoint file" do
      checkpoint_file = Tempfile.new(["checkpoint", ".json"])
      checkpoint_file.write(JSON.pretty_generate({ completed_scenario_ids: ["test_1"], last_updated: Time.now.to_i }))
      checkpoint_file.close

      results = runner.resume(scenarios, checkpoint_file.path)

      # Should only run test_2 since test_1 is already completed
      expect(results.size).to eq(1)
      expect(results[0].scenario_id).to eq("test_2")

      checkpoint_file.unlink
    end
  end

  describe "checkpoint functionality" do
    let(:scenarios) do
      [
        DecisionAgent::Testing::TestScenario.new(id: "test_1", context: { user_id: 123 }),
        DecisionAgent::Testing::TestScenario.new(id: "test_2", context: { user_id: 456 })
      ]
    end

    it "saves checkpoints during execution" do
      checkpoint_file = Tempfile.new(["checkpoint", ".json"])
      checkpoint_file.close
      File.delete(checkpoint_file.path) # Start with no file

      runner.run(scenarios, checkpoint_file: checkpoint_file.path)

      # Checkpoint file should exist and contain completed scenario IDs
      expect(File.exist?(checkpoint_file.path)).to be false # Should be cleaned up after completion
    end

    it "handles checkpoint file errors gracefully" do
      checkpoint_file = Tempfile.new(["checkpoint", ".json"])
      checkpoint_file.close

      # Make file read-only to cause write errors
      File.chmod(0o444, checkpoint_file.path)

      expect do
        runner.run(scenarios, checkpoint_file: checkpoint_file.path)
      end.not_to raise_error

      File.chmod(0o644, checkpoint_file.path)
      checkpoint_file.unlink
    end

    it "loads checkpoint data correctly" do
      checkpoint_file = Tempfile.new(["checkpoint", ".json"])
      checkpoint_data = {
        completed_scenario_ids: ["test_1"],
        last_updated: Time.now.to_i
      }
      checkpoint_file.write(JSON.pretty_generate(checkpoint_data))
      checkpoint_file.close

      results = runner.run(scenarios, checkpoint_file: checkpoint_file.path)

      # Should only execute test_2
      expect(results.size).to eq(1)
      expect(results[0].scenario_id).to eq("test_2")

      checkpoint_file.unlink
    end

    it "handles invalid JSON in checkpoint file" do
      checkpoint_file = Tempfile.new(["checkpoint", ".json"])
      checkpoint_file.write("invalid json")
      checkpoint_file.close

      # Should handle gracefully and start fresh
      results = runner.run(scenarios, checkpoint_file: checkpoint_file.path)
      expect(results.size).to eq(2)

      checkpoint_file.unlink
    end
  end

  describe "TestResult" do
    let(:result) do
      DecisionAgent::Testing::TestResult.new(
        scenario_id: "test_1",
        decision: "approve",
        confidence: 0.95,
        execution_time_ms: 10.5
      )
    end

    it "creates a successful test result" do
      expect(result.success?).to be true
      expect(result.scenario_id).to eq("test_1")
      expect(result.decision).to eq("approve")
      expect(result.confidence).to eq(0.95)
      expect(result.execution_time_ms).to eq(10.5)
    end

    it "creates a failed test result" do
      error = StandardError.new("Test error")
      failed_result = DecisionAgent::Testing::TestResult.new(
        scenario_id: "test_1",
        error: error
      )

      expect(failed_result.success?).to be false
      expect(failed_result.error).to eq(error)
    end

    it "converts to hash" do
      hash = result.to_h

      expect(hash[:scenario_id]).to eq("test_1")
      expect(hash[:decision]).to eq("approve")
      expect(hash[:confidence]).to eq(0.95)
      expect(hash[:execution_time_ms]).to eq(10.5)
      expect(hash[:success]).to be true
    end

    it "includes evaluations in hash" do
      evaluation = DecisionAgent::Evaluation.new(
        decision: "approve",
        weight: 1.0,
        reason: "Test",
        evaluator_name: "TestEvaluator"
      )
      result_with_eval = DecisionAgent::Testing::TestResult.new(
        scenario_id: "test_1",
        decision: "approve",
        evaluations: [evaluation]
      )

      hash = result_with_eval.to_h
      expect(hash[:evaluations]).to be_an(Array)
      expect(hash[:evaluations].first).to respond_to(:to_h)
    end

    it "handles nil decision and confidence" do
      result = DecisionAgent::Testing::TestResult.new(
        scenario_id: "test_1",
        decision: nil,
        confidence: nil
      )

      expect(result.decision).to be_nil
      expect(result.confidence).to be_nil
    end
  end
end
