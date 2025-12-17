#!/usr/bin/env ruby
require_relative "../lib/decision_agent"
require "json"

puts "=" * 60
puts "DecisionAgent - Replay Example"
puts "=" * 60
puts

rules = {
  version: "1.0",
  ruleset: "access_control",
  rules: [
    {
      id: "admin_full_access",
      if: { field: "role", op: "eq", value: "admin" },
      then: { decision: "grant_access", weight: 1.0, reason: "Admin has full access" }
    },
    {
      id: "user_limited_access",
      if: { field: "role", op: "eq", value: "user" },
      then: { decision: "grant_limited_access", weight: 0.7, reason: "User has limited access" }
    }
  ]
}

evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
agent = DecisionAgent::Agent.new(evaluators: [evaluator])

puts "\n1. Make Original Decision"
puts "-" * 60

context = { user: "alice", role: "admin", resource: "database" }
original_result = agent.decide(context: context)

puts "Original Decision: #{original_result.decision}"
puts "Confidence: #{original_result.confidence}"
puts "Hash: #{original_result.audit_payload[:deterministic_hash]}"

puts "\n2. Replay Decision (Strict Mode)"
puts "-" * 60

replayed_result = DecisionAgent::Replay.run(
  original_result.audit_payload,
  strict: true
)

puts "Replayed Decision: #{replayed_result.decision}"
puts "Confidence: #{replayed_result.confidence}"
puts "Hash: #{replayed_result.audit_payload[:deterministic_hash]}"
puts "Match: #{original_result.decision == replayed_result.decision &&
              (original_result.confidence - replayed_result.confidence).abs < 0.0001}"

puts "\n3. Simulate Rule Change (Non-Strict Mode)"
puts "-" * 60

modified_payload = original_result.audit_payload.dup
modified_payload[:decision] = "deny_access"

puts "Attempting to replay with modified decision..."

begin
  DecisionAgent::Replay.run(modified_payload, strict: true)
  puts "ERROR: Should have raised ReplayMismatchError"
rescue DecisionAgent::ReplayMismatchError => e
  puts "Strict mode correctly detected mismatch:"
  puts "  Expected: #{e.expected[:decision]}"
  puts "  Actual: #{e.actual[:decision]}"
  puts "  Differences: #{e.differences.join(', ')}"
end

puts "\nNow trying non-strict mode..."
non_strict_result = DecisionAgent::Replay.run(modified_payload, strict: false)
puts "Non-strict mode allowed replay with warnings"
puts "Replayed Decision: #{non_strict_result.decision}"

puts "\n4. Audit Payload Structure"
puts "-" * 60
puts JSON.pretty_generate(original_result.audit_payload)

puts "\n" + "=" * 60
puts "Replay example complete"
puts "=" * 60
