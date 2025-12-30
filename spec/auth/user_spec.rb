require "spec_helper"

RSpec.describe DecisionAgent::Auth::User do
  describe "#initialize" do
    it "creates a user with email and password" do
      user = DecisionAgent::Auth::User.new(
        email: "test@example.com",
        password: "password123"
      )

      expect(user.email).to eq("test@example.com")
      expect(user.id).to be_a(String)
      expect(user.active).to be true
      expect(user.roles).to eq([])
    end

    it "creates a user with roles" do
      user = DecisionAgent::Auth::User.new(
        email: "admin@example.com",
        password: "password123",
        roles: %i[admin editor]
      )

      expect(user.roles).to include(:admin, :editor)
    end

    it "raises error if neither password nor password_hash provided" do
      expect do
        DecisionAgent::Auth::User.new(email: "test@example.com")
      end.to raise_error(ArgumentError, /password/)
    end
  end

  describe "#authenticate" do
    it "returns true for correct password" do
      user = DecisionAgent::Auth::User.new(
        email: "test@example.com",
        password: "password123"
      )

      expect(user.authenticate("password123")).to be true
    end

    it "returns false for incorrect password" do
      user = DecisionAgent::Auth::User.new(
        email: "test@example.com",
        password: "password123"
      )

      expect(user.authenticate("wrongpassword")).to be false
    end

    it "returns false for inactive user" do
      user = DecisionAgent::Auth::User.new(
        email: "test@example.com",
        password: "password123",
        active: false
      )

      expect(user.authenticate("password123")).to be false
    end
  end

  describe "#assign_role" do
    it "adds a role to the user" do
      user = DecisionAgent::Auth::User.new(
        email: "test@example.com",
        password: "password123"
      )

      user.assign_role(:editor)
      expect(user.roles).to include(:editor)
    end

    it "does not add duplicate roles" do
      user = DecisionAgent::Auth::User.new(
        email: "test@example.com",
        password: "password123"
      )

      user.assign_role(:editor)
      user.assign_role(:editor)

      expect(user.roles.count(:editor)).to eq(1)
    end
  end

  describe "#remove_role" do
    it "removes a role from the user" do
      user = DecisionAgent::Auth::User.new(
        email: "test@example.com",
        password: "password123",
        roles: %i[editor viewer]
      )

      user.remove_role(:editor)
      expect(user.roles).not_to include(:editor)
      expect(user.roles).to include(:viewer)
    end
  end

  describe "#has_role?" do
    it "returns true if user has the role" do
      user = DecisionAgent::Auth::User.new(
        email: "test@example.com",
        password: "password123",
        roles: [:editor]
      )

      expect(user.has_role?(:editor)).to be true
      expect(user.has_role?(:admin)).to be false
    end
  end

  describe "#to_h" do
    it "returns a hash representation of the user" do
      user = DecisionAgent::Auth::User.new(
        email: "test@example.com",
        password: "password123",
        roles: [:editor]
      )

      hash = user.to_h
      expect(hash[:email]).to eq("test@example.com")
      expect(hash[:roles]).to eq(["editor"])
      expect(hash[:active]).to be true
      expect(hash[:id]).to be_a(String)
    end
  end
end
