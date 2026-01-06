# frozen_string_literal: true

require "spec_helper"

RSpec.describe DecisionAgent::DataEnrichment::Config do
  describe "#initialize" do
    it "initializes with default values" do
      config = described_class.new

      expect(config.endpoints).to eq({})
      expect(config.default_timeout).to eq(5)
      expect(config.default_retry).to eq({ max_attempts: 3, backoff: :exponential })
      expect(config.default_cache).to eq({ ttl: 3600, adapter: :memory })
    end
  end

  describe "#add_endpoint" do
    it "adds an endpoint configuration" do
      config = described_class.new
      config.add_endpoint(
        :credit_bureau,
        url: "https://api.example.com/score",
        method: :post,
        auth: { type: :api_key, header: "X-API-Key" },
        cache: { ttl: 3600, adapter: :memory },
        retry_config: { max_attempts: 3, backoff: :exponential }
      )

      endpoint = config.endpoint(:credit_bureau)
      expect(endpoint).not_to be_nil
      expect(endpoint[:url]).to eq("https://api.example.com/score")
      expect(endpoint[:method]).to eq(:post)
      expect(endpoint[:auth][:type]).to eq(:api_key)
    end

    it "uses default values when options are not provided" do
      config = described_class.new
      config.add_endpoint(:test_endpoint, url: "https://api.example.com")

      endpoint = config.endpoint(:test_endpoint)
      expect(endpoint[:timeout]).to eq(5)
      expect(endpoint[:cache]).to eq({ ttl: 3600, adapter: :memory })
      expect(endpoint[:retry]).to eq({ max_attempts: 3, backoff: :exponential })
    end
  end

  describe "#endpoint" do
    it "returns endpoint configuration" do
      config = described_class.new
      config.add_endpoint(:test, url: "https://api.example.com")

      endpoint = config.endpoint(:test)
      expect(endpoint).to be_a(Hash)
      expect(endpoint[:url]).to eq("https://api.example.com")
    end

    it "returns nil for non-existent endpoint" do
      config = described_class.new
      expect(config.endpoint(:nonexistent)).to be_nil
    end
  end

  describe "#endpoint?" do
    it "returns true for existing endpoint" do
      config = described_class.new
      config.add_endpoint(:test, url: "https://api.example.com")

      expect(config.endpoint?(:test)).to be true
    end

    it "returns false for non-existent endpoint" do
      config = described_class.new
      expect(config.endpoint?(:nonexistent)).to be false
    end
  end

  describe "#remove_endpoint" do
    it "removes an endpoint" do
      config = described_class.new
      config.add_endpoint(:test, url: "https://api.example.com")
      config.remove_endpoint(:test)

      expect(config.endpoint?(:test)).to be false
    end
  end

  describe "#clear" do
    it "clears all endpoints" do
      config = described_class.new
      config.add_endpoint(:test1, url: "https://api1.example.com")
      config.add_endpoint(:test2, url: "https://api2.example.com")
      config.clear

      expect(config.endpoints).to eq({})
    end
  end
end
