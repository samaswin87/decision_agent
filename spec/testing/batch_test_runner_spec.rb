require "spec_helper"

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
  end
end
