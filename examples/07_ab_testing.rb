#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: A/B Testing with Decision Agent
# Demonstrates how to run A/B tests comparing different rule versions

require_relative "../lib/decision_agent"

puts "=" * 80
puts "A/B Testing Example"
puts "=" * 80
puts ""

# Step 1: Set up version manager and create two rule versions
puts "📦 Step 1: Creating Rule Versions"
puts "-" * 80

version_manager = DecisionAgent::Versioning::VersionManager.new(
  adapter: DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: "/tmp/ab_test_rules")
)

# Champion version - conservative rule
champion_rule = {
  version: "1.0",
  ruleset: "transaction_approval",
  rules: [
    {
      id: "champion_high_value",
      if: { field: "amount", op: "gt", value: 1000 },
      then: { decision: "approve", weight: 1.0, reason: "High-value transaction approved" }
    },
    {
      id: "champion_low_value",
      if: { field: "amount", op: "lte", value: 1000 },
      then: { decision: "review", weight: 1.0, reason: "Lower-value transaction needs review" }
    }
  ]
}

champion_version = version_manager.save_version(
  rule_id: "transaction_approval",
  rule_content: champion_rule,
  created_by: "system",
  changelog: "Champion version - conservative approval"
)

puts "✅ Champion version created: #{champion_version[:id]}"

# Challenger version - more aggressive rule
challenger_rule = {
  version: "1.0",
  ruleset: "transaction_approval",
  rules: [
    {
      id: "challenger_high_value",
      if: { field: "amount", op: "gt", value: 500 },
      then: { decision: "approve", weight: 1.0, reason: "Lowered threshold for approval" }
    },
    {
      id: "challenger_low_value",
      if: { field: "amount", op: "lte", value: 500 },
      then: { decision: "review", weight: 1.0, reason: "Only low-value transactions need review" }
    }
  ]
}

challenger_version = version_manager.save_version(
  rule_id: "transaction_approval",
  rule_content: challenger_rule,
  created_by: "system",
  changelog: "Challenger version - aggressive approval"
)

puts "✅ Challenger version created: #{challenger_version[:id]}"
puts ""

# Step 2: Create A/B Test
puts "🧪 Step 2: Creating A/B Test"
puts "-" * 80

ab_test_manager = DecisionAgent::ABTesting::ABTestManager.new(
  version_manager: version_manager
)

ab_test = ab_test_manager.create_test(
  name: "Transaction Approval Threshold Test",
  champion_version_id: champion_version[:id],
  challenger_version_id: challenger_version[:id],
  traffic_split: { champion: 90, challenger: 10 }, # 90/10 split
  start_date: Time.now.utc
)

puts "✅ A/B test created: #{ab_test.id}"
puts "   Name: #{ab_test.name}"
puts "   Traffic Split: #{ab_test.traffic_split[:champion]}% champion / #{ab_test.traffic_split[:challenger]}% challenger"
puts ""

# Step 3: Create A/B Testing Agent
puts "🤖 Step 3: Setting up A/B Testing Agent"
puts "-" * 80

# Base evaluators (used if no version is specified)
base_evaluators = [
  DecisionAgent::Evaluators::StaticEvaluator.new(
    decision: "review",
    weight: 1.0,
    reason: "Default: all transactions need review"
  )
]

ab_agent = DecisionAgent::ABTesting::ABTestingAgent.new(
  ab_test_manager: ab_test_manager,
  version_manager: version_manager,
  evaluators: base_evaluators
)

puts "✅ A/B Testing Agent initialized"
puts ""

# Step 4: Run test with multiple users
puts "🎯 Step 4: Running A/B Test with 100 Users"
puts "-" * 80

test_scenarios = [
  { user_id: "user_", amount: 300 },  # Should be "review" for champion, "review" for challenger
  { user_id: "user_", amount: 700 },  # Should be "review" for champion, "approve" for challenger
  { user_id: "user_", amount: 1500 }  # Should be "approve" for both
]

100.times do |i|
  user_id = "user_#{i}"
  scenario = test_scenarios.sample

  result = ab_agent.decide(
    context: { amount: scenario[:amount] },
    ab_test_id: ab_test.id,
    user_id: user_id
  )

  # Simulate some variation in confidence
  # In a real scenario, this would come from actual decision confidence

  next unless i < 5

  puts "User #{user_id}: amount=#{scenario[:amount]}"
  puts "  → Variant: #{result[:ab_test][:variant]}"
  puts "  → Decision: #{result[:decision]}"
  puts "  → Confidence: #{result[:confidence].round(2)}"
  puts "  → Version: #{result[:ab_test][:version_id]}"
