require "spec_helper"

RSpec.describe DecisionAgent::Auth::Role do
  describe ".all" do
    it "returns all role symbols" do
      roles = DecisionAgent::Auth::Role.all
      expect(roles).to include(:admin, :editor, :viewer, :auditor, :approver)
    end
  end

  describe ".exists?" do
    it "returns true for valid roles" do
      expect(DecisionAgent::Auth::Role.exists?(:admin)).to be true
      expect(DecisionAgent::Auth::Role.exists?(:editor)).to be true
    end

    it "returns false for invalid roles" do
      expect(DecisionAgent::Auth::Role.exists?(:invalid)).to be false
    end
  end

  describe ".permissions_for" do
    it "returns permissions for admin role" do
      permissions = DecisionAgent::Auth::Role.permissions_for(:admin)
      expect(permissions).to include(:read, :write, :delete, :approve, :deploy, :manage_users, :audit)
    end

    it "returns permissions for editor role" do
      permissions = DecisionAgent::Auth::Role.permissions_for(:editor)
      expect(permissions).to include(:read, :write)
    end

    it "returns permissions for viewer role" do
      permissions = DecisionAgent::Auth::Role.permissions_for(:viewer)
      expect(permissions).to include(:read)
    end

    it "returns empty array for invalid role" do
      permissions = DecisionAgent::Auth::Role.permissions_for(:invalid)
      expect(permissions).to eq([])
    end
  end

  describe ".has_permission?" do
    it "returns true if role has permission" do
      expect(DecisionAgent::Auth::Role.has_permission?(:admin, :write)).to be true
      expect(DecisionAgent::Auth::Role.has_permission?(:editor, :write)).to be true
      expect(DecisionAgent::Auth::Role.has_permission?(:viewer, :write)).to be false
    end
  end
end
