#!/usr/bin/env ruby
# frozen_string_literal: true
# Example 4: Advanced Versioning Scenarios
#
# This example demonstrates advanced use cases:
# - Multi-environment versioning
# - A/B testing with versions
# - Gradual rollouts
# - Version tagging
# - Batch operations

require 'bundler/setup'
require 'decision_agent'
require 'json'

puts "=" * 70
puts "DecisionAgent - Advanced Versioning Scenarios"
puts "=" * 70
puts

# ========================================
# Scenario 1: Multi-Environment Versioning
# ========================================
puts "Scenario 1: Multi-Environment Versioning"
puts "-" * 70

# Separate version managers for different environments
dev_manager = DecisionAgent::Versioning::VersionManager.new(
  adapter: DecisionAgent::Versioning::FileStorageAdapter.new(
    storage_path: './versions/dev'
  )
)

prod_manager = DecisionAgent::Versioning::VersionManager.new(
  adapter: DecisionAgent::Versioning::FileStorageAdapter.new(
    storage_path: './versions/prod'
  )
)

# Rule content
fraud_rules = {
  version: "1.0",
  ruleset: "fraud_detection",
  rules: [
    {
      id: "high_risk_country",
      if: { field: "country_risk_score", op: "gt", value: 0.7 },
      then: { decision: "flag", weight: 0.85, reason: "High risk country" }
    },
    {
      id: "unusual_amount",
      if: { field: "amount_deviation", op: "gt", value: 3.0 },
      then: { decision: "flag", weight: 0.9, reason: "Unusual transaction amount" }
    }
  ]
}

# Create in dev first
dev_v1 = dev_manager.save_version(
  rule_id: "fraud_rules_001",
  rule_content: fraud_rules,
  created_by: "dev_team",
  changelog: "Testing new fraud rules in dev"
)

puts "✓ Dev version created: v#{dev_v1[:version_number]}"

# Test in dev, then promote to prod
fraud_rules[:rules] << {
  id: "velocity_check",
  if: { field: "transaction_velocity", op: "gt", value: 10 },
  then: { decision: "block", weight: 0.95, reason: "Too many transactions" }
}

dev_v2 = dev_manager.save_version(
  rule_id: "fraud_rules_001",
  rule_content: fraud_rules,
  created_by: "dev_team",
  changelog: "Added velocity check"
)

puts "✓ Dev version updated: v#{dev_v2[:version_number]}"

# After testing, promote to production
prod_v1 = prod_manager.save_version(
  rule_id: "fraud_rules_001",
  rule_content: dev_v2[:content],
  created_by: "ops_team",
  changelog: "Promoted from dev - Added velocity check"
)

puts "✓ Promoted to prod: v#{prod_v1[:version_number]}"
puts

# ========================================
# Scenario 2: A/B Testing with Versions
# ========================================
puts "Scenario 2: A/B Testing with Versions"
puts "-" * 70

manager = DecisionAgent::Versioning::VersionManager.new

# Control version (existing rules)
control_rules = {
  version: "1.0",
  ruleset: "recommendation",
  rules: [
    {
      id: "standard_rec",
      if: { field: "user_activity", op: "gte", value: 5 },
      then: { decision: "recommend", weight: 0.7, reason: "Active user" }
    }
  ]
}

control = manager.save_version(
  rule_id: "recommendation_ab_test",
  rule_content: control_rules,
  created_by: "data_team",
  changelog: "Control group - standard recommendations"
)

# Variant A - more aggressive recommendations
variant_a_rules = control_rules.dup
variant_a_rules[:rules].first[:if][:value] = 3  # Lower threshold
variant_a_rules[:rules].first[:then][:weight] = 0.85

variant_a = manager.save_version(
  rule_id: "recommendation_ab_test_variant_a",
  rule_content: variant_a_rules,
  created_by: "data_team",
  changelog: "Variant A - Lower threshold, higher weight"
)

# Variant B - personalized recommendations
variant_b_rules = control_rules.dup
variant_b_rules[:rules] << {
  id: "personalized_rec",
  if: {
    all: [
      { field: "user_activity", op: "gte", value: 3 },
      { field: "preference_score", op: "gt", value: 0.6 }
    ]
  },
  then: { decision: "recommend", weight: 0.9, reason: "Personalized match" }
}

variant_b = manager.save_version(
  rule_id: "recommendation_ab_test_variant_b",
  rule_content: variant_b_rules,
  created_by: "data_team",
  changelog: "Variant B - Added personalization"
)

puts "✓ A/B Test versions created:"
puts "  - Control: #{control[:id]}"
puts "  - Variant A: #{variant_a[:id]}"
puts "  - Variant B: #{variant_b[:id]}"
puts

# Simulated A/B test assignment
def assign_ab_variant(user_id)
  hash = user_id.hash
  case hash % 3
  when 0 then "control"
  when 1 then "variant_a"
  when 2 then "variant_b"
  end
end

# Usage
user_id = "user_12345"
variant = assign_ab_variant(user_id)
puts "User #{user_id} assigned to: #{variant}"
puts

# ========================================
# Scenario 3: Gradual Rollout with Canary Deployment
# ========================================
puts "Scenario 3: Gradual Rollout (Canary Deployment)"
puts "-" * 70

pricing_rules_v1 = {
  version: "1.0",
  ruleset: "pricing",
  rules: [
    {
      id: "standard_pricing",
      if: { field: "customer_tier", op: "eq", value: "standard" },
      then: { decision: "price_100", weight: 1.0, reason: "Standard pricing" }
    }
  ]
}

# Current production version
current = manager.save_version(
  rule_id: "pricing_001",
  rule_content: pricing_rules_v1,
  created_by: "pricing_team",
  changelog: "Current production pricing"
)

