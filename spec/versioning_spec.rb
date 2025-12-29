require "spec_helper"
require "fileutils"
require "tempfile"

RSpec.describe "DecisionAgent Versioning System" do
  describe DecisionAgent::Versioning::FileStorageAdapter do
    let(:temp_dir) { Dir.mktmpdir }
    let(:adapter) { described_class.new(storage_path: temp_dir) }
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

    describe "#create_version" do
      it "creates a new version with version number 1" do
        version = adapter.create_version(
          rule_id: rule_id,
          content: rule_content,
          metadata: { created_by: "test_user", changelog: "Initial version" }
        )

        expect(version[:version_number]).to eq(1)
        expect(version[:rule_id]).to eq(rule_id)
        expect(version[:content]).to eq(rule_content)
        expect(version[:created_by]).to eq("test_user")
        expect(version[:changelog]).to eq("Initial version")
        expect(version[:status]).to eq("active")
      end

      it "auto-increments version numbers" do
        v1 = adapter.create_version(rule_id: rule_id, content: rule_content)
        v2 = adapter.create_version(rule_id: rule_id, content: rule_content)
        v3 = adapter.create_version(rule_id: rule_id, content: rule_content)

        expect(v1[:version_number]).to eq(1)
        expect(v2[:version_number]).to eq(2)
        expect(v3[:version_number]).to eq(3)
      end

      it "deactivates previous active versions" do
        v1 = adapter.create_version(rule_id: rule_id, content: rule_content)
        v2 = adapter.create_version(rule_id: rule_id, content: rule_content)

        versions = adapter.list_versions(rule_id: rule_id)
        expect(versions.find { |v| v[:id] == v1[:id] }[:status]).to eq("archived")
        expect(versions.find { |v| v[:id] == v2[:id] }[:status]).to eq("active")
      end

      it "persists versions to disk" do
        version = adapter.create_version(rule_id: rule_id, content: rule_content)

        # Create new adapter instance to verify persistence
        new_adapter = described_class.new(storage_path: temp_dir)
        loaded_version = new_adapter.get_version(version_id: version[:id])

        expect(loaded_version).to eq(version)
      end
    end

    describe "#list_versions" do
      it "returns empty array when no versions exist" do
        versions = adapter.list_versions(rule_id: "nonexistent")
        expect(versions).to eq([])
      end

      it "returns all versions for a rule ordered by version number descending" do
        adapter.create_version(rule_id: rule_id, content: rule_content)
        adapter.create_version(rule_id: rule_id, content: rule_content)
        adapter.create_version(rule_id: rule_id, content: rule_content)

        versions = adapter.list_versions(rule_id: rule_id)

        expect(versions.map { |v| v[:version_number] }).to eq([3, 2, 1])
      end

      it "respects limit parameter" do
        5.times { adapter.create_version(rule_id: rule_id, content: rule_content) }

        versions = adapter.list_versions(rule_id: rule_id, limit: 2)
        expect(versions.length).to eq(2)
      end
    end

    describe "#get_version" do
      it "returns nil for nonexistent version" do
        version = adapter.get_version(version_id: "nonexistent")
        expect(version).to be_nil
      end

      it "returns the correct version by ID" do
        adapter.create_version(rule_id: rule_id, content: rule_content)
        v2 = adapter.create_version(rule_id: rule_id, content: rule_content.merge(version: "2.0"))

        loaded = adapter.get_version(version_id: v2[:id])
        expect(loaded[:version_number]).to eq(2)
        expect(loaded[:content][:version]).to eq("2.0")
      end
    end

    describe "#get_version_by_number" do
      it "returns the correct version by rule_id and version_number" do
        adapter.create_version(rule_id: rule_id, content: rule_content)
        v2 = adapter.create_version(rule_id: rule_id, content: rule_content.merge(version: "2.0"))

        loaded = adapter.get_version_by_number(rule_id: rule_id, version_number: 2)
        expect(loaded[:id]).to eq(v2[:id])
        expect(loaded[:content][:version]).to eq("2.0")
      end

      it "returns nil if version number doesn't exist" do
        version = adapter.get_version_by_number(rule_id: rule_id, version_number: 999)
        expect(version).to be_nil
      end
    end

    describe "#get_active_version" do
      it "returns nil when no active version exists" do
        version = adapter.get_active_version(rule_id: "nonexistent")
        expect(version).to be_nil
      end

      it "returns the currently active version" do
        adapter.create_version(rule_id: rule_id, content: rule_content)
        v2 = adapter.create_version(rule_id: rule_id, content: rule_content)

        active = adapter.get_active_version(rule_id: rule_id)
        expect(active[:id]).to eq(v2[:id])
        expect(active[:status]).to eq("active")
      end
    end

    describe "#activate_version" do
      it "activates a version and deactivates others" do
        v1 = adapter.create_version(rule_id: rule_id, content: rule_content)
        v2 = adapter.create_version(rule_id: rule_id, content: rule_content)

        adapter.activate_version(version_id: v1[:id])

        versions = adapter.list_versions(rule_id: rule_id)
        expect(versions.find { |v| v[:id] == v1[:id] }[:status]).to eq("active")
        expect(versions.find { |v| v[:id] == v2[:id] }[:status]).to eq("archived")
      end

      it "raises error for nonexistent version" do
        expect do
          adapter.activate_version(version_id: "nonexistent")
        end.to raise_error(DecisionAgent::NotFoundError)
      end
    end

    describe "#compare_versions" do
      it "returns comparison with differences" do
        content1 = rule_content
        content2 = rule_content.merge(version: "2.0")

        v1 = adapter.create_version(rule_id: rule_id, content: content1)
        v2 = adapter.create_version(rule_id: rule_id, content: content2)

        comparison = adapter.compare_versions(version_id_1: v1[:id], version_id_2: v2[:id])

        expect(comparison[:version_1][:id]).to eq(v1[:id])
        expect(comparison[:version_2][:id]).to eq(v2[:id])
        expect(comparison[:differences]).to have_key(:added)
        expect(comparison[:differences]).to have_key(:removed)
        expect(comparison[:differences]).to have_key(:changed)
      end

      it "returns nil if either version doesn't exist" do
        v1 = adapter.create_version(rule_id: rule_id, content: rule_content)

        comparison = adapter.compare_versions(version_id_1: v1[:id], version_id_2: "nonexistent")
        expect(comparison).to be_nil
      end
    end

    describe "#delete_version" do
      it "deletes a version and removes it from index" do
        v1 = adapter.create_version(rule_id: rule_id, content: rule_content, metadata: { status: "draft" })
        v2 = adapter.create_version(rule_id: rule_id, content: rule_content)

        # Delete v1 (draft, not active)
        result = adapter.delete_version(version_id: v1[:id])
        expect(result).to be true

        # Verify it's deleted
        expect(adapter.get_version(version_id: v1[:id])).to be_nil
      end

      it "raises error when trying to delete active version" do
        v1 = adapter.create_version(rule_id: rule_id, content: rule_content)

        expect do
          adapter.delete_version(version_id: v1[:id])
        end.to raise_error(DecisionAgent::ValidationError, /Cannot delete active version/)
      end

      it "raises error for nonexistent version" do
        expect do
          adapter.delete_version(version_id: "nonexistent")
        end.to raise_error(DecisionAgent::NotFoundError)
      end

      it "handles file already deleted" do
        v1 = adapter.create_version(rule_id: rule_id, content: rule_content, metadata: { status: "draft" })
        v2 = adapter.create_version(rule_id: rule_id, content: rule_content)

        # Delete the file manually
        rule_dir = File.join(adapter.storage_path, rule_id)
        filename = "#{v1[:version_number]}.json"
        filepath = File.join(rule_dir, filename)
        File.delete(filepath) if File.exist?(filepath)

        # Should handle gracefully
        result = adapter.delete_version(version_id: v1[:id])
        expect(result).to be false
      end
    end

    describe "index management" do
      it "loads index on initialization" do
        v1 = adapter.create_version(rule_id: rule_id, content: rule_content)

        # Create new adapter instance - should load index
        new_adapter = DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: temp_dir)

        # Should be able to find version using index
        found = new_adapter.get_version(version_id: v1[:id])
        expect(found).not_to be_nil
      end

      it "handles corrupted JSON files in index loading" do
        # Create a corrupted JSON file
        rule_dir = File.join(temp_dir, rule_id)
        FileUtils.mkdir_p(rule_dir)
        corrupted_file = File.join(rule_dir, "1.json")
        File.write(corrupted_file, "invalid json content{")

        # Should handle gracefully and skip corrupted files
        expect do
          _new_adapter = DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: temp_dir)
        end.not_to raise_error
      end

      it "updates index when creating versions" do
        v1 = adapter.create_version(rule_id: rule_id, content: rule_content)

        # Index should be updated
        found = adapter.get_version(version_id: v1[:id])
        expect(found).not_to be_nil
      end

      it "removes from index when deleting versions" do
        v1 = adapter.create_version(rule_id: rule_id, content: rule_content, metadata: { status: "draft" })
        v2 = adapter.create_version(rule_id: rule_id, content: rule_content)

        version_id = v1[:id]
        adapter.delete_version(version_id: version_id)

        # Should not find in index
        expect(adapter.get_version(version_id: version_id)).to be_nil
      end
    end

    describe "filename sanitization" do
      it "sanitizes special characters in rule_id" do
        special_rule_id = "rule/with\\special:chars*?"
        version = adapter.create_version(rule_id: special_rule_id, content: rule_content)

        # Should create valid filename
        expect(version[:rule_id]).to eq(special_rule_id)

        # Should be able to retrieve it
        found = adapter.get_version(version_id: version[:id])
        expect(found).not_to be_nil
      end
    end

    describe "error handling" do
      it "handles update_version_status_unsafe with invalid status" do
        v1 = adapter.create_version(rule_id: rule_id, content: rule_content)

        # Try to update with invalid status via reflection (testing private method behavior)
        expect do
          adapter.send(:update_version_status_unsafe, v1[:id], "invalid_status", rule_id)
        end.to raise_error(DecisionAgent::ValidationError, /Invalid status/)
      end
    end
  end

  describe DecisionAgent::Versioning::VersionManager do
    let(:temp_dir) { Dir.mktmpdir }
    let(:adapter) { DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: temp_dir) }
    let(:manager) { described_class.new(adapter: adapter) }
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

    describe "#save_version" do
      it "creates a version with metadata" do
        version = manager.save_version(
          rule_id: rule_id,
          rule_content: rule_content,
          created_by: "admin",
          changelog: "Initial version"
        )

        expect(version[:rule_id]).to eq(rule_id)
        expect(version[:content]).to eq(rule_content)
        expect(version[:created_by]).to eq("admin")
        expect(version[:changelog]).to eq("Initial version")
      end

      it "validates rule content" do
        expect do
          manager.save_version(rule_id: rule_id, rule_content: nil)
        end.to raise_error(DecisionAgent::ValidationError, /cannot be nil/)

        expect do
          manager.save_version(rule_id: rule_id, rule_content: "not a hash")
        end.to raise_error(DecisionAgent::ValidationError, /must be a Hash/)

        expect do
          manager.save_version(rule_id: rule_id, rule_content: {})
        end.to raise_error(DecisionAgent::ValidationError, /cannot be empty/)
      end

      it "generates default changelog if not provided" do
        version = manager.save_version(rule_id: rule_id, rule_content: rule_content)
        expect(version[:changelog]).to match(/Version \d+/)
      end
    end

    describe "#get_versions" do
      it "returns all versions for a rule" do
        3.times { manager.save_version(rule_id: rule_id, rule_content: rule_content) }

        versions = manager.get_versions(rule_id: rule_id)
        expect(versions.length).to eq(3)
      end

      it "respects limit" do
        5.times { manager.save_version(rule_id: rule_id, rule_content: rule_content) }

        versions = manager.get_versions(rule_id: rule_id, limit: 2)
        expect(versions.length).to eq(2)
      end
    end

    describe "#rollback" do
      it "activates a previous version without creating a duplicate" do
        v1 = manager.save_version(rule_id: rule_id, rule_content: rule_content, changelog: "v1")
        manager.save_version(rule_id: rule_id, rule_content: rule_content, changelog: "v2")
        manager.save_version(rule_id: rule_id, rule_content: rule_content, changelog: "v3")

        # Rollback to v1 should just activate it, not create a duplicate
        rolled_back = manager.rollback(version_id: v1[:id], performed_by: "admin")

        expect(rolled_back[:status]).to eq("active")
        expect(rolled_back[:id]).to eq(v1[:id])

        # Should NOT create a new version - just activate the old one
        versions = manager.get_versions(rule_id: rule_id)
        expect(versions.length).to eq(3) # Still just v1, v2, v3

        # v1 should be active, v2 and v3 should be archived
        active_version = manager.get_active_version(rule_id: rule_id)
        expect(active_version[:id]).to eq(v1[:id])
        expect(active_version[:version_number]).to eq(1)
      end

      it "maintains version history integrity after rollback" do
        v1 = manager.save_version(rule_id: rule_id, rule_content: rule_content.merge(data: "v1"), changelog: "Version 1")
        v2 = manager.save_version(rule_id: rule_id, rule_content: rule_content.merge(data: "v2"), changelog: "Version 2")
        v3 = manager.save_version(rule_id: rule_id, rule_content: rule_content.merge(data: "v3"), changelog: "Version 3")

        # Rollback to v2
        manager.rollback(version_id: v2[:id])

        # All original versions should still exist with original data
        loaded_v1 = manager.get_version(version_id: v1[:id])
        loaded_v2 = manager.get_version(version_id: v2[:id])
        loaded_v3 = manager.get_version(version_id: v3[:id])

        expect(loaded_v1[:content][:data]).to eq("v1")
        expect(loaded_v2[:content][:data]).to eq("v2")
        expect(loaded_v3[:content][:data]).to eq("v3")

        # v2 should be active
        expect(loaded_v2[:status]).to eq("active")
        expect(loaded_v1[:status]).to eq("archived")
        expect(loaded_v3[:status]).to eq("archived")
      end
    end

    describe "#get_history" do
      it "returns comprehensive history with metadata" do
        manager.save_version(rule_id: rule_id, rule_content: rule_content)
        manager.save_version(rule_id: rule_id, rule_content: rule_content)

        history = manager.get_history(rule_id: rule_id)

        expect(history[:rule_id]).to eq(rule_id)
        expect(history[:total_versions]).to eq(2)
        expect(history[:active_version]).not_to be_nil
        expect(history[:versions]).to be_an(Array)
        expect(history[:created_at]).not_to be_nil
        expect(history[:updated_at]).not_to be_nil
      end
    end

    describe "edge cases and error handling" do
      it "handles empty rule_id gracefully" do
        expect do
          manager.save_version(rule_id: "", rule_content: rule_content)
        end.not_to raise_error
      end

      it "handles special characters in rule_id" do
        special_rule_id = "rule-with_special.chars@123"
        version = manager.save_version(rule_id: special_rule_id, rule_content: rule_content)

        expect(version[:rule_id]).to eq(special_rule_id)
      end

      it "handles large rule content" do
        large_content = {
          version: "1.0",
          ruleset: "large_ruleset",
          rules: Array.new(1000) do |i|
            {
              id: "rule_#{i}",
              if: { field: "value", op: "eq", value: i },
              then: { decision: "approve", weight: 0.5, reason: "Rule #{i}" }
            }
          end
        }

        version = manager.save_version(rule_id: rule_id, rule_content: large_content)
        expect(version[:content][:rules].length).to eq(1000)
      end

      it "handles deeply nested rule structures" do
        nested_content = {
          version: "1.0",
          ruleset: "nested",
          rules: [
            {
              id: "nested_rule",
              if: {
                all: [
                  {
                    any: [
                      { field: "a", op: "eq", value: 1 },
                      { field: "b", op: "eq", value: 2 }
                    ]
                  },
                  {
                    all: [
                      { field: "c", op: "gt", value: 3 },
                      { field: "d", op: "lt", value: 4 }
                    ]
                  }
                ]
              },
              then: { decision: "approve", weight: 0.8, reason: "Complex rule" }
            }
          ]
        }

        version = manager.save_version(rule_id: rule_id, rule_content: nested_content)
        expect(version[:content][:rules].first[:if][:all]).to be_an(Array)
      end

      it "preserves exact content structure including symbols and strings" do
        mixed_content = {
          version: "1.0",
          ruleset: "mixed",
          rules: [
            {
              id: "test",
              metadata: {
                string_key: "value",
                number_key: 123,
                boolean_key: true,
                null_key: nil,
                array_key: [1, 2, 3]
              },
              if: { field: "test", op: "eq", value: "value" },
              then: { decision: "approve", weight: 0.5, reason: "Test" }
            }
          ]
        }

        version = manager.save_version(rule_id: rule_id, rule_content: mixed_content)
        loaded = manager.get_version(version_id: version[:id])

        expect(loaded[:content][:rules].first[:metadata]).to eq(mixed_content[:rules].first[:metadata])
      end
    end

    describe "concurrent version creation" do
      it "maintains version number sequence with concurrent saves" do
        threads = 10.times.map do |i|
          Thread.new do
            manager.save_version(
              rule_id: rule_id,
              rule_content: rule_content.merge(version: i.to_s),
              created_by: "thread_#{i}"
            )
          end
        end

        threads.each(&:join)

        versions = manager.get_versions(rule_id: rule_id)
        version_numbers = versions.map { |v| v[:version_number] }.sort

        expect(version_numbers).to eq((1..10).to_a)
      end
    end

    describe "version lifecycle" do
      it "tracks complete version lifecycle from draft to archived" do
        # Create as draft
        v1 = adapter.create_version(
          rule_id: rule_id,
          content: rule_content,
          metadata: { status: "draft" }
        )
        expect(v1[:status]).to eq("draft")

        # Activate
        adapter.activate_version(version_id: v1[:id])
        v1_updated = adapter.get_version(version_id: v1[:id])
        expect(v1_updated[:status]).to eq("active")

        # Create new version (archives previous)
        v2 = adapter.create_version(rule_id: rule_id, content: rule_content)
        v1_archived = adapter.get_version(version_id: v1[:id])
        expect(v1_archived[:status]).to eq("archived")
        expect(v2[:status]).to eq("active")
      end
    end

    describe "comparison edge cases" do
      it "compares identical versions" do
        v1 = manager.save_version(rule_id: rule_id, rule_content: rule_content)
        v2 = manager.save_version(rule_id: rule_id, rule_content: rule_content)

        comparison = manager.compare(version_id_1: v1[:id], version_id_2: v2[:id])

        # Should have minimal differences (just metadata changes)
        expect(comparison[:differences][:added]).to be_empty
        expect(comparison[:differences][:removed]).to be_empty
      end

      it "detects all types of changes" do
        content_v1 = {
          version: "1.0",
          ruleset: "test",
          rules: [
            { id: "rule_1", if: { field: "a", op: "eq", value: 1 }, then: { decision: "approve", weight: 0.8, reason: "Test" } }
          ]
        }

        content_v2 = {
          version: "2.0", # changed
          ruleset: "test",
          rules: [
            { id: "rule_1", if: { field: "a", op: "eq", value: 2 }, then: { decision: "reject", weight: 0.9, reason: "Updated" } }, # modified
            { id: "rule_2", if: { field: "b", op: "gt", value: 100 }, then: { decision: "approve", weight: 0.7, reason: "New" } } # added
          ],
          new_field: "added" # added field
        }

        v1 = manager.save_version(rule_id: rule_id, rule_content: content_v1)
        v2 = manager.save_version(rule_id: rule_id, rule_content: content_v2)

        comparison = manager.compare(version_id_1: v1[:id], version_id_2: v2[:id])

        expect(comparison[:differences][:added].length).to be > 0
        expect(comparison[:differences][:changed]).to have_key(:version)
      end
    end

    describe "rollback scenarios" do
      it "activates previous version without creating duplicates" do
        v1 = manager.save_version(rule_id: rule_id, rule_content: rule_content, changelog: "Version 1")
        manager.save_version(rule_id: rule_id, rule_content: rule_content, changelog: "Version 2")
        manager.save_version(rule_id: rule_id, rule_content: rule_content, changelog: "Version 3")

        manager.rollback(version_id: v1[:id], performed_by: "admin")

        history = manager.get_history(rule_id: rule_id)
        expect(history[:total_versions]).to eq(3) # Still just v1, v2, v3 - no duplicate

        # v1 should be the active version
        expect(history[:active_version][:id]).to eq(v1[:id])
        expect(history[:active_version][:changelog]).to eq("Version 1")
      end

      it "handles multiple consecutive rollbacks without duplication" do
        v1 = manager.save_version(rule_id: rule_id, rule_content: rule_content)
        v2 = manager.save_version(rule_id: rule_id, rule_content: rule_content)
        v3 = manager.save_version(rule_id: rule_id, rule_content: rule_content)

        # Rollback to v1
        result1 = manager.rollback(version_id: v1[:id], performed_by: "user1")
        expect(result1[:id]).to eq(v1[:id])

        # Rollback to v2
        result2 = manager.rollback(version_id: v2[:id], performed_by: "user2")
        expect(result2[:id]).to eq(v2[:id])

        # Rollback to v3
        result3 = manager.rollback(version_id: v3[:id], performed_by: "user3")
        expect(result3[:id]).to eq(v3[:id])

        history = manager.get_history(rule_id: rule_id)
        expect(history[:total_versions]).to eq(3) # Still just the original 3 versions
        expect(history[:active_version][:id]).to eq(v3[:id])
      end
    end

    describe "query and filtering" do
      it "filters versions by limit correctly" do
        20.times { |i| manager.save_version(rule_id: rule_id, rule_content: rule_content, changelog: "Version #{i + 1}") }

        versions_5 = manager.get_versions(rule_id: rule_id, limit: 5)
        versions_10 = manager.get_versions(rule_id: rule_id, limit: 10)

        expect(versions_5.length).to eq(5)
        expect(versions_10.length).to eq(10)

        # Most recent versions should come first
        expect(versions_5.first[:version_number]).to eq(20)
        expect(versions_5.last[:version_number]).to eq(16)
      end

      it "handles versions across multiple rules" do
        rule_ids = %w[rule_a rule_b rule_c]

        rule_ids.each do |rid|
          3.times { manager.save_version(rule_id: rid, rule_content: rule_content) }

          versions = manager.get_versions(rule_id: rid)
          expect(versions.length).to eq(3)
          expect(versions.all? { |v| v[:rule_id] == rid }).to be true
        end
      end
    end

    describe "error recovery" do
      it "maintains data integrity after failed save" do
        # This test ensures that even if there's an error, previous versions remain intact
        manager.save_version(rule_id: rule_id, rule_content: rule_content)

        begin
          manager.save_version(rule_id: rule_id, rule_content: nil) # This should fail
        rescue DecisionAgent::ValidationError
          # Expected error
        end

        # Previous version should still be accessible
        versions = manager.get_versions(rule_id: rule_id)
        expect(versions.length).to eq(1)
        expect(versions.first[:content]).to eq(rule_content)
      end
    end
  end

  describe "Integration Tests" do
    let(:temp_dir) { Dir.mktmpdir }
    let(:adapter) { DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: temp_dir) }
    let(:manager) { DecisionAgent::Versioning::VersionManager.new(adapter: adapter) }

    after do
      FileUtils.rm_rf(temp_dir)
    end

    describe "real-world workflow" do
      it "handles a complete version management workflow" do
        # 1. Create initial rule
        approval_rule = {
          version: "1.0",
          ruleset: "approval_workflow",
          rules: [
            {
              id: "high_value",
              if: { field: "amount", op: "gt", value: 1000 },
              then: { decision: "approve", weight: 0.9, reason: "High value customer" }
            }
          ]
        }

        v1 = manager.save_version(
          rule_id: "approval_001",
          rule_content: approval_rule,
          created_by: "product_manager",
          changelog: "Initial approval rules"
        )

        expect(v1[:version_number]).to eq(1)

        # 2. Update threshold
        approval_rule[:rules].first[:if][:value] = 5000
        v2 = manager.save_version(
          rule_id: "approval_001",
          rule_content: approval_rule,
          created_by: "compliance_officer",
          changelog: "Increased threshold per compliance requirements"
        )

        expect(v2[:version_number]).to eq(2)

        # 3. Add new rule
        approval_rule[:rules] << {
          id: "fraud_check",
          if: { field: "fraud_score", op: "gt", value: 0.7 },
          then: { decision: "reject", weight: 1.0, reason: "High fraud risk" }
        }

        v3 = manager.save_version(
          rule_id: "approval_001",
          rule_content: approval_rule,
          created_by: "security_team",
          changelog: "Added fraud detection rule"
        )

        expect(v3[:version_number]).to eq(3)
        expect(v3[:content][:rules].length).to eq(2)

        # 4. Compare versions
        comparison = manager.compare(version_id_1: v1[:id], version_id_2: v3[:id])
        expect(comparison[:version_1][:version_number]).to eq(1)
        expect(comparison[:version_2][:version_number]).to eq(3)

        # 5. Rollback due to issue
        rolled_back = manager.rollback(
          version_id: v2[:id],
          performed_by: "incident_responder"
        )

        expect(rolled_back[:status]).to eq("active")
        expect(rolled_back[:id]).to eq(v2[:id])

        # 6. Verify history
        history = manager.get_history(rule_id: "approval_001")
        expect(history[:total_versions]).to eq(3) # v1, v2, v3 - no duplicate created
        expect(history[:active_version][:version_number]).to eq(2) # v2 is active
      end
    end

    describe "multi-rule management" do
      it "manages versions for multiple related rules" do
        rulesets = {
          "approval" => {
            version: "1.0",
            ruleset: "approval",
            rules: [{ id: "approve_1", if: { field: "amount", op: "lt", value: 100 }, then: { decision: "approve", weight: 0.8, reason: "Low amount" } }]
          },
          "rejection" => {
            version: "1.0",
            ruleset: "rejection",
            rules: [{ id: "reject_1", if: { field: "risk_score", op: "gt", value: 0.9 }, then: { decision: "reject", weight: 1.0, reason: "High risk" } }]
          },
          "review" => {
            version: "1.0",
            ruleset: "review",
            rules: [{ id: "review_1", if: { field: "amount", op: "gte", value: 10_000 }, then: { decision: "manual_review", weight: 0.9, reason: "Large transaction" } }]
          }
        }

        # Create versions for all rulesets
        rulesets.each do |name, content|
          manager.save_version(
            rule_id: name,
            rule_content: content,
            created_by: "system",
            changelog: "Initial #{name} rules"
          )
        end

        # Verify each has its own version history
        rulesets.each_key do |name|
          history = manager.get_history(rule_id: name)
          expect(history[:total_versions]).to eq(1)
          expect(history[:active_version][:rule_id]).to eq(name)
        end
      end
    end

    describe "status validation" do
      let(:rule_id) { "test_status_rule" }
      let(:rule_content) do
        {
          version: "1.0",
          ruleset: "test",
          rules: [{ id: "test", if: { field: "x", op: "eq", value: 1 }, then: { decision: "approve", weight: 0.8, reason: "Test" } }]
        }
      end

      it "rejects invalid status values when creating versions" do
        expect do
          adapter.create_version(
            rule_id: rule_id,
            content: rule_content,
            metadata: { status: "banana" }
          )
        end.to raise_error(DecisionAgent::ValidationError, /Invalid status 'banana'/)

        expect do
          adapter.create_version(
            rule_id: rule_id,
            content: rule_content,
            metadata: { status: "pending" }
          )
        end.to raise_error(DecisionAgent::ValidationError, /Invalid status 'pending'/)

        expect do
          adapter.create_version(
            rule_id: rule_id,
            content: rule_content,
            metadata: { status: "deleted" }
          )
        end.to raise_error(DecisionAgent::ValidationError, /Invalid status 'deleted'/)
      end

      it "accepts valid status values" do
        v1 = adapter.create_version(
          rule_id: rule_id,
          content: rule_content,
          metadata: { status: "draft" }
        )
        expect(v1[:status]).to eq("draft")

        v2 = adapter.create_version(
          rule_id: "rule_002",
          content: rule_content,
          metadata: { status: "active" }
        )
        expect(v2[:status]).to eq("active")

        v3 = adapter.create_version(
          rule_id: "rule_003",
          content: rule_content,
          metadata: { status: "archived" }
        )
        expect(v3[:status]).to eq("archived")
      end

      it "uses default status 'active' when not provided" do
        version = adapter.create_version(
          rule_id: rule_id,
          content: rule_content
        )
        expect(version[:status]).to eq("active")
      end
    end
  end
end
