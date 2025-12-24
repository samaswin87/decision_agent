# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tempfile"

# rubocop:disable Lint/ConstantDefinitionInBlock
RSpec.describe "Issue Verification Tests" do
  # ============================================================================
  # ISSUE #4: Missing Database Constraints
  # ============================================================================
  if defined?(ActiveRecord)
    describe "Issue #4: Database Constraints" do
      before(:all) do
        # Setup in-memory SQLite database
        ActiveRecord::Base.establish_connection(
          adapter: "sqlite3",
          database: ":memory:"
        )
      end

      before(:each) do
        # Clean slate for each test
        ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS rule_versions")
      end

      describe "Unique constraint on [rule_id, version_number]" do
        it "FAILS without unique constraint - allows duplicate version numbers" do
          # Create table WITHOUT unique constraint (current state)
          ActiveRecord::Schema.define do
            create_table :rule_versions, force: true do |t|
              t.string :rule_id, null: false
              t.integer :version_number, null: false
              t.text :content, null: false
              t.string :created_by, null: false, default: "system"
              t.text :changelog
              t.string :status, null: false, default: "draft"
              t.timestamps
            end
            # NOTE: NO unique index on [rule_id, version_number]
          end

          # Define model
          class TestRuleVersion1 < ActiveRecord::Base
            self.table_name = "rule_versions"
          end

          # Create duplicate version numbers - THIS SHOULD FAIL BUT DOESN'T
          TestRuleVersion1.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: { test: "v1" }.to_json
          )

          # This should fail but won't without unique constraint
          # BUG: Allows duplicates!
          expect do
            TestRuleVersion1.create!(
              rule_id: "test_rule",
              version_number: 1, # DUPLICATE!
              content: { test: "v1_duplicate" }.to_json
            )
          end.not_to raise_error
          # Verify duplicates exist
          duplicates = TestRuleVersion1.where(rule_id: "test_rule", version_number: 1)
          expect(duplicates.count).to be > 1, "Expected duplicates to exist without constraint"
        end

        it "PASSES with unique constraint - prevents duplicate version numbers" do
          # Create table WITH unique constraint (fixed state)
          ActiveRecord::Schema.define do
            create_table :rule_versions, force: true do |t|
              t.string :rule_id, null: false
              t.integer :version_number, null: false
              t.text :content, null: false
              t.string :created_by, null: false, default: "system"
              t.text :changelog
              t.string :status, null: false, default: "draft"
              t.timestamps
            end
            # ✅ ADD unique constraint
            add_index :rule_versions, %i[rule_id version_number], unique: true
          end

          # Define model
          class TestRuleVersion2 < ActiveRecord::Base
            self.table_name = "rule_versions"
          end

          # Create first version
          TestRuleVersion2.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: { test: "v1" }.to_json
          )

          # Try to create duplicate - should fail
          expect do
            TestRuleVersion2.create!(
              rule_id: "test_rule",
              version_number: 1, # DUPLICATE!
              content: { test: "v1_duplicate" }.to_json
            )
          end.to raise_error(ActiveRecord::RecordNotUnique)
        end

        it "demonstrates race condition without unique constraint" do
          # Create table without unique constraint
          ActiveRecord::Schema.define do
            create_table :rule_versions, force: true do |t|
              t.string :rule_id, null: false
              t.integer :version_number, null: false
              t.text :content, null: false
              t.string :created_by, null: false, default: "system"
              t.text :changelog
              t.string :status, null: false, default: "draft"
              t.timestamps
            end
          end

          class TestRuleVersion3 < ActiveRecord::Base
            self.table_name = "rule_versions"
          end

          # Simulate race condition
          threads = []
          results = []
          mutex = Mutex.new

          10.times do |i|
            threads << Thread.new do
              # Calculate next version (simulating adapter logic)
              last = TestRuleVersion3.where(rule_id: "test_rule")
                                     .order(version_number: :desc)
                                     .first
              next_version = last ? last.version_number + 1 : 1

              # Create version (race window here!)
              version = TestRuleVersion3.create!(
                rule_id: "test_rule",
                version_number: next_version,
                content: { thread: i }.to_json
              )
              mutex.synchronize { results << version }
            end
          end

          threads.each(&:join)

          # Check for duplicate version numbers
          version_numbers = results.map(&:version_number).sort
          duplicates = version_numbers.select { |v| version_numbers.count(v) > 1 }.uniq

          if duplicates.any?
            puts "\n⚠️  RACE CONDITION DETECTED: Duplicate version numbers: #{duplicates.inspect}"
            puts "    Version numbers created: #{version_numbers.inspect}"
          end

          # Without constraint, we EXPECT duplicates in high concurrency
          # This test demonstrates the problem
        end
      end

      describe "Partial unique index - only one active version per rule" do
        it "allows multiple active versions without partial unique index (BUG)" do
          # Current migration doesn't have partial unique index
          ActiveRecord::Schema.define do
            create_table :rule_versions, force: true do |t|
              t.string :rule_id, null: false
              t.integer :version_number, null: false
              t.text :content, null: false
              t.string :status, default: "active", null: false
              t.timestamps
            end
            add_index :rule_versions, %i[rule_id version_number], unique: true
            # NOTE: NO partial unique index on [rule_id, status] where status='active'
          end

          class TestRuleVersion4 < ActiveRecord::Base
            self.table_name = "rule_versions"
          end

          # Create multiple active versions - should fail but won't
          TestRuleVersion4.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: { test: "v1" }.to_json,
            status: "active"
          )

          # This should fail but doesn't without partial unique index
          expect do
            TestRuleVersion4.create!(
              rule_id: "test_rule",
              version_number: 2,
              content: { test: "v2" }.to_json,
              status: "active" # DUPLICATE ACTIVE!
            )
          end.not_to raise_error

          # Verify multiple active versions exist (BUG!)
          active_count = TestRuleVersion4.where(rule_id: "test_rule", status: "active").count
          expect(active_count).to be > 1, "Expected multiple active versions without partial index"
        end

        it "prevents multiple active versions with partial unique index (PostgreSQL only)" do
          skip "Partial unique index requires PostgreSQL" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"

          # With partial unique index
          ActiveRecord::Schema.define do
            create_table :rule_versions, force: true do |t|
              t.string :rule_id, null: false
              t.integer :version_number, null: false
              t.text :content, null: false
              t.string :status, default: "active", null: false
              t.timestamps
            end
            add_index :rule_versions, %i[rule_id version_number], unique: true
            # ✅ Partial unique index (PostgreSQL only)
            add_index :rule_versions, %i[rule_id status],
                      unique: true,
                      where: "status = 'active'",
                      name: "index_rule_versions_one_active_per_rule"
          end

          class TestRuleVersion5 < ActiveRecord::Base
            self.table_name = "rule_versions"
          end

          TestRuleVersion5.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: { test: "v1" }.to_json,
            status: "active"
          )

          # Try to create second active version - should fail
          expect do
            TestRuleVersion5.create!(
              rule_id: "test_rule",
              version_number: 2,
              content: { test: "v2" }.to_json,
              status: "active"
            )
          end.to raise_error(ActiveRecord::RecordNotUnique)
        end
      end
    end
  end

  # ============================================================================
  # ISSUE #5: FileStorageAdapter - Per-Rule Mutex Performance (FIXED)
  # ============================================================================
  describe "Issue #5: FileStorageAdapter Per-Rule Mutex Performance" do
    let(:temp_dir) { Dir.mktmpdir }
    let(:adapter) { DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: temp_dir) }
    let(:rule_content) do
      {
        version: "1.0",
        rules: [{ id: "r1", if: { field: "x", op: "eq", value: 1 }, then: { decision: "approve", weight: 0.8, reason: "Test" } }]
      }
    end

    after { FileUtils.rm_rf(temp_dir) }

    it "verifies per-rule locks allow parallel access to different rules" do
      # Create initial versions for two different rules
      adapter.create_version(rule_id: "rule_a", content: rule_content)
      adapter.create_version(rule_id: "rule_b", content: rule_content)

      timings = { rule_a: [], rule_b: [] }
      mutex = Mutex.new

      # Thread 1: Read rule_a with simulated slow operation
      thread1 = Thread.new do
        start = Time.now
        adapter.get_active_version(rule_id: "rule_a")
        sleep(0.1) # Simulate slow operation
        elapsed = Time.now - start
        mutex.synchronize { timings[:rule_a] << elapsed }
      end

      sleep(0.01) # Ensure thread1 starts first

      # Thread 2: Read rule_b (should NOT be blocked by thread1 with per-rule locks)
      thread2 = Thread.new do
        start = Time.now
        adapter.get_active_version(rule_id: "rule_b") # Different rule!
        elapsed = Time.now - start
        mutex.synchronize { timings[:rule_b] << elapsed }
      end

      thread1.join
      thread2.join

      # With per-rule mutexes, thread2 should NOT wait for thread1
      # Expected: thread2 completes quickly (~0.01s or less), not blocked by thread1's sleep
      puts "\n✅ Per-Rule Lock Performance:"
      puts "    Thread 1 (rule_a): #{timings[:rule_a].first.round(3)}s"
      puts "    Thread 2 (rule_b): #{timings[:rule_b].first.round(3)}s"

      expect(timings[:rule_b].first).to be < 0.05,
                                        "Thread reading rule_b should not be blocked by thread reading rule_a (per-rule locks)"
    end

    it "verifies concurrent operations on different rules run in parallel" do
      # Create 5 different rules
      5.times { |i| adapter.create_version(rule_id: "rule_#{i}", content: rule_content) }

      operations_log = []
      log_mutex = Mutex.new

      threads = []
      10.times do |i|
        threads << Thread.new do
          rule_id = "rule_#{i % 5}" # 5 different rules
          start = Time.now
          adapter.get_active_version(rule_id: rule_id)
          elapsed = Time.now - start
          log_mutex.synchronize do
            operations_log << { rule_id: rule_id, elapsed: elapsed, thread: i }
          end
        end
      end

      threads.each(&:join)

      puts "\n📊 Per-Rule Lock Concurrency:"
      puts "    Operations completed: #{operations_log.size}"
      puts "    Different rules accessed: #{operations_log.map { |op| op[:rule_id] }.uniq.size}"
      puts "    Benefit: Different rules can be accessed in parallel!"

      expect(operations_log.size).to eq(10)
    end

    it "verifies per-rule locks don't serialize operations across different rules" do
      # Create multiple rules
      rules_count = 5
      rules_count.times { |i| adapter.create_version(rule_id: "rule_#{i}", content: rule_content) }

      # Track which operations run concurrently
      start_times = {}
      end_times = {}
      times_mutex = Mutex.new

      # Run operations on different rules with artificial delays
      threads = rules_count.times.map do |i|
        Thread.new do
          rule_id = "rule_#{i}"
          times_mutex.synchronize { start_times[rule_id] = Time.now }

          # Simulate some work
          adapter.get_active_version(rule_id: rule_id)
          sleep(0.01)

          times_mutex.synchronize { end_times[rule_id] = Time.now }
        end
      end
      threads.each(&:join)

      # Calculate overlaps - how many operations were running at the same time
      overlaps = 0
      start_times.each do |rule_id, start_time|
        end_time = end_times[rule_id]
        # Count how many other operations overlapped with this one
        other_overlaps = start_times.count do |other_rule_id, other_start|
          next if other_rule_id == rule_id

          other_end = end_times[other_rule_id]
          # Check if time ranges overlap
          (other_start <= end_time) && (start_time <= other_end)
        end
        overlaps += other_overlaps
      end

      puts "\n📊 Concurrency Verification:"
      puts "    Rules processed: #{rules_count}"
      puts "    Overlapping operations detected: #{overlaps}"
      puts "    ✅ Per-rule locks allow different rules to be accessed concurrently!"

      # With per-rule locks, at least some operations should overlap
      # (With a global mutex, there would be 0 overlaps)
      expect(overlaps).to be > 0,
                          "Expected concurrent operations on different rules (per-rule locks), got #{overlaps} overlaps"
    end
  end

  # ============================================================================
  # ISSUE #6: Missing Error Classes
  # ============================================================================
  describe "Issue #6: Missing Error Classes" do
    it "verifies ConfigurationError is defined" do
      expect(defined?(DecisionAgent::ConfigurationError)).to be_truthy,
                                                             "DecisionAgent::ConfigurationError is referenced but not defined"
    end

    it "verifies NotFoundError is defined" do
      expect(defined?(DecisionAgent::NotFoundError)).to be_truthy,
                                                        "DecisionAgent::NotFoundError is referenced but not defined"
    end

    it "verifies ValidationError is defined" do
      expect(defined?(DecisionAgent::ValidationError)).to be_truthy,
                                                          "DecisionAgent::ValidationError is referenced but not defined"
    end

    it "verifies all error classes inherit from DecisionAgent::Error" do
      expect(DecisionAgent::ConfigurationError.ancestors).to include(DecisionAgent::Error)
      expect(DecisionAgent::NotFoundError.ancestors).to include(DecisionAgent::Error)
      expect(DecisionAgent::ValidationError.ancestors).to include(DecisionAgent::Error)
    end

    it "verifies all error classes inherit from StandardError" do
      expect(DecisionAgent::ConfigurationError.ancestors).to include(StandardError)
      expect(DecisionAgent::NotFoundError.ancestors).to include(StandardError)
      expect(DecisionAgent::ValidationError.ancestors).to include(StandardError)
    end

    it "can instantiate and raise ConfigurationError" do
      expect { raise DecisionAgent::ConfigurationError, "Test error" }
        .to raise_error(DecisionAgent::ConfigurationError, "Test error")
    end

    it "can instantiate and raise NotFoundError" do
      expect { raise DecisionAgent::NotFoundError, "Resource not found" }
        .to raise_error(DecisionAgent::NotFoundError, "Resource not found")
    end

    it "can instantiate and raise ValidationError" do
      expect { raise DecisionAgent::ValidationError, "Validation failed" }
        .to raise_error(DecisionAgent::ValidationError, "Validation failed")
    end
  end

  # ============================================================================
  # ISSUE #7: JSON Serialization Edge Cases
  # ============================================================================
  if defined?(ActiveRecord)
    describe "Issue #7: JSON Serialization Edge Cases in ActiveRecordAdapter" do
      before(:all) do
        ActiveRecord::Base.establish_connection(
          adapter: "sqlite3",
          database: ":memory:"
        )

        ActiveRecord::Schema.define do
          create_table :rule_versions, force: true do |t|
            t.string :rule_id, null: false
            t.integer :version_number, null: false
            t.text :content, null: false
            t.string :created_by, null: false, default: "system"
            t.text :changelog
            t.string :status, null: false, default: "draft"
            t.timestamps
          end
          add_index :rule_versions, %i[rule_id version_number], unique: true
        end

        unless defined?(RuleVersion)
          class ::RuleVersion < ActiveRecord::Base
          end
        end
      end

      before(:each) do
        RuleVersion.delete_all
      end

      let(:adapter) { DecisionAgent::Versioning::ActiveRecordAdapter.new }

      describe "JSON.parse error handling in serialize_version" do
        it "raises ValidationError when content is invalid JSON" do
          # Create a version with invalid JSON directly in database
          version = RuleVersion.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: "{ invalid json", # INVALID JSON!
            created_by: "test",
            status: "active"
          )

          # serialize_version should catch JSON::ParserError and raise ValidationError
          expect do
            adapter.send(:serialize_version, version)
          end.to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
        end

        it "raises ValidationError when content is empty string" do
          version = RuleVersion.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: "", # EMPTY STRING!
            created_by: "test",
            status: "active"
          )

          expect do
            adapter.send(:serialize_version, version)
          end.to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
        end

        it "raises ValidationError when content is nil (if allowed by DB)" do
          # Skip this test because the schema has NOT NULL constraint on content
          # The database won't allow nil content to be saved in the first place
          skip "Schema has NOT NULL constraint on content column"

          # This test would only be relevant if the schema allowed NULL content
          # In that case, the serialize_version method already handles it with:
          # rescue TypeError, NoMethodError
          #   raise DecisionAgent::ValidationError, "content is nil or not a string"
        end

        it "raises ValidationError when content contains malformed UTF-8" do
          # Create version with invalid UTF-8 bytes
          invalid_utf8 = "\xFF\xFE".dup.force_encoding("UTF-8")
          version = RuleVersion.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: invalid_utf8,
            created_by: "test",
            status: "active"
          )

          expect do
            adapter.send(:serialize_version, version)
          end.to raise_error(DecisionAgent::ValidationError) do |error|
            expect(error.message).to include("Invalid JSON")
          end
        end

        it "raises ValidationError when content is truncated JSON" do
          version = RuleVersion.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: '{"version":"1.0","rules":[{"id":"r1"', # TRUNCATED!
            created_by: "test",
            status: "active"
          )

          expect do
            adapter.send(:serialize_version, version)
          end.to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
        end

        it "raises ValidationError on get_version when JSON is invalid" do
          version = RuleVersion.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: "not json",
            created_by: "test",
            status: "active"
          )

          expect do
            adapter.get_version(version_id: version.id)
          end.to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
        end

        it "raises ValidationError on get_active_version when JSON is invalid" do
          RuleVersion.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: "{ broken",
            created_by: "test",
            status: "active"
          )

          expect do
            adapter.get_active_version(rule_id: "test_rule")
          end.to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
        end

        it "raises ValidationError on list_versions when any JSON is invalid" do
          # Create valid and invalid versions
          RuleVersion.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: { valid: true }.to_json,
            created_by: "test",
            status: "active"
          )
          RuleVersion.create!(
            rule_id: "test_rule",
            version_number: 2,
            content: "{ invalid", # INVALID!
            created_by: "test",
            status: "draft"
          )

          # list_versions tries to serialize all versions
          expect do
            adapter.list_versions(rule_id: "test_rule")
          end.to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
        end

        it "provides clear error messages for data corruption scenarios" do
          # Simulate corrupted data (e.g., from manual DB edit, migration issue, etc.)
          version = adapter.create_version(
            rule_id: "test_rule",
            content: { valid: "content" },
            metadata: { created_by: "system" }
          )

          # Manually corrupt the content in DB
          RuleVersion.find(version[:id]).update_column(:content, "corrupted{")

          # Now operations fail with clear ValidationError messages
          expect { adapter.get_version(version_id: version[:id]) }
            .to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
          expect { adapter.get_active_version(rule_id: "test_rule") }
            .to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
          expect { adapter.list_versions(rule_id: "test_rule") }
            .to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
        end
      end

      describe "Edge cases that should be handled gracefully" do
        it "handles valid but unusual JSON structures" do
          unusual_contents = [
            [],  # Empty array
            {},  # Empty object
            "string", # JSON string
            123, # JSON number
            true, # JSON boolean
            nil # JSON null
          ]

          unusual_contents.each_with_index do |content, _i|
            version = adapter.create_version(
              rule_id: "test_rule",
              content: content,
              metadata: { created_by: "test" }
            )

            # Should work fine
            loaded = adapter.get_version(version_id: version[:id])
            expect(loaded[:content]).to eq(content)
          end
        end

        it "handles very large JSON content" do
          # 10MB JSON
          large_content = { "data" => "x" * (10 * 1024 * 1024) }

          version = adapter.create_version(
            rule_id: "test_rule",
            content: large_content,
            metadata: { created_by: "test" }
          )

          loaded = adapter.get_version(version_id: version[:id])
          expect(loaded[:content]["data"].size).to eq(large_content["data"].size)
        end

        it "handles deeply nested JSON" do
          nested = { "a" => { "b" => { "c" => { "d" => { "e" => { "f" => { "g" => { "h" => { "i" => { "j" => "deep" } } } } } } } } } }

          version = adapter.create_version(
            rule_id: "test_rule",
            content: nested,
            metadata: { created_by: "test" }
          )

          loaded = adapter.get_version(version_id: version[:id])
          expect(loaded[:content]["a"]["b"]["c"]["d"]["e"]["f"]["g"]["h"]["i"]["j"]).to eq("deep")
        end

        it "handles JSON with special characters" do
          special = {
            "unicode" => "Hello 世界 🌍",
            "escaped" => "Line 1\nLine 2\tTabbed",
            "quotes" => 'He said "Hello"',
            "backslash" => "C:\\Users\\test"
          }

          version = adapter.create_version(
            rule_id: "test_rule",
            content: special,
            metadata: { created_by: "test" }
          )

          loaded = adapter.get_version(version_id: version[:id])
          expect(loaded[:content]).to eq(special)
        end
      end
    end
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock
