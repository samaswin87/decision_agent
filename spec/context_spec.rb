require "spec_helper"

RSpec.describe DecisionAgent::Context do
  describe "#initialize" do
    it "accepts a hash and freezes it" do
      context = DecisionAgent::Context.new({ user: "alice" })

      expect(context.to_h).to eq({ user: "alice" })
      expect(context.to_h).to be_frozen
    end

    it "converts non-hash to empty hash" do
      context = DecisionAgent::Context.new("not a hash")

      expect(context.to_h).to eq({})
    end

    it "deep freezes nested hashes" do
      data = { user: { name: "alice", roles: ["admin"] } }
      context = DecisionAgent::Context.new(data)

      expect(context.to_h[:user]).to be_frozen
      expect(context.to_h[:user][:roles]).to be_frozen
    end
  end

  describe "#[]" do
    it "retrieves values by key" do
      context = DecisionAgent::Context.new({ status: "active" })

      expect(context[:status]).to eq("active")
    end

    it "returns nil for missing keys" do
      context = DecisionAgent::Context.new({})

      expect(context[:missing]).to be_nil
    end
  end

  describe "#fetch" do
    it "retrieves values by key" do
      context = DecisionAgent::Context.new({ priority: "high" })

      expect(context.fetch(:priority)).to eq("high")
    end

    it "returns default for missing keys" do
      context = DecisionAgent::Context.new({})

      expect(context.fetch(:missing, "default")).to eq("default")
    end
  end

  describe "#key?" do
    it "returns true when key exists" do
      context = DecisionAgent::Context.new({ user: "alice" })

      expect(context.key?(:user)).to be true
    end

    it "returns false when key does not exist" do
      context = DecisionAgent::Context.new({})

      expect(context.key?(:user)).to be false
    end
  end

  describe "#==" do
    it "compares contexts by data equality" do
      context1 = DecisionAgent::Context.new({ user: "alice" })
      context2 = DecisionAgent::Context.new({ user: "alice" })

      expect(context1).to eq(context2)
    end

    it "returns false for different data" do
      context1 = DecisionAgent::Context.new({ user: "alice" })
      context2 = DecisionAgent::Context.new({ user: "bob" })

      expect(context1).not_to eq(context2)
    end
  end
end
