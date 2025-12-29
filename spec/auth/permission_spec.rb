require "spec_helper"

RSpec.describe DecisionAgent::Auth::Permission do
  describe ".all" do
    it "returns all permission symbols" do
      permissions = DecisionAgent::Auth::Permission.all
      expect(permissions).to be_an(Array)
      expect(permissions).to include(:read, :write, :delete, :approve, :deploy, :manage_users, :audit)
    end

    it "returns only symbol keys" do
      permissions = DecisionAgent::Auth::Permission.all
      expect(permissions.all? { |p| p.is_a?(Symbol) }).to be true
    end
  end

  describe ".exists?" do
    it "returns true for valid permissions" do
      expect(DecisionAgent::Auth::Permission.exists?(:read)).to be true
      expect(DecisionAgent::Auth::Permission.exists?(:write)).to be true
      expect(DecisionAgent::Auth::Permission.exists?(:delete)).to be true
      expect(DecisionAgent::Auth::Permission.exists?(:approve)).to be true
      expect(DecisionAgent::Auth::Permission.exists?(:deploy)).to be true
      expect(DecisionAgent::Auth::Permission.exists?(:manage_users)).to be true
      expect(DecisionAgent::Auth::Permission.exists?(:audit)).to be true
    end

    it "converts string to symbol" do
      expect(DecisionAgent::Auth::Permission.exists?("read")).to be true
      expect(DecisionAgent::Auth::Permission.exists?("write")).to be true
    end

    it "returns false for invalid permissions" do
      expect(DecisionAgent::Auth::Permission.exists?(:invalid)).to be false
      expect(DecisionAgent::Auth::Permission.exists?("invalid")).to be false
      expect(DecisionAgent::Auth::Permission.exists?(:unknown)).to be false
    end

    it "raises error for nil (not handled)" do
      expect do
        DecisionAgent::Auth::Permission.exists?(nil)
      end.to raise_error(NoMethodError)
    end
  end

  describe ".description_for" do
    it "returns description for valid permissions" do
      expect(DecisionAgent::Auth::Permission.description_for(:read)).to eq("Read access to rules and versions")
      expect(DecisionAgent::Auth::Permission.description_for(:write)).to eq("Create and modify rules")
      expect(DecisionAgent::Auth::Permission.description_for(:delete)).to eq("Delete rules and versions")
      expect(DecisionAgent::Auth::Permission.description_for(:approve)).to eq("Approve rule changes")
      expect(DecisionAgent::Auth::Permission.description_for(:deploy)).to eq("Deploy rule versions")
      expect(DecisionAgent::Auth::Permission.description_for(:manage_users)).to eq("Manage users and roles")
      expect(DecisionAgent::Auth::Permission.description_for(:audit)).to eq("Access audit logs")
    end

    it "converts string to symbol" do
      expect(DecisionAgent::Auth::Permission.description_for("read")).to eq("Read access to rules and versions")
      expect(DecisionAgent::Auth::Permission.description_for("write")).to eq("Create and modify rules")
    end

    it "returns nil for invalid permissions" do
      expect(DecisionAgent::Auth::Permission.description_for(:invalid)).to be_nil
      expect(DecisionAgent::Auth::Permission.description_for("invalid")).to be_nil
    end

    it "raises error for nil (not handled)" do
      expect do
        DecisionAgent::Auth::Permission.description_for(nil)
      end.to raise_error(NoMethodError)
    end
  end
end

