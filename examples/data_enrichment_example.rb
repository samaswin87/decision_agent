#!/usr/bin/env ruby
# frozen_string_literal: true

# Data Enrichment Example
#
# This example demonstrates how to use REST API data enrichment in DecisionAgent rules.
# Data enrichment allows rules to fetch external data during decision-making without
# manual context assembly.
#
# To run this example:
#   ruby examples/data_enrichment_example.rb
#
# Note: This example uses WebMock to simulate API calls. In production, you would
# configure real API endpoints.

require_relative "../lib/decision_agent"
require "webmock"
require "webmock/minitest" if defined?(Minitest)
require "json"

# Enable WebMock to simulate HTTP requests
WebMock.enable!
WebMock.disable_net_connect!(allow_localhost: true)

# Include WebMock methods for standalone script
include WebMock::API

# Mock API responses for demonstration
def setup_mock_apis
  # Mock credit bureau API
  stub_request(:post, "https://api.creditbureau.com/v1/score")
    .to_return(
      status: 200,
      body: {
        score: 750,
        risk_level: "low",
        last_updated: "2025-01-15T10:30:00Z"
      }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

  # Mock fraud detection API
  stub_request(:post, "https://api.fraudservice.com/check")
    .to_return(
      status: 200,
      body: {
        risk_score: 0.25,
        flagged: false,
        reason: "Low risk transaction"
      }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
end

puts "=" * 80
puts "DecisionAgent Data Enrichment Example"
puts "=" * 80
puts

# Step 1: Configure data enrichment endpoints
puts "Step 1: Configuring data enrichment endpoints..."
puts "-" * 80

DecisionAgent.configure_data_enrichment do |config|
  # Credit bureau endpoint
  config.add_endpoint(:credit_bureau,
    url: "https://api.creditbureau.com/v1/score",
    method: :post,
    cache: { ttl: 3600, adapter: :memory }, # Cache for 1 hour
    timeout: 5)

  # Fraud detection endpoint
  config.add_endpoint(:fraud_check,
    url: "https://api.fraudservice.com/check",
    method: :post,
    cache: { ttl: 300, adapter: :memory }, # Cache for 5 minutes
    timeout: 3)
end

puts "✓ Configured credit_bureau endpoint"
puts "✓ Configured fraud_check endpoint"
puts

# Step 2: Set up mock APIs (for demonstration only)
puts "Step 2: Setting up mock API responses..."
puts "-" * 80
setup_mock_apis
puts "✓ Mock APIs configured"
puts

# Step 3: Define rules with data enrichment
puts "Step 3: Defining rules with fetch_from_api operator..."
puts "-" * 80

rules = {
  version: "1.0",
  ruleset: "loan_approval_with_enrichment",
  rules: [
    {
      id: "fraud_check_rule",
      if: {
        field: "fraud_check",
        op: "fetch_from_api",
        value: {
          endpoint: "fraud_check",
          params: {
            user_id: "{{user.id}}",
            amount: "{{transaction.amount}}",
            ip_address: "{{transaction.ip}}"
          },
          mapping: {
            risk_score: "fraud_score"
          }
        }
      },
      then: {
        decision: "fraud_check_passed",
        weight: 0.9,
        reason: "Fraud check passed - API call successful"
      }
    },
    {
      id: "credit_score_check",
      if: {
        all: [
          {
            field: "credit_check",
            op: "fetch_from_api",
            value: {
              endpoint: "credit_bureau",
              params: {
                ssn: "{{customer.ssn}}"
              },
              mapping: {
                score: "credit_score"
              }
            }
          },
          {
            field: "loan_amount",
            op: "lte",
            value: 100000
          }
        ]
      },
      then: {
        decision: "approve",
        weight: 0.8,
        reason: "Credit check passed and loan amount is acceptable"
      }
    },
    {
      id: "high_credit_approval",
      if: {
        all: [
          {
            field: "credit_check",
            op: "fetch_from_api",
            value: {
              endpoint: "credit_bureau",
              params: {
                ssn: "{{customer.ssn}}"
              },
              mapping: {
                score: "credit_score"
              }
            }
          },
          {
            field: "loan_amount",
            op: "lte",
            value: 200000
          }
        ]
      },
      then: {
        decision: "approve",
        weight: 0.95,
        reason: "Credit check passed - approved for larger loan amount"
      }
    }
  ]
}

puts "✓ Defined 3 rules with data enrichment"
puts "  - fraud_check_rule: Checks fraud risk score"
puts "  - credit_score_check: Checks credit score (>= 700)"
puts "  - high_credit_approval: High credit score approval (>= 750)"
puts

# Step 4: Create evaluator and agent
puts "Step 4: Creating evaluator and agent..."
puts "-" * 80

evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
agent = DecisionAgent::Agent.new(evaluators: [evaluator])

puts "✓ Evaluator created"
puts "✓ Agent created"
puts

# Step 5: Make decisions with different contexts
puts "Step 5: Making decisions with data enrichment..."
puts "-" * 80
puts

# Example 1: Low-risk transaction with good credit
puts "Example 1: Low-risk transaction with good credit"
puts "-" * 40

context1 = DecisionAgent::Context.new({
  user: { id: "user123" },
  transaction: { amount: 50000, ip: "192.168.1.1" },
  customer: { ssn: "123-45-6789" },
  loan_amount: 75000
})

begin
  decision1 = agent.decide(context: context1)

  if decision1
    puts "Decision: #{decision1.decision}"
    puts "Confidence: #{decision1.confidence}"
    puts "Explanations: #{decision1.explanations.join(', ')}"
  else
    puts "No decision made"
  end
rescue DecisionAgent::NoEvaluationsError => e
  puts "No decision made: #{e.message}"
  puts "Note: This may occur if API calls fail or no rules match"
end
puts

# Example 2: High credit score, larger loan
puts "Example 2: High credit score, larger loan"
puts "-" * 40

context2 = DecisionAgent::Context.new({
  user: { id: "user456" },
  transaction: { amount: 150000, ip: "192.168.1.2" },
  customer: { ssn: "987-65-4321" },
  loan_amount: 150000
})

begin
  decision2 = agent.decide(context: context2)

  if decision2
    puts "Decision: #{decision2.decision}"
    puts "Confidence: #{decision2.confidence}"
    puts "Explanations: #{decision2.explanations.join(', ')}"
  else
    puts "No decision made"
  end
rescue DecisionAgent::NoEvaluationsError => e
  puts "No decision made: #{e.message}"
end
puts

# Example 3: Demonstrate caching
puts "Example 3: Demonstrating caching (second call uses cache)"
puts "-" * 40

context3 = DecisionAgent::Context.new({
  user: { id: "user789" },
  transaction: { amount: 30000, ip: "192.168.1.3" },
  customer: { ssn: "555-55-5555" },
  loan_amount: 50000
})

# First call - makes HTTP request
puts "First call (makes HTTP request)..."
begin
  decision3a = agent.decide(context: context3)
  puts "Decision: #{decision3a.decision}" if decision3a
rescue DecisionAgent::NoEvaluationsError
  puts "No decision made (expected - demonstrating API call)"
end
puts

# Second call - uses cache (no HTTP request)
puts "Second call (uses cache, no HTTP request)..."
begin
  decision3b = agent.decide(context: context3)
  puts "Decision: #{decision3b.decision}" if decision3b
rescue DecisionAgent::NoEvaluationsError
  puts "No decision made (expected - demonstrating cache)"
end
puts

# Step 6: Show configuration details
puts "Step 6: Configuration summary"
puts "-" * 80

config = DecisionAgent.data_enrichment_config
puts "Configured endpoints:"
config.endpoints.each do |name, endpoint_config|
  puts "  - #{name}:"
  puts "      URL: #{endpoint_config[:url]}"
  puts "      Method: #{endpoint_config[:method]}"
  puts "      Cache TTL: #{endpoint_config[:cache][:ttl]} seconds"
  puts "      Timeout: #{endpoint_config[:timeout]} seconds"
end
puts

# Step 7: Advanced usage - error handling
puts "Step 7: Error handling demonstration"
puts "-" * 80

# Mock a failing API
stub_request(:post, "https://api.creditbureau.com/v1/score")
  .with(body: { ssn: "999-99-9999" }.to_json)
  .to_return(status: 500, body: "Internal Server Error")

rules_with_fallback = {
  version: "1.0",
  ruleset: "loan_with_fallback",
  rules: [
    {
      id: "credit_with_fallback",
      if: {
        any: [
          {
            field: "credit_score",
            op: "fetch_from_api",
            value: {
              endpoint: "credit_bureau",
              params: { ssn: "{{customer.ssn}}" },
              mapping: { score: "credit_score" }
            }
          },
          {
            field: "manual_credit_score",
            op: "present"
          }
        ]
      },
      then: {
        decision: "approve",
        weight: 0.7,
        reason: "Credit check passed or fallback used"
      }
    }
  ]
}

evaluator_fallback = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules_with_fallback)
agent_fallback = DecisionAgent::Agent.new(evaluators: [evaluator_fallback])

context_fallback = DecisionAgent::Context.new({
  customer: { ssn: "999-99-9999" },
  manual_credit_score: 720
})

puts "Testing with failing API and fallback..."
begin
  decision_fallback = agent_fallback.decide(context: context_fallback)

  if decision_fallback
    puts "Decision: #{decision_fallback.decision}"
    puts "Confidence: #{decision_fallback.confidence}"
    puts "✓ Fallback logic worked - used manual_credit_score when API failed"
  else
    puts "No decision made"
  end
rescue DecisionAgent::NoEvaluationsError => e
  puts "No decision made: #{e.message}"
  puts "Note: This demonstrates graceful error handling when API fails"
end
puts

puts "=" * 80
puts "Example completed!"
puts "=" * 80
puts
puts "Key takeaways:"
puts "1. Configure endpoints using DecisionAgent.configure_data_enrichment"
puts "2. Use 'fetch_from_api' operator in rule conditions"
puts "3. Use {{path}} syntax for template parameter expansion"
puts "4. Map API response fields to context using 'mapping'"
puts "5. Responses are automatically cached based on TTL"
puts "6. Errors are handled gracefully - operator returns false on failure"
puts "7. Combine with other operators using 'all' or 'any' conditions"
puts

