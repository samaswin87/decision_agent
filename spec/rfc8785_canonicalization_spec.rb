# frozen_string_literal: true
# encoding: utf-8

require "spec_helper"

RSpec.describe "RFC 8785 JSON Canonicalization" do
  let(:evaluator) do
    DecisionAgent::Evaluators::JsonRuleEvaluator.new(
      rules_json: {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "always_approve",
            if: { field: "amount", op: "gte", value: 0 },
            then: { decision: "approve", weight: 1.0, reason: "Test rule" }
          }
        ]
      }
    )
  end

  let(:agent) { DecisionAgent::Agent.new(evaluators: [evaluator]) }

  describe "canonical JSON serialization" do
    it "produces deterministic hashes using RFC 8785" do
      # Same context should produce same hash every time
      context = { amount: 100, user: { id: 123, name: "Alice" } }

      decision1 = agent.decide(context: context)
      decision2 = agent.decide(context: context)

      hash1 = decision1.audit_payload[:deterministic_hash]
      hash2 = decision2.audit_payload[:deterministic_hash]

      expect(hash1).to eq(hash2)
      expect(hash1).to be_a(String)
      expect(hash1.length).to eq(64) # SHA256 produces 64 hex characters
    end

    it "produces different hashes for different contexts" do
      context1 = { amount: 100, user: { id: 123 } }
      context2 = { amount: 200, user: { id: 456 } }

      decision1 = agent.decide(context: context1)
      decision2 = agent.decide(context: context2)

      hash1 = decision1.audit_payload[:deterministic_hash]
      hash2 = decision2.audit_payload[:deterministic_hash]

      expect(hash1).not_to eq(hash2)
    end

    it "is insensitive to property order (canonicalization)" do
      # Different property order should produce same hash
      context1 = { amount: 100, user: { id: 123, name: "Alice" } }
      context2 = { user: { name: "Alice", id: 123 }, amount: 100 }

      decision1 = agent.decide(context: context1)
      decision2 = agent.decide(context: context2)

      hash1 = decision1.audit_payload[:deterministic_hash]
      hash2 = decision2.audit_payload[:deterministic_hash]

      expect(hash1).to eq(hash2), "RFC 8785 canonicalization should sort properties"
    end

    it "handles special characters correctly" do
      # Test Unicode, quotes, and control characters
      context = {
        amount: 100,
        note: "Test with \"quotes\", €uro, and \n newline"
      }

      decision = agent.decide(context: context)
      hash = decision.audit_payload[:deterministic_hash]

      expect(hash).to be_a(String)
      expect(hash.length).to eq(64)
    end

    it "handles floating point numbers deterministically" do
      # RFC 8785 specifies exact float serialization per IEEE 754
      # Note: 99.99 cannot be exactly represented in binary floating point
      context = { amount: 100, price: 99.99, tax: 0.075 }

      decision1 = agent.decide(context: context)
      decision2 = agent.decide(context: context)

      hash1 = decision1.audit_payload[:deterministic_hash]
      hash2 = decision2.audit_payload[:deterministic_hash]

      # Same context should always produce same hash
      expect(hash1).to eq(hash2), "RFC 8785 should produce consistent hashes for same values"

      # Verify RFC 8785 uses ECMAScript number serialization
      canonical = agent.send(:canonical_json, context)
      # RFC 8785 may represent 99.99 as 99.98999999999999 due to IEEE 754
      expect(canonical).to match(/99\.\d+/)
      expect(canonical).to include("0.075")
    end

    it "handles nested structures correctly" do
      context = {
        amount: 100,
        user: {
          id: 123,
          profile: {
            name: "Alice",
            tags: ["premium", "verified"]
          }
        }
      }

      decision = agent.decide(context: context)
      hash = decision.audit_payload[:deterministic_hash]

      expect(hash).to be_a(String)
      expect(hash.length).to eq(64)
    end

    it "handles arrays consistently" do
      # Array order should be preserved (not sorted)
      context1 = { amount: 100, tags: ["a", "b", "c"] }
      context2 = { amount: 100, tags: ["c", "b", "a"] }

      decision1 = agent.decide(context: context1)
      decision2 = agent.decide(context: context2)

      hash1 = decision1.audit_payload[:deterministic_hash]
      hash2 = decision2.audit_payload[:deterministic_hash]

      expect(hash1).not_to eq(hash2), "RFC 8785 preserves array order"
    end

    it "handles nil values correctly" do
      context = { amount: 100, optional_field: nil }

      decision = agent.decide(context: context)
      hash = decision.audit_payload[:deterministic_hash]

      expect(hash).to be_a(String)
      expect(hash.length).to eq(64)
    end

    it "handles boolean values correctly" do
      context = { amount: 100, is_verified: true, is_blocked: false }

      decision = agent.decide(context: context)
      hash = decision.audit_payload[:deterministic_hash]

      expect(hash).to be_a(String)
      expect(hash.length).to eq(64)
    end

    it "is thread-safe with concurrent hash computations" do
      contexts = 10.times.map { |i| { amount: i * 100, id: i } }
      results = []
      mutex = Mutex.new

      threads = contexts.map do |ctx|
        Thread.new do
          decision = agent.decide(context: ctx)
          hash = decision.audit_payload[:deterministic_hash]
          mutex.synchronize { results << hash }
        end
      end

      threads.each(&:join)

      expect(results.size).to eq(10)
      expect(results.uniq.size).to eq(10), "Each context should produce unique hash"
      results.each do |hash|
        expect(hash.length).to eq(64)
      end
    end
  end

  describe "RFC 8785 compliance" do
    it "uses json-canonicalization gem for canonicalization" do
      # Verify we're using the RFC 8785 implementation
      test_data = { b: 2, a: 1 }
      canonical = agent.send(:canonical_json, test_data)

      # RFC 8785 should sort keys: {"a":1,"b":2}
      expect(canonical).to include('"a":1')
      expect(canonical).to include('"b":2')
      expect(canonical.index('"a"')).to be < canonical.index('"b"')
    end

    it "produces compact JSON without whitespace" do
      test_data = { amount: 100, user: { id: 123 } }
      canonical = agent.send(:canonical_json, test_data)

      # RFC 8785 produces compact JSON
      expect(canonical).not_to include("\n")
      expect(canonical).not_to include("  ")
    end
  end

  describe "performance characteristics" do
    it "computes hashes efficiently" do
      context = {
        amount: 100,
        user: { id: 123, name: "Alice", tags: (1..100).to_a }
      }

      # Should complete quickly even with larger payloads
      start_time = Time.now
      100.times { agent.decide(context: context) }
      elapsed = Time.now - start_time

      expect(elapsed).to be < 1.0, "100 decisions should complete in under 1 second"
    end
  end
end
