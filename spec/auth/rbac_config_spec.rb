require "spec_helper"

RSpec.describe DecisionAgent::Auth::RbacConfig do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "initializes with nil adapter, authenticator, and user_store" do
      expect(config.instance_variable_get(:@adapter)).to be_nil
      expect(config.authenticator).to be_nil
      expect(config.user_store).to be_nil
    end
  end

  describe "#use" do
    it "configures default adapter" do
      config.use(:default)
      expect(config.adapter).to be_a(DecisionAgent::Auth::DefaultAdapter)
    end

    it "configures devise_cancan adapter" do
      config.use(:devise_cancan)
      expect(config.adapter).to be_a(DecisionAgent::Auth::DeviseCanCanAdapter)
    end

    it "configures pundit adapter" do
      config.use(:pundit)
      expect(config.adapter).to be_a(DecisionAgent::Auth::PunditAdapter)
    end

    it "configures custom adapter" do
      config.use(:custom)
      expect(config.adapter).to be_a(DecisionAgent::Auth::CustomAdapter)
    end

    it "raises error for unknown adapter type" do
      expect do
        config.use(:unknown)
      end.to raise_error(ArgumentError, /Unknown adapter type/)
    end

    it "returns self for chaining" do
      result = config.use(:default)
      expect(result).to eq(config)
    end
  end

  describe "#adapter=" do
    it "sets custom adapter instance" do
      custom_adapter = DecisionAgent::Auth::DefaultAdapter.new
      config.adapter = custom_adapter
      expect(config.adapter).to eq(custom_adapter)
    end

    it "raises error for non-RbacAdapter instance" do
      expect do
        config.adapter = "not an adapter"
      end.to raise_error(ArgumentError, /must be an instance of DecisionAgent::Auth::RbacAdapter/)
    end
  end

  describe "#adapter" do
    it "returns configured adapter" do
      config.use(:default)
      expect(config.adapter).to be_a(DecisionAgent::Auth::DefaultAdapter)
    end

    it "returns default adapter if none configured" do
      expect(config.adapter).to be_a(DecisionAgent::Auth::DefaultAdapter)
    end
  end

  describe "#configured?" do
    it "returns false when no adapter configured" do
      expect(config.configured?).to be false
    end

    it "returns true when adapter configured" do
      config.use(:default)
      expect(config.configured?).to be true
    end
  end
end
