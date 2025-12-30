require "spec_helper"

RSpec.describe DecisionAgent::Auth::PermissionChecker do
  let(:checker) { DecisionAgent::Auth::PermissionChecker.new }

  describe "#can?" do
    let(:admin_user) do
      DecisionAgent::Auth::User.new(
        email: "admin@example.com",
        password: "password123",
        roles: [:admin]
      )
    end

    let(:editor_user) do
      DecisionAgent::Auth::User.new(
        email: "editor@example.com",
        password: "password123",
        roles: [:editor]
      )
    end

    let(:viewer_user) do
      DecisionAgent::Auth::User.new(
        email: "viewer@example.com",
        password: "password123",
        roles: [:viewer]
      )
    end

    it "returns true if user has permission" do
      expect(checker.can?(admin_user, :write)).to be true
      expect(checker.can?(editor_user, :write)).to be true
      expect(checker.can?(viewer_user, :read)).to be true
    end

    it "returns false if user lacks permission" do
      expect(checker.can?(viewer_user, :write)).to be false
      expect(checker.can?(editor_user, :delete)).to be false
    end

    it "returns false for nil user" do
      expect(checker.can?(nil, :read)).to be false
    end

    it "returns false for inactive user" do
      admin_user.active = false
      expect(checker.can?(admin_user, :read)).to be false
    end
  end

  describe "#require_permission!" do
    let(:user) do
      DecisionAgent::Auth::User.new(
        email: "user@example.com",
        password: "password123",
        roles: [:viewer]
      )
    end

    it "does not raise if user has permission" do
      expect do
        checker.require_permission!(user, :read)
      end.not_to raise_error
    end

    it "raises PermissionDeniedError if user lacks permission" do
      expect do
        checker.require_permission!(user, :write)
      end.to raise_error(DecisionAgent::PermissionDeniedError)
    end
  end

  describe "#has_role?" do
    let(:user) do
      DecisionAgent::Auth::User.new(
        email: "user@example.com",
        password: "password123",
        roles: [:editor]
      )
    end

    it "returns true if user has role" do
      expect(checker.has_role?(user, :editor)).to be true
    end

    it "returns false if user lacks role" do
      expect(checker.has_role?(user, :admin)).to be false
    end

    it "returns false for nil user" do
      expect(checker.has_role?(nil, :editor)).to be false
    end
  end

  describe "#require_role!" do
    let(:user) do
      DecisionAgent::Auth::User.new(
        email: "user@example.com",
        password: "password123",
        roles: [:editor]
      )
    end

    it "does not raise if user has role" do
      expect do
        checker.require_role!(user, :editor)
      end.not_to raise_error
    end

    it "returns true if user has role" do
      result = checker.require_role!(user, :editor)
      expect(result).to be true
    end

    it "raises PermissionDeniedError if user lacks role" do
      expect do
        checker.require_role!(user, :admin)
      end.to raise_error(DecisionAgent::PermissionDeniedError, /User does not have role: admin/)
    end
  end

  describe "#active?" do
    let(:user) do
      DecisionAgent::Auth::User.new(
        email: "user@example.com",
        password: "password123"
      )
    end

    it "returns true for active user" do
      user.active = true
      expect(checker.active?(user)).to be true
    end

    it "returns false for inactive user" do
      user.active = false
      expect(checker.active?(user)).to be false
    end

    it "returns true for user without active attribute" do
      user = double("User", id: "123", email: "test@example.com")
      expect(checker.active?(user)).to be true
    end

    it "returns false for nil user" do
      expect(checker.active?(nil)).to be false
    end
  end

  describe "#user_id" do
    let(:user) do
      DecisionAgent::Auth::User.new(
        email: "user@example.com",
        password: "password123"
      )
    end

    it "returns user id" do
      expect(checker.user_id(user)).to eq(user.id)
    end

    it "returns nil for nil user" do
      expect(checker.user_id(nil)).to be_nil
    end

    it "handles user without id method" do
      user = double("User", to_s: "user_string")
      expect(checker.user_id(user)).to eq("user_string")
    end
  end

  describe "#user_email" do
    let(:user) do
      DecisionAgent::Auth::User.new(
        email: "user@example.com",
        password: "password123"
      )
    end

    it "returns user email" do
      expect(checker.user_email(user)).to eq("user@example.com")
    end

    it "returns nil for nil user" do
      expect(checker.user_email(nil)).to be_nil
    end

    it "returns nil for user without email method" do
      user = double("User", id: "123")
      expect(checker.user_email(user)).to be_nil
    end
  end

  describe "#adapter" do
    it "uses default adapter when none provided" do
      checker = DecisionAgent::Auth::PermissionChecker.new
      expect(checker.adapter).to be_a(DecisionAgent::Auth::DefaultAdapter)
    end

    it "uses provided adapter" do
      custom_adapter = DecisionAgent::Auth::DefaultAdapter.new
      checker = DecisionAgent::Auth::PermissionChecker.new(adapter: custom_adapter)
      expect(checker.adapter).to eq(custom_adapter)
    end
  end
end
