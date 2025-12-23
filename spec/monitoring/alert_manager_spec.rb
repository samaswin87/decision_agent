require "spec_helper"
require "decision_agent/monitoring/metrics_collector"
require "decision_agent/monitoring/alert_manager"

RSpec.describe DecisionAgent::Monitoring::AlertManager do
  let(:collector) { DecisionAgent::Monitoring::MetricsCollector.new }
  let(:manager) { described_class.new(metrics_collector: collector) }

  describe "#initialize" do
    it "initializes with empty rules and alerts" do
      expect(manager.rules).to be_empty
      expect(manager.alerts).to be_empty
    end
  end

  describe "#add_rule" do
    it "adds an alert rule" do
      rule = manager.add_rule(
        name: "High Error Rate",
        condition: ->(stats) { stats.dig(:errors, :total).to_i > 10 },
        severity: :critical
      )

      expect(rule).to be_a(Hash)
      expect(rule[:name]).to eq("High Error Rate")
      expect(rule[:severity]).to eq(:critical)
      expect(rule[:enabled]).to be true
    end

    it "generates unique rule ID" do
      rule1 = manager.add_rule(name: "Rule 1", condition: ->(_) { false })
      rule2 = manager.add_rule(name: "Rule 1", condition: ->(_) { false })

      expect(rule1[:id]).not_to eq(rule2[:id])
    end

    it "sets default values" do
      rule = manager.add_rule(name: "Test", condition: ->(_) { false })

      expect(rule[:severity]).to eq(:warning)
      expect(rule[:cooldown]).to eq(300)
      expect(rule[:message]).to eq("Alert: Test")
    end

    it "allows custom message and cooldown" do
      rule = manager.add_rule(
        name: "Test",
        condition: ->(_) { false },
        message: "Custom message",
        cooldown: 600
      )

      expect(rule[:message]).to eq("Custom message")
      expect(rule[:cooldown]).to eq(600)
    end
  end

  describe "#remove_rule" do
    it "removes a rule by ID" do
      rule = manager.add_rule(name: "Test", condition: ->(_) { false })
      rule_id = rule[:id]

      manager.remove_rule(rule_id)

      expect(manager.rules).not_to include(rule)
    end
  end

  describe "#toggle_rule" do
    it "enables and disables rules" do
      rule = manager.add_rule(name: "Test", condition: ->(_) { false })

      manager.toggle_rule(rule[:id], false)
      expect(manager.rules.first[:enabled]).to be false

      manager.toggle_rule(rule[:id], true)
      expect(manager.rules.first[:enabled]).to be true
    end
  end

  describe "#check_rules" do
    before do
      # Setup metrics
      5.times { collector.record_error(StandardError.new("Test")) }
    end

    it "evaluates all enabled rules" do
      triggered = false

      manager.add_rule(
        name: "Error Threshold",
        condition: ->(stats) { stats.dig(:errors, :total).to_i > 3 }
      )

      manager.add_handler { |_| triggered = true }
      manager.check_rules

      expect(triggered).to be true
      expect(manager.active_alerts.size).to eq(1)
    end

    it "skips disabled rules" do
      rule = manager.add_rule(
        name: "Error Threshold",
        condition: ->(stats) { stats.dig(:errors, :total).to_i > 3 }
      )

      manager.toggle_rule(rule[:id], false)
      manager.check_rules

      expect(manager.active_alerts).to be_empty
    end

    it "respects cooldown period" do
      manager.add_rule(
        name: "Error Threshold",
        condition: ->(stats) { stats.dig(:errors, :total).to_i > 3 },
        cooldown: 60
      )

      manager.check_rules
      expect(manager.active_alerts.size).to eq(1)

      # Immediate second check should not trigger due to cooldown
      manager.check_rules
      expect(manager.active_alerts.size).to eq(1)
    end

    it "triggers multiple rules" do
      manager.add_rule(
        name: "Rule 1",
        condition: ->(_) { true }
      )
      manager.add_rule(
        name: "Rule 2",
        condition: ->(_) { true }
      )

      manager.check_rules

      expect(manager.active_alerts.size).to eq(2)
    end
  end

  describe "#add_handler" do
    it "registers alert handlers" do
      alerts_received = []

      manager.add_handler do |alert|
        alerts_received << alert
      end

      manager.add_rule(name: "Test", condition: ->(_) { true })
      manager.check_rules

      expect(alerts_received.size).to eq(1)
      expect(alerts_received.first[:rule_name]).to eq("Test")
    end

    it "calls multiple handlers" do
      count1 = 0
      count2 = 0

      manager.add_handler { count1 += 1 }
      manager.add_handler { count2 += 1 }

      manager.add_rule(name: "Test", condition: ->(_) { true })
      manager.check_rules

      expect(count1).to eq(1)
      expect(count2).to eq(1)
    end

    it "continues if a handler fails" do
      successful_handler_called = false

      manager.add_handler { raise "Handler error" }
      manager.add_handler { successful_handler_called = true }

      manager.add_rule(name: "Test", condition: ->(_) { true })

      expect { manager.check_rules }.not_to raise_error
      expect(successful_handler_called).to be true
    end
  end

  describe "#acknowledge_alert" do
    before do
      manager.add_rule(name: "Test", condition: ->(_) { true })
      manager.check_rules
    end

    it "acknowledges an alert" do
      alert = manager.active_alerts.first
      manager.acknowledge_alert(alert[:id], acknowledged_by: "admin")

      acknowledged = manager.all_alerts.find { |a| a[:id] == alert[:id] }
      expect(acknowledged[:status]).to eq(:acknowledged)
      expect(acknowledged[:acknowledged_by]).to eq("admin")
      expect(acknowledged[:acknowledged_at]).to be_a(Time)
    end
  end

  describe "#resolve_alert" do
    before do
      manager.add_rule(name: "Test", condition: ->(_) { true })
      manager.check_rules
    end

    it "resolves an alert" do
      alert = manager.active_alerts.first
      manager.resolve_alert(alert[:id], resolved_by: "admin")

      resolved = manager.all_alerts.find { |a| a[:id] == alert[:id] }
      expect(resolved[:status]).to eq(:resolved)
      expect(resolved[:resolved_by]).to eq("admin")
      expect(resolved[:resolved_at]).to be_a(Time)
    end

    it "removes from active alerts" do
      alert = manager.active_alerts.first
      manager.resolve_alert(alert[:id])

      expect(manager.active_alerts).to be_empty
    end
  end

  describe "#clear_old_alerts" do
    it "clears old resolved alerts" do
      manager.add_rule(name: "Test", condition: ->(_) { true })
      manager.check_rules

      alert = manager.active_alerts.first
      manager.resolve_alert(alert[:id])

      # Manually set old timestamp
      manager.alerts.first[:triggered_at] = Time.now.utc - 90000

      manager.clear_old_alerts(older_than: 86400)

      expect(manager.all_alerts).to be_empty
    end

    it "keeps active alerts regardless of age" do
      manager.add_rule(name: "Test", condition: ->(_) { true })
      manager.check_rules

      # Manually set old timestamp
      manager.alerts.first[:triggered_at] = Time.now.utc - 90000

      manager.clear_old_alerts(older_than: 86400)

      expect(manager.active_alerts.size).to eq(1)
    end
  end

  describe "built-in conditions" do
    describe ".high_error_rate" do
      it "detects high error rate" do
        condition = described_class.high_error_rate(threshold: 0.1)

        # Low error rate
        stats = { performance: { total_operations: 100, success_rate: 0.95 } }
        expect(condition.call(stats)).to be false

        # High error rate
        stats = { performance: { total_operations: 100, success_rate: 0.80 } }
        expect(condition.call(stats)).to be true
      end
    end

    describe ".low_confidence" do
      it "detects low confidence" do
        condition = described_class.low_confidence(threshold: 0.5)

        stats = { decisions: { avg_confidence: 0.8 } }
        expect(condition.call(stats)).to be false

        stats = { decisions: { avg_confidence: 0.3 } }
        expect(condition.call(stats)).to be true
      end
    end

    describe ".high_latency" do
      it "detects high latency" do
        condition = described_class.high_latency(threshold_ms: 1000)

        stats = { performance: { p95_duration_ms: 500 } }
        expect(condition.call(stats)).to be false

        stats = { performance: { p95_duration_ms: 1500 } }
        expect(condition.call(stats)).to be true
      end
    end

    describe ".error_spike" do
      it "detects error spikes" do
        condition = described_class.error_spike(threshold: 10)

        stats = { errors: { total: 5 } }
        expect(condition.call(stats)).to be false

        stats = { errors: { total: 15 } }
        expect(condition.call(stats)).to be true
      end
    end
  end

  describe "hash-based conditions" do
    it "evaluates hash conditions" do
      manager.add_rule(
        name: "Hash Condition",
        condition: { metric: "errors.total", op: "gt", value: 5 }
      )

      5.times { collector.record_error(StandardError.new("Test")) }
      manager.check_rules
      expect(manager.active_alerts).to be_empty

      collector.record_error(StandardError.new("Test"))
      manager.check_rules
      expect(manager.active_alerts.size).to eq(1)
    end

    it "supports different operators" do
      # Greater than
      condition = { metric: "errors.total", op: "gt", value: 5 }
      stats = { errors: { total: 10 } }
      expect(manager.send(:evaluate_hash_condition, condition, stats)).to be true

      # Less than
      condition = { metric: "errors.total", op: "lt", value: 5 }
      expect(manager.send(:evaluate_hash_condition, condition, stats)).to be false

      # Equal
      condition = { metric: "errors.total", op: "eq", value: 10 }
      expect(manager.send(:evaluate_hash_condition, condition, stats)).to be true
    end
  end

  describe "#start_monitoring and #stop_monitoring" do
    it "starts background monitoring" do
      manager.start_monitoring(interval: 1)
      sleep 0.1

      expect(manager.instance_variable_get(:@monitoring_thread)).to be_alive

      manager.stop_monitoring
      sleep 0.1

      expect(manager.instance_variable_get(:@monitoring_thread)).to be_nil
    end
  end

  describe "thread safety" do
    it "handles concurrent rule additions" do
      threads = 10.times.map do |i|
        Thread.new do
          manager.add_rule(name: "Rule #{i}", condition: ->(_) { false })
        end
      end

      threads.each(&:join)

      expect(manager.rules.size).to eq(10)
    end

    it "handles concurrent alert checks" do
      manager.add_rule(name: "Test", condition: ->(_) { true })

      threads = 5.times.map do
        Thread.new { manager.check_rules }
      end

      expect { threads.each(&:join) }.not_to raise_error
    end
  end
end
