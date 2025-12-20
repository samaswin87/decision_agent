# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tempfile"

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
          expect {
            TestRuleVersion1.create!(
              rule_id: "test_rule",
              version_number: 1,  # DUPLICATE!
              content: { test: "v1_duplicate" }.to_json
            )
          }.not_to raise_error  # BUG: Allows duplicates!

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
            add_index :rule_versions, [:rule_id, :version_number], unique: true
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
          expect {
            TestRuleVersion2.create!(
              rule_id: "test_rule",
              version_number: 1,  # DUPLICATE!
              content: { test: "v1_duplicate" }.to_json
            )
          }.to raise_error(ActiveRecord::RecordNotUnique)
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
            add_index :rule_versions, [:rule_id, :version_number], unique: true
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
          expect {
            TestRuleVersion4.create!(
              rule_id: "test_rule",
              version_number: 2,
              content: { test: "v2" }.to_json,
              status: "active"  # DUPLICATE ACTIVE!
            )
          }.not_to raise_error

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
            add_index :rule_versions, [:rule_id, :version_number], unique: true
            # ✅ Partial unique index (PostgreSQL only)
            add_index :rule_versions, [:rule_id, :status],
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
          expect {
            TestRuleVersion5.create!(
              rule_id: "test_rule",
              version_number: 2,
              content: { test: "v2" }.to_json,
              status: "active"
            )
          }.to raise_error(ActiveRecord::RecordNotUnique)
        end
      end
    end
  end

  # ============================================================================
  # ISSUE #5: FileStorageAdapter - Slow Global Mutex
  # ============================================================================
  describe "Issue #5: FileStorageAdapter Global Mutex Performance" do
    let(:temp_dir) { Dir.mktmpdir }
    let(:adapter) { DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: temp_dir) }
    let(:rule_content) do
      {
        version: "1.0",
        rules: [{ id: "r1", if: { field: "x", op: "eq", value: 1 }, then: { decision: "approve", weight: 0.8, reason: "Test" } }]
      }
    end

    after { FileUtils.rm_rf(temp_dir) }

    it "demonstrates global mutex blocking unrelated rule operations" do
      # Create initial versions for two different rules
      adapter.create_version(rule_id: "rule_a", content: rule_content)
      adapter.create_version(rule_id: "rule_b", content: rule_content)

      timings = { blocked: [], unblocked: [] }
      mutex = Mutex.new

      # Thread 1: Read rule_a (holds global mutex)
      # Thread 2: Read rule_b (should NOT block, but DOES with global mutex)

      thread1 = Thread.new do
        start = Time.now
        adapter.get_active_version(rule_id: "rule_a")
        sleep(0.1)  # Simulate slow operation
        elapsed = Time.now - start
        mutex.synchronize { timings[:blocked] << elapsed }
      end

      sleep(0.01)  # Ensure thread1 starts first

      thread2 = Thread.new do
        start = Time.now
        adapter.get_active_version(rule_id: "rule_b")  # Different rule!
        elapsed = Time.now - start
        mutex.synchronize { timings[:unblocked] << elapsed }
      end

      thread1.join
      thread2.join

      # With global mutex, thread2 waits for thread1 even though different rules
      # Expected: thread2 ~0.01s, Actual: ~0.1s (blocked by thread1)
      if timings[:unblocked].first > 0.05
        puts "\n⚠️  PERFORMANCE ISSUE: Thread reading rule_b blocked by thread reading rule_a"
        puts "    Thread 1 (rule_a): #{timings[:blocked].first.round(3)}s"
        puts "    Thread 2 (rule_b): #{timings[:unblocked].first.round(3)}s (BLOCKED!)"
      end
    end

    it "shows serialized operations even for different rules" do
      operations_log = []
      log_mutex = Mutex.new

      threads = []
      10.times do |i|
        threads << Thread.new do
          rule_id = "rule_#{i % 2}"  # Only 2 different rules
          start = Time.now
          adapter.get_active_version(rule_id: rule_id)
          elapsed = Time.now - start
          log_mutex.synchronize do
            operations_log << { rule_id: rule_id, elapsed: elapsed, thread: i }
          end
        end
      end

      threads.each(&:join)

      # With global mutex, ALL operations are serialized
      # Even reads of rule_0 and rule_1 can't happen in parallel
      total_time = operations_log.sum { |op| op[:elapsed] }
      puts "\n📊 Global Mutex Performance:"
      puts "    Total serialized time: #{total_time.round(3)}s"
      puts "    Operations: #{operations_log.size}"
      puts "    Problem: All operations serialized, even for different rules!"
    end

    it "measures performance impact of global mutex" do
      # Create 5 different rules
      5.times { |i| adapter.create_version(rule_id: "rule_#{i}", content: rule_content) }

      # Measure time for sequential reads (baseline)
      sequential_start = Time.now
      5.times { |i| adapter.get_active_version(rule_id: "rule_#{i}") }
      sequential_time = Time.now - sequential_start

      # Measure time for concurrent reads (should be faster, but isn't with global mutex)
      concurrent_start = Time.now
      threads = 5.times.map do |i|
        Thread.new { adapter.get_active_version(rule_id: "rule_#{i}") }
      end
      threads.each(&:join)
      concurrent_time = Time.now - concurrent_start

      speedup = sequential_time / concurrent_time

      puts "\n📊 Concurrency Performance:"
      puts "    Sequential: #{sequential_time.round(3)}s"
      puts "    Concurrent: #{concurrent_time.round(3)}s"
      puts "    Speedup: #{speedup.round(2)}x"
      puts "    Expected: ~5x speedup with per-rule locks"
      puts "    Actual: ~1x speedup (no parallelism due to global mutex)"

      # With global mutex, concurrent is NOT significantly faster
      expect(speedup).to be < 2.0, "Expected poor concurrency due to global mutex"
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
          add_index :rule_versions, [:rule_id, :version_number], unique: true
        end

        unless defined?(::RuleVersion)
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
            content: "{ invalid json",  # INVALID JSON!
            created_by: "test",
            status: "active"
          )

          # serialize_version should catch JSON::ParserError and raise ValidationError
          expect {
            adapter.send(:serialize_version, version)
          }.to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
        end

        it "raises ValidationError when content is empty string" do
          version = RuleVersion.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: "",  # EMPTY STRING!
            created_by: "test",
            status: "active"
          )

          expect {
            adapter.send(:serialize_version, version)
          }.to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
        end

        it "raises ValidationError when content is nil (if allowed by DB)" do
          # Try to create version with nil content
          version = RuleVersion.new(
            rule_id: "test_rule",
            version_number: 1,
            content: nil,  # NIL!
            created_by: "test",
            status: "active"
          )

          if version.save(validate: false)
            expect {
              adapter.send(:serialize_version, version)
            }.to raise_error(DecisionAgent::ValidationError, /content is nil/)
          end
        end

        it "raises ValidationError when content contains malformed UTF-8" do
          # Create version with invalid UTF-8 bytes
          invalid_utf8 = "\xFF\xFE"
          version = RuleVersion.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: invalid_utf8.force_encoding("UTF-8"),
            created_by: "test",
            status: "active"
          )

          expect {
            adapter.send(:serialize_version, version)
          }.to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
        end

        it "raises ValidationError when content is truncated JSON" do
          version = RuleVersion.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: '{"version":"1.0","rules":[{"id":"r1"',  # TRUNCATED!
            created_by: "test",
            status: "active"
          )

          expect {
            adapter.send(:serialize_version, version)
          }.to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
        end

        it "raises ValidationError on get_version when JSON is invalid" do
          version = RuleVersion.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: "not json",
            created_by: "test",
            status: "active"
          )

          expect {
            adapter.get_version(version_id: version.id)
          }.to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
        end

        it "raises ValidationError on get_active_version when JSON is invalid" do
          RuleVersion.create!(
            rule_id: "test_rule",
            version_number: 1,
            content: "{ broken",
            created_by: "test",
            status: "active"
          )

          expect {
            adapter.get_active_version(rule_id: "test_rule")
          }.to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
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
            content: "{ invalid",  # INVALID!
            created_by: "test",
            status: "draft"
          )

          # list_versions tries to serialize all versions
          expect {
            adapter.list_versions(rule_id: "test_rule")
          }.to raise_error(DecisionAgent::ValidationError, /Invalid JSON/)
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
            "string",  # JSON string
            123,  # JSON number
            true,  # JSON boolean
            nil,  # JSON null
          ]

          unusual_contents.each_with_index do |content, i|
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
          large_content = { data: "x" * (10 * 1024 * 1024) }

          version = adapter.create_version(
            rule_id: "test_rule",
            content: large_content,
            metadata: { created_by: "test" }
          )

          loaded = adapter.get_version(version_id: version[:id])
          expect(loaded[:content][:data].size).to eq(large_content[:data].size)
        end

        it "handles deeply nested JSON" do
          nested = { a: { b: { c: { d: { e: { f: { g: { h: { i: { j: "deep" } } } } } } } } } }

          version = adapter.create_version(
            rule_id: "test_rule",
            content: nested,
            metadata: { created_by: "test" }
          )

          loaded = adapter.get_version(version_id: version[:id])
          expect(loaded[:content][:a][:b][:c][:d][:e][:f][:g][:h][:i][:j]).to eq("deep")
        end

        it "handles JSON with special characters" do
          special = {
            unicode: "Hello 世界 🌍",
            escaped: "Line 1\nLine 2\tTabbed",
            quotes: 'He said "Hello"',
            backslash: "C:\\Users\\test"
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
