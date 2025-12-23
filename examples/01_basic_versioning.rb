#!/usr/bin/env ruby
# frozen_string_literal: true
# Example 1: Basic Versioning with File Storage
#
# This example demonstrates the core versioning features using
# the default file storage adapter (no database required).

require 'bundler/setup'
require 'decision_agent'

puts "=" * 60
puts "DecisionAgent - Basic Versioning Example"
puts "=" * 60
puts

# Create a version manager (uses file storage by default)
manager = DecisionAgent::Versioning::VersionManager.new

# Define an approval rule
approval_rule = {
  version: "1.0",
  ruleset: "loan_approval",
  rules: [
    {
      id: "small_loan_auto_approve",
      if: {
        all: [
          { field: "loan_amount", op: "lt", value: 5000 },
          { field: "credit_score", op: "gte", value: 650 }
        ]
      },
      then: {
        decision: "approve",
        weight: 0.85,
        reason: "Small loan with good credit"
      }
    },
    {
      id: "large_loan_review",
      if: { field: "loan_amount", op: "gte", value: 50000 },
      then: {
        decision: "manual_review",
        weight: 0.95,
        reason: "Large loan requires manual review"
      }
    }
  ]
}

# ========================================
# 1. Create Initial Version
# ========================================
puts "1. Creating initial version..."
v1 = manager.save_version(
  rule_id: "loan_approval_001",
  rule_content: approval_rule,
  created_by: "product_team",
  changelog: "Initial loan approval rules"
)

puts "   ✓ Version #{v1[:version_number]} created"
puts "   - Created by: #{v1[:created_by]}"
puts "   - Status: #{v1[:status]}"
puts "   - Rules count: #{v1[:content][:rules].length}"
puts

# ========================================
# 2. Update Rules (Change Threshold)
# ========================================
puts "2. Updating credit score threshold..."
approval_rule[:rules][0][:if][:all][1][:value] = 700  # Increase to 700

v2 = manager.save_version(
  rule_id: "loan_approval_001",
  rule_content: approval_rule,
  created_by: "risk_team",
  changelog: "Increased minimum credit score to 700"
)

puts "   ✓ Version #{v2[:version_number]} created"
puts "   - New credit score minimum: #{v2[:content][:rules][0][:if][:all][1][:value]}"
puts

# ========================================
# 3. Add New Rule
# ========================================
puts "3. Adding fraud detection rule..."
approval_rule[:rules] << {
  id: "fraud_check",
  if: { field: "fraud_risk_score", op: "gt", value: 0.8 },
  then: {
    decision: "reject",
    weight: 1.0,
    reason: "High fraud risk detected"
  }
}

v3 = manager.save_version(
  rule_id: "loan_approval_001",
  rule_content: approval_rule,
  created_by: "security_team",
  changelog: "Added fraud detection rule"
)

puts "   ✓ Version #{v3[:version_number]} created"
puts "   - Total rules now: #{v3[:content][:rules].length}"
puts

# ========================================
# 4. List All Versions
# ========================================
puts "4. Listing all versions..."
versions = manager.get_versions(rule_id: "loan_approval_001")

versions.each do |version|
  status_emoji = version[:status] == 'active' ? '✓' : '○'
  puts "   #{status_emoji} v#{version[:version_number]} - #{version[:changelog]} (by #{version[:created_by]})"
end
puts

# ========================================
# 5. Compare Versions
# ========================================
puts "5. Comparing v1 and v3..."
comparison = manager.compare(
  version_id_1: v1[:id],
  version_id_2: v3[:id]
)

puts "   Changes:"
puts "   - Added: #{comparison[:differences][:added].length} items"
puts "   - Removed: #{comparison[:differences][:removed].length} items"
puts "   - Changed: #{comparison[:differences][:changed].keys.join(', ')}"
puts

# ========================================
# 6. Rollback to Previous Version
# ========================================
puts "6. Rolling back to version 2..."
rolled_back = manager.rollback(
  version_id: v2[:id],
  performed_by: "ops_team"
)

puts "   ✓ Rolled back successfully"
puts "   - Now active: Version #{rolled_back[:version_number]}"
puts "   - Rules count: #{rolled_back[:content][:rules].length}"
puts

# ========================================
# 7. Get Version History
# ========================================
puts "7. Getting complete history..."
history = manager.get_history(rule_id: "loan_approval_001")

puts "   Total versions: #{history[:total_versions]}"
puts "   Active version: v#{history[:active_version][:version_number]}"
puts "   First created: #{history[:created_at]}"
puts "   Last updated: #{history[:updated_at]}"
puts

# ========================================
# 8. Get Active Version
# ========================================
puts "8. Retrieving active version..."
active = manager.get_active_version(rule_id: "loan_approval_001")

puts "   Active version: v#{active[:version_number]}"
puts "   Status: #{active[:status]}"
puts "   Changelog: #{active[:changelog]}"
puts

puts "=" * 60
puts "Example completed! Check ./versions/ directory for stored versions."
puts "=" * 60
