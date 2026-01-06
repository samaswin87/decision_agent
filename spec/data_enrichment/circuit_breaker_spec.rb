# frozen_string_literal: true

require "spec_helper"

RSpec.describe DecisionAgent::DataEnrichment::CircuitBreaker do
  let(:breaker) { described_class.new(failure_threshold: 3, timeout: 1, success_threshold: 2) }

  describe "#call" do
    it "executes block when circuit is closed" do
      result = breaker.call { "success" }
      expect(result).to eq("success")
    end

    it "opens circuit after failure threshold is reached" do
      3.times do
        breaker.call { raise StandardError, "error" }
      rescue StandardError
        # Expected
      end

      expect(breaker.open?).to be true
      expect { breaker.call { "should not execute" } }.to raise_error(DecisionAgent::DataEnrichment::CircuitBreaker::CircuitOpenError)
    end

    it "closes circuit after timeout and successful calls" do
      # Open the circuit
      3.times do
        breaker.call { raise StandardError, "error" }
      rescue StandardError
        # Expected
      end

      expect(breaker.open?).to be true

      # Wait for timeout
      sleep(1.1)

      # Half-open state: need success_threshold successful calls
      2.times do
        breaker.call { "success" }
      end

      expect(breaker.state).to eq(described_class::CLOSED)
    end

    it "records success and resets failure count" do
      # Fail once
      begin
        breaker.call { raise StandardError }
      rescue StandardError
        # Expected
      end

      # Success should reset failure count
      breaker.call { "success" }
      expect(breaker.state).to eq(described_class::CLOSED)
    end
  end

  describe "#reset" do
    it "resets circuit breaker to closed state" do
      # Open the circuit
      3.times do
        breaker.call { raise StandardError }
      rescue StandardError
        # Expected
      end

      breaker.reset
      expect(breaker.state).to eq(described_class::CLOSED)
    end
  end

  describe "#state" do
    it "returns current state" do
      expect(breaker.state).to eq(described_class::CLOSED)
    end
  end
end
