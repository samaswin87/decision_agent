require "spec_helper"
require "decision_agent/dmn/errors"

RSpec.describe "FEEL Errors" do
  describe DecisionAgent::Dmn::FeelParseError do
    it "creates error with message only" do
      error = DecisionAgent::Dmn::FeelParseError.new("Parse failed")
      expect(error.message).to eq("Parse failed")
    end
  end

  describe DecisionAgent::Dmn::FeelEvaluationError do
    it "creates error with message only" do
      error = DecisionAgent::Dmn::FeelEvaluationError.new("Evaluation failed")
      expect(error.message).to eq("Evaluation failed")
    end
  end
end
