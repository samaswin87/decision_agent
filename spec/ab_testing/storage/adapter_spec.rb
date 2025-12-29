require "spec_helper"
require_relative "../../../lib/decision_agent/ab_testing/storage/adapter"

RSpec.describe DecisionAgent::ABTesting::Storage::Adapter do
  let(:adapter) { described_class.new }

  describe "#save_test" do
    it "raises NotImplementedError" do
      test = double("ABTest")
      expect { adapter.save_test(test) }.to raise_error(NotImplementedError, /must implement #save_test/)
    end
  end

  describe "#get_test" do
    it "raises NotImplementedError" do
      expect { adapter.get_test("test_id") }.to raise_error(NotImplementedError, /must implement #get_test/)
    end
  end

  describe "#update_test" do
    it "raises NotImplementedError" do
      expect { adapter.update_test("test_id", {}) }.to raise_error(NotImplementedError, /must implement #update_test/)
    end
  end

  describe "#list_tests" do
    it "raises NotImplementedError" do
      expect { adapter.list_tests }.to raise_error(NotImplementedError, /must implement #list_tests/)
    end

    it "raises NotImplementedError with status filter" do
      expect { adapter.list_tests(status: "active") }.to raise_error(NotImplementedError, /must implement #list_tests/)
    end

    it "raises NotImplementedError with limit" do
      expect { adapter.list_tests(limit: 10) }.to raise_error(NotImplementedError, /must implement #list_tests/)
    end
  end

  describe "#save_assignment" do
    it "raises NotImplementedError" do
      assignment = double("ABTestAssignment")
      expect { adapter.save_assignment(assignment) }.to raise_error(NotImplementedError, /must implement #save_assignment/)
    end
  end

  describe "#update_assignment" do
    it "raises NotImplementedError" do
      expect { adapter.update_assignment("assignment_id", {}) }.to raise_error(NotImplementedError, /must implement #update_assignment/)
    end
  end

  describe "#get_assignments" do
    it "raises NotImplementedError" do
      expect { adapter.get_assignments("test_id") }.to raise_error(NotImplementedError, /must implement #get_assignments/)
    end
  end

  describe "#delete_test" do
    it "raises NotImplementedError" do
      expect { adapter.delete_test("test_id") }.to raise_error(NotImplementedError, /must implement #delete_test/)
    end
  end
end

