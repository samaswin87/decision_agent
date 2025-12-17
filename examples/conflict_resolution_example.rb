#!/usr/bin/env ruby
require_relative "../lib/decision_agent"

puts "=" * 60
puts "DecisionAgent - Conflict Resolution Example"
puts "=" * 60
puts

eval1 = DecisionAgent::Evaluators::StaticEvaluator.new(
  decision: "approve",
  weight: 0.6,
  reason: "Basic criteria met",
  name: "BasicEvaluator"
)

eval2 = DecisionAgent::Evaluators::StaticEvaluator.new(
  decision: "approve",
  weight: 0.7,
  reason: "Advanced criteria met",
  name: "AdvancedEvaluator"
)

eval3 = DecisionAgent::Evaluators::StaticEvaluator.new(
  decision: "reject",
  weight: 0.5,
  reason: "Risk detected",
  name: "RiskEvaluator"
)

strategies = {
  "WeightedAverage" => DecisionAgent::Scoring::WeightedAverage.new,
  "MaxWeight" => DecisionAgent::Scoring::MaxWeight.new,
  "Consensus (60%)" => DecisionAgent::Scoring::Consensus.new(minimum_agreement: 0.6),
  "Threshold (0.75)" => DecisionAgent::Scoring::Threshold.new(threshold: 0.75, fallback_decision: "manual_review")
}

context = { user: "test_user", action: "sensitive_operation" }

strategies.each do |name, strategy|
  puts "\nStrategy: #{name}"
  puts "-" * 60

  agent = DecisionAgent::Agent.new(
    evaluators: [eval1, eval2, eval3],
    scoring_strategy: strategy
  )

  result = agent.decide(context: context)

  puts "Decision: #{result.decision}"
  puts "Confidence: #{result.confidence.round(4)}"
  puts "Explanations:"
  result.explanations.each do |explanation|
    puts "  #{explanation}"
  end
end

puts "\n" + "=" * 60
puts "Conflict resolution comparison complete"
puts "=" * 60
