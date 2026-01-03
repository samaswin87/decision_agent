#!/usr/bin/env ruby
# frozen_string_literal: true

# Real-World Use Case: Request Routing Decision
#
# This example demonstrates routing logic for a service platform:
# - Route requests based on priority, type, and region
# - Handle different service tiers
# - Geographic routing considerations

require "bundler/setup"
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/evaluators/dmn_evaluator"

# Request routing decision table
dmn_xml = <<~DMN
  <?xml version="1.0" encoding="UTF-8"?>
  <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
               id="request_routing"
               name="Request Routing Decision"
               namespace="http://example.com/routing">

    <decision id="routing" name="Determine Request Route">
      <decisionTable id="routing_table" hitPolicy="FIRST">
        <input id="input_priority" label="Priority">
          <inputExpression typeRef="string">
            <text>priority</text>
          </inputExpression>
        </input>

        <input id="input_type" label="Request Type">
          <inputExpression typeRef="string">
            <text>request_type</text>
          </inputExpression>
        </input>

        <input id="input_region" label="Region">
          <inputExpression typeRef="string">
            <text>region</text>
          </inputExpression>
        </input>

        <input id="input_tier" label="Service Tier">
          <inputExpression typeRef="string">
            <text>service_tier</text>
          </inputExpression>
        </input>

        <output id="output_server" label="Target Server" name="server" typeRef="string"/>
        <output id="output_queue" label="Queue Name" name="queue" typeRef="string"/>

        <!-- Critical priority always goes to dedicated server -->
        <rule id="rule_critical">
          <description>Critical priority requests - dedicated server</description>
          <inputEntry><text>"critical"</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>"dedicated-1"</text></outputEntry>
          <outputEntry><text>"critical-queue"</text></outputEntry>
        </rule>

        <!-- High priority API requests -->
        <rule id="rule_high_api">
          <description>High priority API requests</description>
          <inputEntry><text>"high"</text></inputEntry>
          <inputEntry><text>"api"</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>"api-cluster-1"</text></outputEntry>
          <outputEntry><text>"high-priority-api"</text></outputEntry>
        </rule>

        <!-- Enterprise tier gets premium routing -->
        <rule id="rule_enterprise">
          <description>Enterprise tier customers</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>"enterprise"</text></inputEntry>
          <outputEntry><text>"enterprise-cluster"</text></outputEntry>
          <outputEntry><text>"enterprise-queue"</text></outputEntry>
        </rule>

        <!-- EU region routing for GDPR compliance -->
        <rule id="rule_eu_region">
          <description>EU region requests - must stay in EU</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>"eu"</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>"eu-cluster"</text></outputEntry>
          <outputEntry><text>"eu-queue"</text></outputEntry>
        </rule>

        <!-- Batch processing requests -->
        <rule id="rule_batch">
          <description>Batch processing requests</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>"batch"</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>"batch-processor"</text></outputEntry>
          <outputEntry><text>"batch-queue"</text></outputEntry>
        </rule>

        <!-- Default routing -->
        <rule id="rule_default">
          <description>Default routing for standard requests</description>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <inputEntry><text>-</text></inputEntry>
          <outputEntry><text>"standard-cluster"</text></outputEntry>
          <outputEntry><text>"standard-queue"</text></outputEntry>
        </rule>
      </decisionTable>
    </decision>
  </definitions>
DMN

puts "=" * 80
puts "Real-World Use Case: Request Routing"
puts "=" * 80
puts
puts "This example shows how DMN can model routing logic:"
puts "  • Priority-based routing (critical, high, standard)"
puts "  • Request type routing (API, batch, web)"
puts "  • Geographic routing (EU for GDPR compliance)"
puts "  • Service tier routing (enterprise, standard)"
puts

# Import the DMN model
importer = DecisionAgent::Dmn::Importer.new
result = importer.import_from_xml(dmn_xml, ruleset_name: "request_routing", created_by: "example_user")

evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: result[:model],
  decision_id: "routing"
)

puts "Routing Scenarios"
puts "-" * 80

scenarios = [
  {
    context: { priority: "critical", request_type: "api", region: "us", service_tier: "standard" },
    description: "Critical priority request - should route to dedicated server"
  },
  {
    context: { priority: "high", request_type: "api", region: "us", service_tier: "standard" },
    description: "High priority API request"
  },
  {
    context: { priority: "standard", request_type: "web", region: "eu", service_tier: "standard" },
    description: "EU region request - must route to EU cluster for compliance"
  },
  {
    context: { priority: "standard", request_type: "batch", region: "us", service_tier: "standard" },
    description: "Batch processing request"
  },
  {
    context: { priority: "standard", request_type: "api", region: "us", service_tier: "enterprise" },
    description: "Enterprise tier customer - premium routing"
  },
  {
    context: { priority: "standard", request_type: "web", region: "us", service_tier: "standard" },
    description: "Standard request - default routing"
  }
]

scenarios.each_with_index do |scenario, idx|
  context = DecisionAgent::Context.new(scenario[:context])
  evaluation = evaluator.evaluate(context)

  server = evaluation.decision
  queue = evaluation.metadata[:outputs][:queue] if evaluation.metadata && evaluation.metadata[:outputs]

  puts "Scenario #{idx + 1}: #{scenario[:description]}"
  puts "  Input: priority=#{scenario[:context][:priority]}, type=#{scenario[:context][:request_type]}, region=#{scenario[:context][:region]}, tier=#{scenario[:context][:service_tier]}"
  puts "  ✓ Server: #{server}"
  puts "  ✓ Queue: #{queue}"
  puts
end

puts "=" * 80
puts "Benefits:"
puts "  • Routing rules are business logic, not code"
puts "  • Easy to add new regions, tiers, or request types"
puts "  • Compliance rules (like EU routing) are explicit and auditable"
puts "  • Operations team can modify routing without developer involvement"
puts "=" * 80

