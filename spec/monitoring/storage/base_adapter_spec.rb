require "spec_helper"

RSpec.describe DecisionAgent::Monitoring::Storage::BaseAdapter do
  let(:adapter) { described_class.new }

  describe "abstract methods" do
    it "raises NotImplementedError for record_decision" do
      expect do
        adapter.record_decision("approve", {})
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for record_evaluation" do
      expect do
        adapter.record_evaluation("evaluator1")
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for record_performance" do
      expect do
        adapter.record_performance("operation")
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for record_error" do
      expect do
        adapter.record_error("ErrorType")
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for statistics" do
      expect do
        adapter.statistics
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for time_series" do
      expect do
        adapter.time_series(:decisions)
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for metrics_count" do
      expect do
        adapter.metrics_count
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for cleanup" do
      expect do
        adapter.cleanup(older_than: 3600)
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for available?" do
      expect do
        described_class.available?
      end.to raise_error(NotImplementedError)
    end
  end
end
