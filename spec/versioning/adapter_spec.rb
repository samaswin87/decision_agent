require "spec_helper"
require "fileutils"
require "tempfile"
require "decision_agent/versioning/adapter"
require "decision_agent/versioning/file_storage_adapter"

RSpec.describe DecisionAgent::Versioning::Adapter do
  let(:temp_dir) { Dir.mktmpdir }
  let(:adapter) { DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: temp_dir) }
  let(:rule_id) { "test_rule_001" }
  let(:rule_content) do
    {
      version: "1.0",
      ruleset: "test_ruleset",
      rules: [
        {
          id: "rule_1",
          if: { field: "amount", op: "gt", value: 100 },
          then: { decision: "approve", weight: 0.8, reason: "High value" }
        }
      ]
    }
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#compare_versions" do
    it "returns nil when first version doesn't exist" do
      v2 = adapter.create_version(rule_id: rule_id, content: rule_content)

      comparison = adapter.compare_versions(version_id_1: "nonexistent", version_id_2: v2[:id])
      expect(comparison).to be_nil
    end

    it "returns nil when second version doesn't exist" do
      v1 = adapter.create_version(rule_id: rule_id, content: rule_content)

      comparison = adapter.compare_versions(version_id_1: v1[:id], version_id_2: "nonexistent")
      expect(comparison).to be_nil
    end

    it "calculates differences correctly with added keys" do
      content1 = { key1: "value1", key2: "value2" }
      content2 = { key1: "value1", key2: "value2", key3: "value3" }

      v1 = adapter.create_version(rule_id: rule_id, content: content1)
      v2 = adapter.create_version(rule_id: "rule_2", content: content2)

      comparison = adapter.compare_versions(version_id_1: v1[:id], version_id_2: v2[:id])

      expect(comparison[:differences][:added]).not_to be_empty
    end

    it "calculates differences correctly with removed keys" do
      content1 = { key1: "value1", key2: "value2", key3: "value3" }
      content2 = { key1: "value1", key2: "value2" }

      v1 = adapter.create_version(rule_id: rule_id, content: content1)
      v2 = adapter.create_version(rule_id: "rule_2", content: content2)

      comparison = adapter.compare_versions(version_id_1: v1[:id], version_id_2: v2[:id])

      expect(comparison[:differences][:removed]).not_to be_empty
    end

    it "calculates differences correctly with changed values" do
      content1 = { key1: "value1", key2: "value2" }
      content2 = { key1: "value1", key2: "value2_changed" }

      v1 = adapter.create_version(rule_id: rule_id, content: content1)
      v2 = adapter.create_version(rule_id: "rule_2", content: content2)

      comparison = adapter.compare_versions(version_id_1: v1[:id], version_id_2: v2[:id])

      expect(comparison[:differences][:changed]).to have_key(:key2)
      expect(comparison[:differences][:changed][:key2][:old]).to eq("value2")
      expect(comparison[:differences][:changed][:key2][:new]).to eq("value2_changed")
    end

    it "does not include nil values in changed differences" do
      content1 = { key1: "value1", key2: "value2" }
      content2 = { key1: "value1", key2: nil }

      v1 = adapter.create_version(rule_id: rule_id, content: content1)
      v2 = adapter.create_version(rule_id: "rule_2", content: content2)

      comparison = adapter.compare_versions(version_id_1: v1[:id], version_id_2: v2[:id])

      # key2 should not be in changed since new value is nil
      expect(comparison[:differences][:changed]).not_to have_key(:key2)
    end

    it "returns identical versions with empty differences" do
      v1 = adapter.create_version(rule_id: rule_id, content: rule_content)
      v2 = adapter.create_version(rule_id: "rule_2", content: rule_content)

      comparison = adapter.compare_versions(version_id_1: v1[:id], version_id_2: v2[:id])

      expect(comparison[:differences][:added]).to be_empty
      expect(comparison[:differences][:removed]).to be_empty
      expect(comparison[:differences][:changed]).to be_empty
    end
  end

  describe "abstract methods" do
    # Test that abstract methods raise NotImplementedError when called on base class
    # We use a minimal test adapter class for this
    let(:abstract_adapter) do
      Class.new(DecisionAgent::Versioning::Adapter).new
    end

    it "raises NotImplementedError for create_version" do
      expect do
        abstract_adapter.create_version(rule_id: "test", content: {})
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for list_versions" do
      expect do
        abstract_adapter.list_versions(rule_id: "test")
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for get_version" do
      expect do
        abstract_adapter.get_version(version_id: "test")
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for get_version_by_number" do
      expect do
        abstract_adapter.get_version_by_number(rule_id: "test", version_number: 1)
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for get_active_version" do
      expect do
        abstract_adapter.get_active_version(rule_id: "test")
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for activate_version" do
      expect do
        abstract_adapter.activate_version(version_id: "test")
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for delete_version" do
      expect do
        abstract_adapter.delete_version(version_id: "test")
      end.to raise_error(NotImplementedError)
    end
  end
end

