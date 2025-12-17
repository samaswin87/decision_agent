#!/usr/bin/env ruby
require_relative "../lib/decision_agent"
require "json"

puts "=" * 60
puts "DecisionAgent - JSON Rules Example"
puts "=" * 60
puts

rules = {
  version: "1.0",
  ruleset: "issue_triage",
  rules: [
    {
      id: "critical_immediate",
      if: {
        all: [
          { field: "priority", op: "eq", value: "critical" },
          { field: "hours_inactive", op: "gte", value: 2 }
        ]
      },
      then: {
        decision: "escalate_immediately",
        weight: 1.0,
        reason: "Critical issue inactive for 2+ hours"
      }
    },
    {
      id: "high_priority_notify",
      if: {
        all: [
          { field: "priority", op: "eq", value: "high" },
          { field: "hours_inactive", op: "gte", value: 4 }
        ]
      },
      then: {
        decision: "notify_manager",
        weight: 0.8,
        reason: "High priority issue inactive for 4+ hours"
      }
    },
    {
      id: "normal_monitor",
      if: {
        field: "priority", op: "eq", value: "normal"
      },
      then: {
        decision: "continue_monitoring",
        weight: 0.3,
        reason: "Normal priority - continue monitoring"
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
    name: "Critical issue, 3 hours inactive",
    context: { priority: "critical", hours_inactive: 3, assignee: "alice" }
  },
  {
    name: "High priority, 5 hours inactive",
    context: { priority: "high", hours_inactive: 5, assignee: "bob" }
  },
  {
    name: "Normal priority, 1 hour inactive",
    context: { priority: "normal", hours_inactive: 1, assignee: "charlie" }
  },
  {
    name: "High priority, only 2 hours inactive (no match)",
    context: { priority: "high", hours_inactive: 2, assignee: "dave" }
  }
]

test_cases.each_with_index do |test_case, idx|
  puts "\nTest Case #{idx + 1}: #{test_case[:name]}"
  puts "-" * 60

  begin
    result = agent.decide(context: test_case[:context])

    puts "Decision: #{result.decision}"
    puts "Confidence: #{result.confidence}"
    puts "Explanations:"
    result.explanations.each do |explanation|
      puts "  #{explanation}"
    end
  rescue DecisionAgent::NoEvaluationsError
    puts "No rule matched - no decision made"
  end
end

puts "\n" + "=" * 60
puts "Example complete"
puts "=" * 60
