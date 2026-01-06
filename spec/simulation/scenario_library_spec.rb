require "spec_helper"

RSpec.describe DecisionAgent::Simulation::ScenarioLibrary do
  describe ".get_template" do
    it "returns template by name" do
      template = described_class.get_template(:loan_approval_high_risk)

      expect(template).to be_a(Hash)
      expect(template[:context]).to be_a(Hash)
      expect(template[:metadata]).to be_a(Hash)
    end

    it "returns nil for non-existent template" do
      expect(described_class.get_template(:non_existent)).to be_nil
    end
  end

  describe ".list_templates" do
    it "returns list of available templates" do
      templates = described_class.list_templates

      expect(templates).to be_an(Array)
      expect(templates).to include("loan_approval_high_risk")
      expect(templates).to include("loan_approval_low_risk")
    end
  end

  describe ".create_scenario" do
    it "creates scenario from template" do
      scenario = described_class.create_scenario(:loan_approval_high_risk)

      expect(scenario[:context]).to be_a(Hash)
      expect(scenario[:metadata]).to be_a(Hash)
    end

    it "merges overrides into template" do
      scenario = described_class.create_scenario(
        :loan_approval_high_risk,
        overrides: {
          context: { amount: 200_000 }
        }
      )

      expect(scenario[:context][:amount]).to eq(200_000)
    end

    it "raises error for non-existent template" do
      expect do
        described_class.create_scenario(:non_existent)
      end.to raise_error(DecisionAgent::Simulation::ScenarioExecutionError)
    end
  end

  describe ".generate_edge_cases" do
    let(:base_context) do
      {
        amount: 1000,
        credit_score: 700,
        name: "John"
      }
    end

    it "generates edge case scenarios" do
      scenarios = described_class.generate_edge_cases(base_context)

      expect(scenarios).to be_an(Array)
      expect(scenarios.size).to be > 0
    end

    it "includes nil value scenarios" do
      scenarios = described_class.generate_edge_cases(base_context)

      nil_scenarios = scenarios.select { |s| s[:metadata][:value] == "nil" }
      expect(nil_scenarios.size).to be > 0
    end

    it "includes zero value scenarios for numeric fields" do
      scenarios = described_class.generate_edge_cases(base_context)

      zero_scenarios = scenarios.select { |s| s[:metadata][:value] == "zero" }
      expect(zero_scenarios.size).to be > 0
    end

    it "includes empty string scenarios for string fields" do
      scenarios = described_class.generate_edge_cases(base_context)

      empty_scenarios = scenarios.select { |s| s[:metadata][:value] == "empty_string" }
      expect(empty_scenarios.size).to be > 0
    end
  end
end

