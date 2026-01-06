#!/usr/bin/env ruby
require_relative "../lib/decision_agent"
require "json"

puts "=" * 60
puts "DecisionAgent - Explainability Example"
puts "=" * 60
puts

# Define rules for loan approval
rules = {
  version: "1.0",
  ruleset: "loan_approval",
  rules: [
    {
      id: "auto_approve",
      if: {
        all: [
          { field: "risk_score", op: "lt", value: 0.7 },
          { field: "account_age_days", op: "gt", value: 180 },
          { field: "credit_hold", op: "eq", value: false }
        ]
      },
      then: {
        decision: "approved",
        weight: 0.9,
        reason: "Low risk, established account, no credit hold"
      }
    },
    {
      id: "manual_review",
      if: {
        all: [
          { field: "risk_score", op: "gte", value: 0.7 },
          { field: "risk_score", op: "lt", value: 0.85 },
          { field: "account_age_days", op: "gt", value: 90 }
        ]
      },
      then: {
        decision: "manual_review",
        weight: 0.7,
        reason: "Medium risk requires manual review"
      }
    },
    {
      id: "reject_high_risk",
      if: {
        field: "risk_score", op: "gte", value: 0.85
      },
      then: {
        decision: "rejected",
        weight: 1.0,
        reason: "High risk score"
      }
    }
  ]
}

evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
agent = DecisionAgent::Agent.new(
  evaluators: [evaluator],
  scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new
)

test_cases = [
  {
    name: "Auto-approve: Low risk, established account",
    context: {
      risk_score: 0.5,
      account_age_days: 200,
      credit_hold: false
    }
  },
  {
    name: "Manual review: Medium risk",
    context: {
      risk_score: 0.75,
      account_age_days: 120,
      credit_hold: false
    }
  },
  {
    name: "Reject: High risk",
    context: {
      risk_score: 0.9,
      account_age_days: 100,
      credit_hold: false
    }
  },
  {
    name: "Credit hold blocks approval",
    context: {
      risk_score: 0.5,
      account_age_days: 200,
      credit_hold: true  # This will cause auto_approve rule to fail
    }
  }
]

test_cases.each_with_index do |test_case, idx|
  puts "\n" + "=" * 60
  puts "Test Case #{idx + 1}: #{test_case[:name]}"
  puts "=" * 60
  puts "Context: #{test_case[:context].inspect}"
  puts

  begin
    result = agent.decide(context: test_case[:context])

    puts "Decision: #{result.decision}"
    puts "Confidence: #{result.confidence.round(3)}"
    puts

    # Show human-readable explanations
    puts "Explanations:"
    result.explanations.each do |explanation|
      puts "  - #{explanation}"
    end
    puts

    # Show machine-readable explainability
    puts "Explainability:"
    puts "  Because (conditions that led to decision):"
    if result.because.any?
      result.because.each do |condition|
        puts "    ✓ #{condition}"
      end
    else
      puts "    (no conditions matched)"
    end
    puts

    puts "  Failed Conditions (conditions that didn't match):"
    if result.failed_conditions.any?
      result.failed_conditions.each do |condition|
        puts "    ✗ #{condition}"
      end
    else
      puts "    (none)"
    end
    puts

    # Show full explainability data structure
    puts "  Full Explainability Data:"
    explainability = result.explainability
    puts "    Decision: #{explainability[:decision]}"
    puts "    Because: #{explainability[:because].inspect}"
    puts "    Failed Conditions: #{explainability[:failed_conditions].inspect}"
    puts

    # Show verbose explainability for first test case
    if idx == 0
      puts "  Verbose Explainability (with detailed condition info):"
      verbose = result.explainability(verbose: true)
      puts JSON.pretty_generate(verbose).gsub(/^/, "    ")
      puts
    end

  rescue DecisionAgent::NoEvaluationsError
    puts "No rule matched - no decision made"
  end
end

puts "\n" + "=" * 60
puts "Example: Using Explainability for Audit Logging"
puts "=" * 60
puts

# Example: Store explainability for audit trail
result = agent.decide(context: {
  risk_score: 0.6,
  account_age_days: 250,
  credit_hold: false
})

audit_record = {
  timestamp: Time.now.utc.iso8601,
  decision: result.decision,
  confidence: result.confidence,
  explainability: result.explainability,
  because: result.because,
  failed_conditions: result.failed_conditions,
  audit_hash: result.audit_payload[:deterministic_hash]
}

puts "Audit Record (suitable for compliance/regulatory requirements):"
puts JSON.pretty_generate(audit_record)
puts

puts "=" * 60
puts "Example complete"
puts "=" * 60

