require "spec_helper"
require "json"

RSpec.describe DecisionAgent::Simulation::MonteCarloSimulator do
  let(:evaluator) do
    DecisionAgent::Evaluators::JsonRuleEvaluator.new(
      rules_json: {
        version: "1.0",
        ruleset: "test_rules",
        rules: [
          {
            id: "rule_1",
            if: { field: "credit_score", op: "gte", value: 700 },
            then: { decision: "approve", weight: 0.9, reason: "High credit score" }
          },
          {
            id: "rule_2",
            if: { field: "credit_score", op: "lt", value: 700 },
            then: { decision: "reject", weight: 0.8, reason: "Low credit score" }
          }
        ]
      }
    )
  end
  let(:agent) { DecisionAgent::Agent.new(evaluators: [evaluator]) }
  let(:version_manager) { DecisionAgent::Versioning::VersionManager.new }
  let(:simulator) { described_class.new(agent: agent, version_manager: version_manager) }

  describe "#initialize" do
    it "creates a Monte Carlo simulator with agent and version manager" do
      expect(simulator.agent).to eq(agent)
      expect(simulator.version_manager).to eq(version_manager)
    end

    it "creates a simulator with default version manager" do
      sim = described_class.new(agent: agent)
      expect(sim.agent).to eq(agent)
      expect(sim.version_manager).to be_a(DecisionAgent::Versioning::VersionManager)
    end
  end

  describe "#simulate" do
    context "with normal distribution" do
      let(:distributions) do
        {
          credit_score: { type: :normal, mean: 650, stddev: 50 }
        }
      end

      it "runs Monte Carlo simulation" do
        results = simulator.simulate(
          distributions: distributions,
          iterations: 1000,
          base_context: { name: "Test User" },
          options: { parallel: false }
        )

        expect(results[:iterations]).to eq(1000)
        expect(results[:decision_probabilities]).to be_a(Hash)
        expect(results[:decision_probabilities].values.sum).to be_within(0.01).of(1.0)
        expect(results[:average_confidence]).to be >= 0
        expect(results[:average_confidence]).to be <= 1.0
      end

      it "includes decision statistics" do
        results = simulator.simulate(
          distributions: distributions,
          iterations: 1000,
          options: { parallel: false }
        )

        expect(results[:decision_stats]).to be_a(Hash)
        results[:decision_stats].each_value do |stats|
          expect(stats).to include(:count, :probability, :average_confidence)
        end
      end

      it "calculates confidence intervals" do
        results = simulator.simulate(
          distributions: distributions,
          iterations: 1000,
          options: { parallel: false }
        )

        expect(results[:confidence_intervals]).to be_a(Hash)
        expect(results[:confidence_intervals][:confidence]).to include(:lower, :upper)
        expect(results[:confidence_intervals][:level]).to eq(0.95)
      end

      it "uses seed for reproducibility" do
        results1 = simulator.simulate(
          distributions: distributions,
          iterations: 100,
          options: { seed: 12_345, parallel: false }
        )

        results2 = simulator.simulate(
          distributions: distributions,
          iterations: 100,
          options: { seed: 12_345, parallel: false }
        )

        # Decision probabilities should be very similar with same seed
        expect(results1[:decision_probabilities].keys).to eq(results2[:decision_probabilities].keys)
      end
    end

    context "with uniform distribution" do
      let(:distributions) do
        {
          credit_score: { type: :uniform, min: 500, max: 800 }
        }
      end

      it "runs simulation with uniform distribution" do
        results = simulator.simulate(
          distributions: distributions,
          iterations: 1000,
          options: { parallel: false }
        )

        expect(results[:iterations]).to eq(1000)
        expect(results[:decision_probabilities]).to be_a(Hash)
      end
    end

    context "with discrete distribution" do
      let(:distributions) do
        {
          credit_score: {
            type: :discrete,
            values: [600, 650, 700, 750],
            probabilities: [0.2, 0.3, 0.3, 0.2]
          }
        }
      end

      it "runs simulation with discrete distribution" do
        results = simulator.simulate(
          distributions: distributions,
          iterations: 1000,
          options: { parallel: false }
        )

        expect(results[:iterations]).to eq(1000)
        expect(results[:decision_probabilities]).to be_a(Hash)
      end
    end

    context "with triangular distribution" do
      let(:distributions) do
        {
          credit_score: { type: :triangular, min: 500, mode: 650, max: 800 }
        }
      end

      it "runs simulation with triangular distribution" do
        results = simulator.simulate(
          distributions: distributions,
          iterations: 1000,
          options: { parallel: false }
        )

        expect(results[:iterations]).to eq(1000)
        expect(results[:decision_probabilities]).to be_a(Hash)
      end
    end

    context "with multiple distributions" do
      let(:evaluator_multi) do
        DecisionAgent::Evaluators::JsonRuleEvaluator.new(
          rules_json: {
            version: "1.0",
            ruleset: "test_rules",
            rules: [
              {
                id: "rule_1",
                if: { field: "credit_score", op: "gte", value: 700 },
                then: { decision: "approve", weight: 0.9, reason: "High credit score" }
              },
              {
                id: "rule_2",
                if: { field: "credit_score", op: "lt", value: 700 },
                then: { decision: "reject", weight: 0.8, reason: "Low credit score" }
              }
            ]
          }
        )
      end
      let(:agent_multi) { DecisionAgent::Agent.new(evaluators: [evaluator_multi]) }
      let(:simulator_multi) { described_class.new(agent: agent_multi, version_manager: version_manager) }

      let(:distributions) do
        {
          credit_score: { type: :normal, mean: 650, stddev: 50 },
          amount: { type: :uniform, min: 50_000, max: 200_000 }
        }
      end

      it "runs simulation with multiple probabilistic inputs" do
        results = simulator_multi.simulate(
          distributions: distributions,
          iterations: 1000,
          base_context: { name: "Test User" }
        )

        expect(results[:iterations]).to eq(1000)
        expect(results[:decision_probabilities]).to be_a(Hash)

        # Check that contexts include both fields
        sample_context = results[:results].first[:context]
        expect(sample_context).to include(:credit_score, :amount, :name)
      end
    end

    context "with validation" do
      it "raises error for invalid distribution type" do
        expect do
          simulator.simulate(
            distributions: {
              credit_score: { type: :invalid }
            },
            iterations: 100
          )
        end.to raise_error(ArgumentError, /Unknown distribution type/)
      end

      it "raises error for normal distribution without mean" do
        expect do
          simulator.simulate(
            distributions: {
              credit_score: { type: :normal, stddev: 50 }
            },
            iterations: 100
          )
        end.to raise_error(ArgumentError, /requires :mean and :stddev/)
      end

      it "raises error for uniform distribution without min" do
        expect do
          simulator.simulate(
            distributions: {
              credit_score: { type: :uniform, max: 800 }
            },
            iterations: 100
          )
        end.to raise_error(ArgumentError, /requires :min and :max/)
      end

      it "raises error for discrete distribution with mismatched arrays" do
        expect do
          simulator.simulate(
            distributions: {
              credit_score: {
                type: :discrete,
                values: [600, 650],
                probabilities: [0.5, 0.3, 0.2]
              }
            },
            iterations: 100
          )
        end.to raise_error(ArgumentError, /must have same length/)
      end

      it "raises error for discrete distribution with probabilities not summing to 1" do
        expect do
          simulator.simulate(
            distributions: {
              credit_score: {
                type: :discrete,
                values: [600, 650],
                probabilities: [0.5, 0.3]
              }
            },
            iterations: 100
          )
        end.to raise_error(ArgumentError, /must sum to 1.0/)
      end
    end

    context "with parallel execution" do
      let(:distributions) do
        {
          credit_score: { type: :normal, mean: 650, stddev: 50 }
        }
      end

      it "runs in parallel when enabled" do
        results = simulator.simulate(
          distributions: distributions,
          iterations: 5000,
          options: { parallel: true, thread_count: 4, seed: 42 }
        )

        expect(results[:iterations]).to eq(5000)
        expect(results[:decision_probabilities]).to be_a(Hash)
      end

      it "runs sequentially when parallel disabled" do
        results = simulator.simulate(
          distributions: distributions,
          iterations: 1000,
          options: { parallel: false }
        )

        expect(results[:iterations]).to eq(1000)
      end
    end

    context "with custom confidence level" do
      let(:distributions) do
        {
          credit_score: { type: :normal, mean: 650, stddev: 50 }
        }
      end

      it "uses custom confidence level" do
        results = simulator.simulate(
          distributions: distributions,
          iterations: 1000,
          options: { confidence_level: 0.99, parallel: false }
        )

        expect(results[:confidence_intervals][:level]).to eq(0.99)
      end
    end
  end

  describe "#sensitivity_analysis" do
    let(:base_distributions) do
      {
        credit_score: { type: :normal, mean: 650, stddev: 50 }
      }
    end

    let(:sensitivity_params) do
      {
        credit_score: {
          mean: [600, 650, 700],
          stddev: [40, 50, 60]
        }
      }
    end

    it "performs sensitivity analysis on distribution parameters" do
      results = simulator.sensitivity_analysis(
        base_distributions: base_distributions,
        sensitivity_params: sensitivity_params,
        iterations: 500
      )

      expect(results[:sensitivity_results]).to be_a(Hash)
      expect(results[:sensitivity_results][:credit_score]).to be_a(Hash)
      expect(results[:sensitivity_results][:credit_score][:mean]).to be_a(Hash)
      expect(results[:sensitivity_results][:credit_score][:stddev]).to be_a(Hash)
    end

    it "includes impact analysis for each parameter" do
      results = simulator.sensitivity_analysis(
        base_distributions: base_distributions,
        sensitivity_params: sensitivity_params,
        iterations: 500
      )

      mean_results = results[:sensitivity_results][:credit_score][:mean]
      expect(mean_results[:impact_analysis]).to be_a(Hash)

      mean_results[:impact_analysis].each_value do |impact|
        expect(impact).to include(:min_probability, :max_probability, :range, :sensitivity)
      end
    end

    it "tests multiple parameter values" do
      results = simulator.sensitivity_analysis(
        base_distributions: base_distributions,
        sensitivity_params: sensitivity_params,
        iterations: 500
      )

      mean_results = results[:sensitivity_results][:credit_score][:mean]
      expect(mean_results[:values_tested]).to eq([600, 650, 700])
      expect(mean_results[:results].size).to eq(3)
    end

    it "includes base distributions in results" do
      results = simulator.sensitivity_analysis(
        base_distributions: base_distributions,
        sensitivity_params: sensitivity_params,
        iterations: 500
      )

      expect(results[:base_distributions]).to eq(base_distributions)
      expect(results[:iterations_per_test]).to eq(500)
    end
  end

  context "with lognormal distribution" do
    let(:evaluator_lognormal) do
      DecisionAgent::Evaluators::JsonRuleEvaluator.new(
        rules_json: {
          version: "1.0",
          ruleset: "test_rules",
          rules: [
            {
              id: "rule_1",
              if: { field: "amount", op: "gt", value: 0 },
              then: { decision: "approve", weight: 0.9, reason: "Positive amount" }
            }
          ]
        }
      )
    end
    let(:agent_lognormal) { DecisionAgent::Agent.new(evaluators: [evaluator_lognormal]) }
    let(:simulator_lognormal) { described_class.new(agent: agent_lognormal, version_manager: version_manager) }

    let(:distributions) do
      {
        amount: { type: :lognormal, mean: 10.0, stddev: 0.5 }
      }
    end

    it "runs simulation with lognormal distribution" do
      results = simulator_lognormal.simulate(
        distributions: distributions,
        iterations: 1000
      )

      expect(results[:iterations]).to eq(1000)
      expect(results[:decision_probabilities]).to be_a(Hash)
    end
  end

  context "with exponential distribution" do
    let(:evaluator_exp) do
      DecisionAgent::Evaluators::JsonRuleEvaluator.new(
        rules_json: {
          version: "1.0",
          ruleset: "test_rules",
          rules: [
            {
              id: "rule_1",
              if: { field: "time_to_event", op: "gt", value: 0 },
              then: { decision: "approve", weight: 0.9, reason: "Positive time" }
            }
          ]
        }
      )
    end
    let(:agent_exp) { DecisionAgent::Agent.new(evaluators: [evaluator_exp]) }
    let(:simulator_exp) { described_class.new(agent: agent_exp, version_manager: version_manager) }

    let(:distributions) do
      {
        time_to_event: { type: :exponential, lambda: 0.1 }
      }
    end

    it "runs simulation with exponential distribution" do
      results = simulator_exp.simulate(
        distributions: distributions,
        iterations: 1000
      )

      expect(results[:iterations]).to eq(1000)
      expect(results[:decision_probabilities]).to be_a(Hash)
    end
  end

  context "with nested field paths" do
    let(:evaluator_nested) do
      DecisionAgent::Evaluators::JsonRuleEvaluator.new(
        rules_json: {
          version: "1.0",
          ruleset: "test_rules",
          rules: [
            {
              id: "rule_1",
              if: { field: "user.credit_score", op: "gte", value: 700 },
              then: { decision: "approve", weight: 0.9, reason: "High credit score" }
            },
            {
              id: "rule_2",
              if: { field: "user.credit_score", op: "lt", value: 700 },
              then: { decision: "reject", weight: 0.8, reason: "Low credit score" }
            }
          ]
        }
      )
    end
    let(:agent_nested) { DecisionAgent::Agent.new(evaluators: [evaluator_nested]) }
    let(:simulator_nested) { described_class.new(agent: agent_nested, version_manager: version_manager) }

    let(:distributions) do
      {
        "user.credit_score" => { type: :normal, mean: 650, stddev: 50 }
      }
    end

    it "handles nested field paths" do
      results = simulator_nested.simulate(
        distributions: distributions,
        iterations: 100,
        base_context: { user: { name: "Test" } }
      )

      expect(results[:iterations]).to eq(100)
      sample_context = results[:results].first[:context]
      expect(sample_context[:user]).to be_a(Hash)
      expect(sample_context[:user][:credit_score]).to be_a(Numeric)
    end
  end

  context "edge cases" do
    it "handles zero iterations gracefully" do
      results = simulator.simulate(
        distributions: {
          credit_score: { type: :normal, mean: 650, stddev: 50 }
        },
        iterations: 0
      )

      expect(results[:iterations]).to eq(0)
      expect(results[:decision_probabilities]).to eq({})
      expect(results[:average_confidence]).to eq(0.0)
    end

    it "handles single iteration" do
      results = simulator.simulate(
        distributions: {
          credit_score: { type: :normal, mean: 750, stddev: 10 }
        },
        iterations: 1
      )

      expect(results[:iterations]).to eq(1)
      expect(results[:results].size).to eq(1)
    end
  end
end
