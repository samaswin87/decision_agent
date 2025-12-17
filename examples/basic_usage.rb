#!/usr/bin/env ruby
require_relative "../lib/decision_agent"

puts "=" * 60
puts "DecisionAgent - Basic Usage Example"
puts "=" * 60
puts

evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(
  decision: "approve",
  weight: 0.85,
  reason: "User meets approval criteria"
)

agent = DecisionAgent::Agent.new(
  evaluators: [evaluator],
  scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new,
  audit_adapter: DecisionAgent::Audit::NullAdapter.new
)

context = {
  user: "alice",
  action: "login",
  timestamp: Time.now.to_s
}

result = agent.decide(context: context)

puts "Decision: #{result.decision}"
puts "Confidence: #{result.confidence}"
puts
puts "Explanations:"
result.explanations.each do |explanation|
  puts "  - #{explanation}"
end
puts
puts "Audit Hash: #{result.audit_payload[:deterministic_hash]}"
puts
puts "Full Audit Payload:"
puts JSON.pretty_generate(result.audit_payload)