# New version with updated pricing
pricing_rules_v2 = pricing_rules_v1.dup
pricing_rules_v2[:rules].first[:then][:decision] = "price_95"  # Discount

canary = manager.save_version(
  rule_id: "pricing_001_canary",
  rule_content: pricing_rules_v2,
  created_by: "pricing_team",
  changelog: "Canary - 5% discount for standard tier"
)

puts "✓ Canary version created: #{canary[:id]}"

# Simulate gradual rollout
def use_canary_version?(user_id, canary_percentage)
  (user_id.hash % 100) < canary_percentage
end

# Start with 5% of users
canary_percentage = 5
test_users = 20

canary_count = test_users.times.count do |i|
  use_canary_version?("user_#{i}", canary_percentage)
end

puts "✓ Rollout: #{canary_percentage}% canary (#{canary_count}/#{test_users} users)"
puts "  If metrics look good, increase to 10%, 25%, 50%, 100%"
puts

# ========================================
# Scenario 4: Version Tagging and Metadata
# ========================================
puts "Scenario 4: Version Tagging and Metadata"
puts "-" * 70

compliance_rules = {
  version: "1.0",
  ruleset: "compliance",
  metadata: {
    tags: ["production", "compliance", "reviewed"],
    reviewer: "compliance_officer@company.com",
    jira_ticket: "COMP-1234",
    approved_at: Time.now.utc.iso8601
  },
  rules: [
    {
      id: "pii_check",
      if: { field: "contains_pii", op: "eq", value: true },
      then: { decision: "requires_approval", weight: 1.0, reason: "PII data" }
    }
  ]
}

tagged_version = manager.save_version(
  rule_id: "compliance_001",
  rule_content: compliance_rules,
  created_by: "compliance_team",
  changelog: "COMP-1234: Added PII compliance check - Reviewed and approved"
)

puts "✓ Tagged version created with metadata:"
puts "  - Tags: #{compliance_rules[:metadata][:tags].join(', ')}"
puts "  - Reviewer: #{compliance_rules[:metadata][:reviewer]}"
puts "  - Ticket: #{compliance_rules[:metadata][:jira_ticket]}"
puts

# ========================================
# Scenario 5: Batch Version Operations
# ========================================
puts "Scenario 5: Batch Version Operations"
puts "-" * 70

# Update multiple related rulesets together
rulesets = {
  "payment_fraud" => {
    version: "2.0",
    ruleset: "payment_fraud",
    rules: [
      { id: "cvv_check", if: { field: "cvv_match", op: "eq", value: false },
        then: { decision: "decline", weight: 0.9, reason: "CVV mismatch" } }
    ]
  },
  "account_fraud" => {
    version: "2.0",
    ruleset: "account_fraud",
    rules: [
      { id: "ip_check", if: { field: "suspicious_ip", op: "eq", value: true },
        then: { decision: "flag", weight: 0.85, reason: "Suspicious IP" } }
    ]
  },
  "identity_fraud" => {
    version: "2.0",
    ruleset: "identity_fraud",
    rules: [
      { id: "id_verification", if: { field: "id_verified", op: "eq", value: false },
        then: { decision: "require_verification", weight: 0.95, reason: "ID not verified" } }
    ]
  }
}

batch_results = rulesets.map do |name, content|
  manager.save_version(
    rule_id: name,
    rule_content: content,
    created_by: "security_team",
    changelog: "Q1 2025 Security Update - Batch deployment"
  )
end

puts "✓ Batch update completed:"
batch_results.each do |result|
  puts "  - #{result[:rule_id]}: v#{result[:version_number]}"
end
puts

# ========================================
# Scenario 6: Version Comparison for Audit
# ========================================
puts "Scenario 6: Audit Trail and Compliance"
puts "-" * 70

# Get complete history for audit
audit_history = manager.get_history(rule_id: "compliance_001")

puts "Compliance Audit Report:"
puts "  Total versions: #{audit_history[:total_versions]}"
puts "  First created: #{audit_history[:created_at]}"
puts "  Last modified: #{audit_history[:updated_at]}"
puts "  Active version: v#{audit_history[:active_version][:version_number]}"
puts
puts "  Change history:"

audit_history[:versions].each do |v|
  puts "    v#{v[:version_number]} - #{v[:created_at]} - #{v[:created_by]}"
  puts "      #{v[:changelog]}"
end
puts

# ========================================
# Scenario 7: Version Locking for Critical Rules
# ========================================
puts "Scenario 7: Critical Rule Protection"
puts "-" * 70

def save_critical_version(manager, rule_id, content, created_by, changelog)
  # Require approval for critical rules
  puts "⚠️  Critical rule change requires approval"
  puts "   Rule ID: #{rule_id}"
  puts "   Changed by: #{created_by}"
  puts "   Changelog: #{changelog}"

  # In production, this would send for approval
  # For demo, we auto-approve
  approved = true

  if approved
    version = manager.save_version(
      rule_id: rule_id,
      rule_content: content,
      created_by: created_by,
      changelog: "[APPROVED] #{changelog}"
    )
    puts "✓ Version approved and saved: v#{version[:version_number]}"
    version
  else
    puts "✗ Version rejected"
    nil
  end
end

critical_rules = {
  version: "1.0",
  ruleset: "aml_screening",
  rules: [
    {
      id: "high_risk_transaction",
      if: { field: "risk_score", op: "gte", value: 0.9 },
      then: { decision: "block", weight: 1.0, reason: "AML high risk" }
    }
  ]
}

save_critical_version(
  manager,
  "aml_critical_001",
  critical_rules,
  "compliance_officer",
  "Updated AML screening threshold"
)
puts

puts "=" * 70
puts "Advanced scenarios completed!"
puts "=" * 70