end

puts "..."
puts "✅ Completed 100 test assignments"
puts ""

# Step 5: Analyze Results
puts "📊 Step 5: Analyzing A/B Test Results"
puts "-" * 80

results = ab_test_manager.get_results(ab_test.id)

puts "\nTest: #{results[:test][:name]}"
puts "Status: #{results[:test][:status]}"
puts "Total Assignments: #{results[:total_assignments]}"
puts ""

puts "🏆 CHAMPION (Version #{results[:test][:champion_version_id]})"
puts "   Assignments: #{results[:champion][:total_assignments]}"
puts "   Decisions Recorded: #{results[:champion][:decisions_recorded]}"
if results[:champion][:avg_confidence]
  puts "   Avg Confidence: #{results[:champion][:avg_confidence]}"
  puts "   Range: #{results[:champion][:min_confidence]} - #{results[:champion][:max_confidence]}"
  puts "   Decision Distribution:"
  results[:champion][:decision_distribution].each do |decision, count|
    puts "     - #{decision}: #{count}"
  end
end
puts ""

puts "🆕 CHALLENGER (Version #{results[:test][:challenger_version_id]})"
puts "   Assignments: #{results[:challenger][:total_assignments]}"
puts "   Decisions Recorded: #{results[:challenger][:decisions_recorded]}"
if results[:challenger][:avg_confidence]
  puts "   Avg Confidence: #{results[:challenger][:avg_confidence]}"
  puts "   Range: #{results[:challenger][:min_confidence]} - #{results[:challenger][:max_confidence]}"
  puts "   Decision Distribution:"
  results[:challenger][:decision_distribution].each do |decision, count|
    puts "     - #{decision}: #{count}"
  end
end
puts ""

if results[:comparison][:statistical_significance] == "insufficient_data"
  puts "⚠️  Insufficient data for statistical comparison"
  puts "   Run more tests to gather statistical significance"
else
  puts "📈 STATISTICAL COMPARISON"
  puts "   Improvement: #{results[:comparison][:improvement_percentage]}%"
  puts "   Winner: #{results[:comparison][:winner]}"
  puts "   Statistical Significance: #{results[:comparison][:statistical_significance]}"
  puts "   Confidence Level: #{(results[:comparison][:confidence_level] * 100).round(0)}%"
  puts ""
  puts "💡 RECOMMENDATION:"
  puts "   #{results[:comparison][:recommendation]}"
end

puts ""

# Step 6: Test completion workflow
puts "🏁 Step 6: Test Lifecycle Management"
puts "-" * 80

puts "\nActive tests:"
active_tests = ab_test_manager.active_tests
active_tests.each do |test|
  puts "  - #{test.name} (ID: #{test.id}, Status: #{test.status})"
end

puts "\n✅ Completing the test..."
ab_test_manager.complete_test(ab_test.id)
puts "Test status changed to: completed"

puts ""

# Step 7: Consistent Assignment Demo
puts "🔄 Step 7: Consistent User Assignment"
puts "-" * 80

# Create a new test
new_test = ab_test_manager.create_test(
  name: "Consistent Assignment Test",
  champion_version_id: champion_version[:id],
  challenger_version_id: challenger_version[:id],
  traffic_split: { champion: 50, challenger: 50 }
)

puts "\nDemonstrating that the same user always gets the same variant:"
user_id = "consistent_user_123"

3.times do |i|
  result = ab_agent.decide(
    context: { amount: 1000 },
    ab_test_id: new_test.id,
    user_id: user_id
  )

  puts "Attempt #{i + 1}: User '#{user_id}' → Variant: #{result[:ab_test][:variant]}"
end

puts ""
puts "=" * 80
puts "✅ A/B Testing Example Complete!"
puts "=" * 80
puts ""
puts "Key Takeaways:"
puts "1. A/B tests compare different rule versions (champion vs challenger)"
puts "2. Traffic is split according to configured percentages (e.g., 90/10)"
puts "3. Same users get consistent assignments using user_id"
puts "4. Statistical analysis determines which version performs better"
puts "5. Results include confidence intervals and recommendations"
puts ""
puts "Next Steps:"
puts "- In Rails: Use rake tasks to manage A/B tests"
puts "- Use ActiveRecord adapter for database persistence"
puts "- Monitor test progress in real-time"
puts "- Promote winning variants to production"
puts ""
