#!/usr/bin/env ruby
# frozen_string_literal: true

# This script demonstrates the race condition fix in ActiveRecordAdapter
# It requires ActiveRecord and SQLite3 to be installed

require "bundler/setup"
require "active_record"
require "decision_agent"

puts "=" * 80
puts "RACE CONDITION DEMONSTRATION - ActiveRecordAdapter"
puts "=" * 80
puts

# Setup in-memory database
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

# Create schema
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

# Define RuleVersion model (with the fix)
class RuleVersion < ActiveRecord::Base
  validates :rule_id, presence: true
  validates :version_number, presence: true, uniqueness: { scope: :rule_id }
  validates :content, presence: true
  validates :status, inclusion: { in: %w[draft active archived] }
  validates :created_by, presence: true

  before_create :set_next_version_number

  private

  def set_next_version_number
    return if version_number.present?

    # ✅ WITH FIX: Pessimistic locking prevents race conditions
    last_version = self.class.where(rule_id: rule_id)
                             .order(version_number: :desc)
                             .lock  # This line prevents the race condition!
                             .first

    self.version_number = last_version ? last_version.version_number + 1 : 1
  end
end

# Test rule content
RULE_CONTENT = {
  version: "1.0",
  ruleset: "demo_rules",
  rules: [
    {
      id: "demo_rule",
      if: { field: "amount", op: "gt", value: 100 },
      then: { decision: "approve", weight: 0.8, reason: "Demo rule" }
    }
  ]
}.freeze

puts "Setting up ActiveRecordAdapter..."
adapter = DecisionAgent::Versioning::ActiveRecordAdapter.new
rule_id = "concurrent_demo_rule"

puts "Creating versions concurrently with #{20} threads..."
puts

threads = []
results = []
mutex = Mutex.new
errors = []

start_time = Time.now

20.times do |i|
  threads << Thread.new do
    begin
      version = adapter.create_version(
        rule_id: rule_id,
        content: RULE_CONTENT,
        metadata: { created_by: "thread_#{i}" }
      )

      mutex.synchronize do
        results << version
        print "."
      end
    rescue => e
      mutex.synchronize do
        errors << { thread: i, error: e }
        print "X"
      end
    end
  end
end

threads.each(&:join)
puts
puts

elapsed = Time.now - start_time

puts "Results:"
puts "--------"
puts "Total threads: 20"
puts "Successful: #{results.size}"
puts "Failed: #{errors.size}"
puts "Time elapsed: #{elapsed.round(3)}s"
puts

if errors.any?
  puts "Errors encountered:"
  errors.each do |err|
    puts "  Thread #{err[:thread]}: #{err[:error].class} - #{err[:error].message}"
  end
  puts
end

# Verify version numbers
version_numbers = results.map { |v| v[:version_number] }.sort
puts "Version numbers created: #{version_numbers.inspect}"
puts

# Check for duplicates
duplicates = version_numbers.select { |v| version_numbers.count(v) > 1 }.uniq
if duplicates.any?
  puts "❌ RACE CONDITION DETECTED! Duplicate version numbers: #{duplicates.inspect}"
else
  puts "✅ NO DUPLICATES! All version numbers are unique."
end
puts

# Verify sequential
expected = (1..results.size).to_a
if version_numbers == expected
  puts "✅ SEQUENTIAL! Version numbers are 1, 2, 3, ..., #{results.size}"
else
  puts "❌ NOT SEQUENTIAL! Expected #{expected.inspect}, got #{version_numbers.inspect}"
end
puts

# Verify database state
db_versions = RuleVersion.where(rule_id: rule_id).order(:version_number)
puts "Database verification:"
puts "  Total versions in DB: #{db_versions.count}"
puts "  Version numbers in DB: #{db_versions.pluck(:version_number).inspect}"
puts "  Active versions: #{RuleVersion.where(rule_id: rule_id, status: 'active').count}"
puts "  Archived versions: #{RuleVersion.where(rule_id: rule_id, status: 'archived').count}"
puts

# Demonstrate the fix
puts "=" * 80
puts "DEMONSTRATION OF THE FIX"
puts "=" * 80
puts

puts "The fix uses pessimistic locking (SELECT ... FOR UPDATE):"
puts

puts "WITHOUT FIX (race condition):"
puts "  Thread A: SELECT version → 5"
puts "  Thread B: SELECT version → 5  (same!)"
puts "  Thread A: INSERT version 6"
puts "  Thread B: INSERT version 6  ❌ DUPLICATE!"
puts

puts "WITH FIX (pessimistic locking):"
puts "  Thread A: SELECT ... FOR UPDATE → 5 (locks row)"
puts "  Thread B: SELECT ... FOR UPDATE → WAITS..."
puts "  Thread A: INSERT version 6"
puts "  Thread A: COMMIT (releases lock)"
puts "  Thread B: SELECT ... FOR UPDATE → 6 (lock acquired)"
puts "  Thread B: INSERT version 7  ✅ CORRECT!"
puts

puts "=" * 80
puts "SUMMARY"
puts "=" * 80
puts

if duplicates.empty? && version_numbers == expected
  puts "✅ All tests passed!"
  puts "✅ No race conditions detected"
  puts "✅ Version numbers are unique and sequential"
  puts "✅ The pessimistic locking fix works correctly"
else
  puts "❌ Issues detected - please review the results above"
end

puts
puts "Demo complete!"
