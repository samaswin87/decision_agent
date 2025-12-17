#!/usr/bin/env ruby
require_relative "../lib/decision_agent"

puts "=" * 60
puts "DecisionAgent - Custom Evaluator Example"
puts "=" * 60
puts

class RevenueBasedEvaluator < DecisionAgent::Evaluators::Base
  def initialize(threshold:)
    @threshold = threshold
  end

  def evaluate(context, feedback: {})
    revenue = context[:revenue] || context["revenue"]

    return nil unless revenue

    if revenue >= @threshold
      DecisionAgent::Evaluation.new(
        decision: "approve_vip",
        weight: 0.95,
        reason: "High-value customer (revenue: $#{revenue})",
        evaluator_name: "RevenueEvaluator",
        metadata: { revenue: revenue, threshold: @threshold }
      )
    else
      DecisionAgent::Evaluation.new(
        decision: "standard_approval",
        weight: 0.5,
        reason: "Standard customer (revenue: $#{revenue})",
        evaluator_name: "RevenueEvaluator",
        metadata: { revenue: revenue, threshold: @threshold }
      )
    end
  end
end

class RiskScoreEvaluator < DecisionAgent::Evaluators::Base
  def evaluate(context, feedback: {})
    risk_score = context[:risk_score] || context["risk_score"]

    return nil unless risk_score

    if risk_score > 80
      DecisionAgent::Evaluation.new(
        decision: "reject_high_risk",
        weight: 1.0,
        reason: "Risk score too high: #{risk_score}",
        evaluator_name: "RiskEvaluator",
        metadata: { risk_score: risk_score }
      )
    elsif risk_score > 50
      DecisionAgent::Evaluation.new(
        decision: "manual_review",
        weight: 0.7,
        reason: "Moderate risk: #{risk_score}",
        evaluator_name: "RiskEvaluator",
        metadata: { risk_score: risk_score }
      )
    else
      nil
    end
  end
end

revenue_eval = RevenueBasedEvaluator.new(threshold: 50_000)
risk_eval = RiskScoreEvaluator.new

agent = DecisionAgent::Agent.new(
  evaluators: [revenue_eval, risk_eval],
  scoring_strategy: DecisionAgent::Scoring::MaxWeight.new
)

test_cases = [
  {
    name: "VIP customer, low risk",
    context: { customer_id: "C001", revenue: 100_000, risk_score: 20 }
  },
  {
    name: "VIP customer, high risk",
    context: { customer_id: "C002", revenue: 150_000, risk_score: 85 }
  },
  {
    name: "Standard customer, moderate risk",
    context: { customer_id: "C003", revenue: 20_000, risk_score: 60 }
  },
  {
    name: "Standard customer, low risk",
    context: { customer_id: "C004", revenue: 10_000, risk_score: 15 }
  }
]

test_cases.each do |test_case|
  puts "\nTest: #{test_case[:name]}"
  puts "-" * 60

  result = agent.decide(context: test_case[:context])

  puts "Decision: #{result.decision}"
  puts "Confidence: #{result.confidence}"
  puts "Explanations:"
  result.explanations.each do |explanation|
    puts "  #{explanation}"
  end
end

puts "\n" + "=" * 60
puts "Custom evaluator example complete"
puts "=" * 60
