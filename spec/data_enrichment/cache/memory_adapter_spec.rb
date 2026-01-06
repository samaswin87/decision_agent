# frozen_string_literal: true

require "spec_helper"

RSpec.describe DecisionAgent::DataEnrichment::Cache::MemoryAdapter do
  let(:adapter) { described_class.new }

  describe "#set and #get" do
    it "stores and retrieves cached values" do
      adapter.set("test_key", { data: "value" }, 60)

      result = adapter.get("test_key")
      expect(result).to eq({ data: "value" })
    end

    it "returns nil for non-existent keys" do
      result = adapter.get("nonexistent")
      expect(result).to be_nil
    end

    it "expires cached values after TTL" do
      adapter.set("test_key", { data: "value" }, 1)
      sleep(1.1)

      result = adapter.get("test_key")
      expect(result).to be_nil
    end

    it "handles concurrent access" do
      threads = []
      10.times do |i|
        threads << Thread.new do
          adapter.set("key_#{i}", { value: i }, 60)
          adapter.get("key_#{i}")
        end
      end

      threads.each(&:join)
      expect(adapter.get("key_0")).to eq({ value: 0 })
    end
  end

  describe "#delete" do
    it "deletes cached values" do
      adapter.set("test_key", { data: "value" }, 60)
      adapter.delete("test_key")

      expect(adapter.get("test_key")).to be_nil
    end
  end

  describe "#clear" do
    it "clears all cached values" do
      adapter.set("key1", { data: "value1" }, 60)
      adapter.set("key2", { data: "value2" }, 60)
      adapter.clear

      expect(adapter.get("key1")).to be_nil
      expect(adapter.get("key2")).to be_nil
    end
  end

  describe "#cache_key" do
    it "generates consistent cache keys" do
      key1 = adapter.cache_key(:endpoint, { param1: "value1", param2: "value2" })
      key2 = adapter.cache_key(:endpoint, { param2: "value2", param1: "value1" })

      expect(key1).to eq(key2)
    end
  end

  describe "#stats" do
    it "returns cache statistics" do
      adapter.set("key1", { data: "value1" }, 60)
      adapter.set("key2", { data: "value2" }, 60)

      stats = adapter.stats
      expect(stats[:size]).to eq(2)
      expect(stats[:valid]).to eq(2)
      expect(stats[:expired]).to eq(0)
    end
  end
end
