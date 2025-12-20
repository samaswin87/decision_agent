# frozen_string_literal: true
# encoding: UTF-8

require "spec_helper"

# Only run these tests if ActiveRecord is available
if defined?(ActiveRecord)
  RSpec.describe "ActiveRecordAdapter Thread-Safety" do
    # Setup in-memory SQLite database for testing
    before(:all) do
      ActiveRecord::Base.establish_connection(
        adapter: "sqlite3",
        database: ":memory:"
      )

      # Create the schema
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
        add_index :rule_versions, [:rule_id, :status]
      end

      # Define RuleVersion model if not already defined
      unless defined?(::RuleVersion)
        class ::RuleVersion < ActiveRecord::Base
          validates :rule_id, presence: true
          validates :version_number, presence: true, uniqueness: { scope: :rule_id }
          validates :content, presence: true
          validates :status, inclusion: { in: %w[draft active archived] }
          validates :created_by, presence: true

          scope :active, -> { where(status: "active") }
          scope :for_rule, ->(rule_id) { where(rule_id: rule_id).order(version_number: :desc) }
          scope :latest, -> { order(version_number: :desc).limit(1) }

          before_create :set_next_version_number

          def parsed_content
            JSON.parse(content, symbolize_names: true)
          rescue JSON::ParserError
            {}
          end

          def content_hash=(hash)
            self.content = hash.to_json
          end

          def activate!
            transaction do
              self.class.where(rule_id: rule_id, status: "active")
                        .where.not(id: id)
                        .update_all(status: "archived")
              update!(status: "active")
            end
          end

          private

          def set_next_version_number
            return if version_number.present?

            # Use pessimistic locking to prevent race conditions
            last_version = self.class.where(rule_id: rule_id)
                                     .order(version_number: :desc)
                                     .lock
                                     .first

            self.version_number = last_version ? last_version.version_number + 1 : 1
          end
        end
      end
    end

    before(:each) do
      RuleVersion.delete_all
    end

    let(:adapter) { DecisionAgent::Versioning::ActiveRecordAdapter.new }
    let(:rule_id) { "concurrent_test_rule" }
    let(:rule_content) do
      {
        version: "1.0",
        ruleset: "test_rules",
        rules: [
          {
            id: "test_rule",
            if: { field: "amount", op: "gt", value: 100 },
            then: { decision: "approve", weight: 0.8, reason: "Test" }
          }
        ]
      }
    end

    describe "concurrent version creation" do
      it "prevents duplicate version numbers with pessimistic locking" do
        thread_count = 20
        threads = []
        results = []
        mutex = Mutex.new

        # Spawn multiple threads creating versions concurrently
        thread_count.times do |i|
          threads << Thread.new do
            version = adapter.create_version(
              rule_id: rule_id,
              content: rule_content.merge(thread_id: i),
              metadata: { created_by: "thread_#{i}" }
            )
            mutex.synchronize { results << version }
          end
        end

        threads.each(&:join)

        # All versions should be created successfully
        expect(results.size).to eq(thread_count)

        # Version numbers must be unique and sequential
        version_numbers = results.map { |v| v[:version_number] }.sort
        expect(version_numbers).to eq((1..thread_count).to_a)

        # Verify in database
        db_versions = RuleVersion.where(rule_id: rule_id).order(:version_number)
        expect(db_versions.count).to eq(thread_count)
        expect(db_versions.pluck(:version_number)).to eq((1..thread_count).to_a)
      end

      it "handles high concurrency (100 threads)" do
        thread_count = 100
        threads = []
        errors = []
        mutex = Mutex.new

        thread_count.times do |i|
          threads << Thread.new do
            begin
              adapter.create_version(
                rule_id: rule_id,
                content: rule_content,
                metadata: { created_by: "thread_#{i}" }
              )
            rescue => e
              mutex.synchronize { errors << e }
            end
          end
        end

        threads.each(&:join)

        # Should have no errors
        expect(errors).to be_empty

        # All versions created with unique version numbers
        versions = RuleVersion.where(rule_id: rule_id).order(:version_number)
        expect(versions.count).to eq(thread_count)
        expect(versions.pluck(:version_number)).to eq((1..thread_count).to_a)
      end

      it "maintains unique constraint even under extreme concurrency" do
        # This test verifies the database-level unique constraint catches any edge cases
        thread_count = 50
        threads = []
        successes = []
        failures = []
        mutex = Mutex.new

        thread_count.times do |i|
          threads << Thread.new do
            begin
              version = adapter.create_version(
                rule_id: rule_id,
                content: rule_content,
                metadata: { created_by: "thread_#{i}" }
              )
              mutex.synchronize { successes << version }
            rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
              # These errors are acceptable - they mean the unique constraint caught duplicates
              mutex.synchronize { failures << e }
            end
          end
        end

        threads.each(&:join)

        # Either all succeed with unique versions, or some fail due to constraint
        total_attempts = successes.size + failures.size
        expect(total_attempts).to eq(thread_count)

        # All successful versions must have unique version numbers
        version_numbers = successes.map { |v| v[:version_number] }
        expect(version_numbers.uniq.size).to eq(version_numbers.size)

        # Database should have only unique versions
        db_versions = RuleVersion.where(rule_id: rule_id)
        db_version_numbers = db_versions.pluck(:version_number).sort
        expect(db_version_numbers).to eq(db_version_numbers.uniq)
      end
    end

    describe "concurrent read and write operations" do
      it "allows safe concurrent reads during writes" do
        # Create initial version
        adapter.create_version(
          rule_id: rule_id,
          content: rule_content,
          metadata: { created_by: "setup" }
        )

        threads = []
        read_results = []
        write_results = []
        read_mutex = Mutex.new
        write_mutex = Mutex.new

        # Mix of readers and writers
        20.times do |i|
          if i % 3 == 0
            # Write thread
            threads << Thread.new do
              version = adapter.create_version(
                rule_id: rule_id,
                content: rule_content,
                metadata: { created_by: "writer_#{i}" }
              )
              write_mutex.synchronize { write_results << version }
            end
          else
            # Read thread
            threads << Thread.new do
              versions = adapter.list_versions(rule_id: rule_id)
              read_mutex.synchronize { read_results << versions }
            end
          end
        end

        threads.each(&:join)

        # Readers should never see corrupted data
        read_results.each do |versions|
          expect(versions).to be_an(Array)
          versions.each do |v|
            expect(v[:version_number]).to be > 0
            expect(v[:rule_id]).to eq(rule_id)
          end
        end

        # Writers should create valid sequential versions
        write_version_numbers = write_results.map { |v| v[:version_number] }.sort
        expect(write_version_numbers.first).to eq(2) # First write creates version 2
      end
    end

    describe "status updates during concurrent creation" do
      it "ensures only one active version at a time" do
        thread_count = 10
        threads = []

        thread_count.times do |i|
          threads << Thread.new do
            adapter.create_version(
              rule_id: rule_id,
              content: rule_content,
              metadata: { created_by: "thread_#{i}", status: "active" }
            )
          end
        end

        threads.each(&:join)

        # Only the last created version should be active
        active_versions = RuleVersion.where(rule_id: rule_id, status: "active")
        expect(active_versions.count).to eq(1)

        # The active version should be the last one
        expect(active_versions.first.version_number).to eq(thread_count)

        # All others should be archived
        archived_versions = RuleVersion.where(rule_id: rule_id, status: "archived")
        expect(archived_versions.count).to eq(thread_count - 1)
      end
    end

    describe "multiple rules concurrently" do
      it "handles version creation for different rules in parallel" do
        rule_ids = (1..10).map { |i| "rule_#{i}" }
        threads = []
        results = {}
        mutex = Mutex.new

        rule_ids.each do |rid|
          5.times do |version_index|
            threads << Thread.new do
              version = adapter.create_version(
                rule_id: rid,
                content: rule_content,
                metadata: { created_by: "creator_#{version_index}" }
              )
              mutex.synchronize do
                results[rid] ||= []
                results[rid] << version
              end
            end
          end
        end

        threads.each(&:join)

        # Each rule should have 5 versions
        rule_ids.each do |rid|
          expect(results[rid].size).to eq(5)
          version_numbers = results[rid].map { |v| v[:version_number] }.sort
          expect(version_numbers).to eq([1, 2, 3, 4, 5])
        end
      end
    end

    describe "transaction rollback on errors" do
      it "rolls back version creation if there's an error" do
        # Create a scenario where create might fail
        allow(RuleVersion).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(RuleVersion.new))

        expect {
          adapter.create_version(
            rule_id: rule_id,
            content: rule_content
          )
        }.to raise_error(ActiveRecord::RecordInvalid)

        # No versions should be created
        expect(RuleVersion.where(rule_id: rule_id).count).to eq(0)
      end
    end

    describe "RuleVersion model callback thread safety" do
      it "safely calculates version numbers when using model directly" do
        thread_count = 30
        threads = []
        errors = []
        mutex = Mutex.new

        thread_count.times do |i|
          threads << Thread.new do
            begin
              RuleVersion.create!(
                rule_id: rule_id,
                content: rule_content.to_json,
                created_by: "thread_#{i}",
                status: "draft"
              )
            rescue => e
              mutex.synchronize { errors << e }
            end
          end
        end

        threads.each(&:join)

        # Should have minimal or no errors (unique constraint might catch some)
        # The key is version numbers should be unique
        versions = RuleVersion.where(rule_id: rule_id).order(:version_number)
        version_numbers = versions.pluck(:version_number)

        # All version numbers should be unique
        expect(version_numbers.uniq.size).to eq(version_numbers.size)
      end
    end

    describe "concurrent activate_version" do
      it "prevents multiple active versions with pessimistic locking" do
        # Create 5 versions
        versions = 5.times.map do |i|
          adapter.create_version(
            rule_id: rule_id,
            content: rule_content.merge(version: "#{i + 1}.0"),
            metadata: { created_by: "setup_#{i}" }
          )
        end

        # Try to activate different versions concurrently
        thread_count = 10
        threads = []
        activated_versions = []
        mutex = Mutex.new

        thread_count.times do |i|
          threads << Thread.new do
            # Each thread tries to activate a different version (cycling through versions)
            version_to_activate = versions[i % versions.size]
            activated = adapter.activate_version(version_id: version_to_activate[:id])
            mutex.synchronize { activated_versions << activated }
          end
        end

        threads.each(&:join)

        # CRITICAL: Only ONE version should be active at the end
        active_versions = RuleVersion.where(rule_id: rule_id, status: "active")
        expect(active_versions.count).to eq(1),
          "Expected exactly 1 active version, but found #{active_versions.count}: #{active_versions.pluck(:version_number)}"

        # All other versions should be archived
        archived_versions = RuleVersion.where(rule_id: rule_id, status: "archived")
        expect(archived_versions.count).to eq(versions.size - 1)

        # The active version should be one of the versions we tried to activate
        active_version_id = active_versions.first.id
        expect(versions.map { |v| v[:id] }).to include(active_version_id)
      end

      it "handles race condition when two threads activate different versions simultaneously" do
        # Create 3 versions
        v1 = adapter.create_version(
          rule_id: rule_id,
          content: rule_content.merge(version: "1.0"),
          metadata: { created_by: "setup" }
        )
        v2 = adapter.create_version(
          rule_id: rule_id,
          content: rule_content.merge(version: "2.0"),
          metadata: { created_by: "setup" }
        )
        adapter.create_version(
          rule_id: rule_id,
          content: rule_content.merge(version: "3.0"),
          metadata: { created_by: "setup" }
        )

        # At this point v3 is active, v1 and v2 are archived

        # Spawn two threads trying to activate v1 and v2 at the same time
        barrier = Concurrent::CyclicBarrier.new(2) rescue Thread::Barrier.new(2) rescue nil
        threads = []

        if barrier
          threads << Thread.new do
            barrier.wait
            adapter.activate_version(version_id: v1[:id])
          end

          threads << Thread.new do
            barrier.wait
            adapter.activate_version(version_id: v2[:id])
          end

          threads.each(&:join)
        else
          # Fallback without barrier - still tests thread safety
          t1 = Thread.new { adapter.activate_version(version_id: v1[:id]) }
          t2 = Thread.new { adapter.activate_version(version_id: v2[:id]) }
          t1.join
          t2.join
        end

        # CRITICAL: Only ONE version should be active
        active_count = RuleVersion.where(rule_id: rule_id, status: "active").count
        expect(active_count).to eq(1),
          "Race condition detected: #{active_count} active versions found instead of 1"
      end

      it "maintains consistency across 100 concurrent activation attempts" do
        # Create 10 versions
        versions = 10.times.map do |i|
          adapter.create_version(
            rule_id: rule_id,
            content: rule_content.merge(version: "#{i + 1}.0"),
            metadata: { created_by: "setup_#{i}" }
          )
        end

        # 100 threads each randomly activating versions
        threads = 100.times.map do
          Thread.new do
            random_version = versions.sample
            adapter.activate_version(version_id: random_version[:id])
            sleep(rand * 0.01) # Small random delay to increase race condition likelihood
          end
        end

        threads.each(&:join)

        # Check consistency
        active_versions = RuleVersion.where(rule_id: rule_id, status: "active")
        expect(active_versions.count).to eq(1),
          "Consistency violation: #{active_versions.count} active versions after concurrent activations"

        # All versions should still exist
        expect(RuleVersion.where(rule_id: rule_id).count).to eq(10)
      end
    end
  end
else
  RSpec.describe "ActiveRecordAdapter Thread-Safety" do
    it "skips tests when ActiveRecord is not available" do
      skip "ActiveRecord is not loaded"
    end
  end
end
