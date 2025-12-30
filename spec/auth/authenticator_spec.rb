require "spec_helper"

RSpec.describe DecisionAgent::Auth::Authenticator do
  let(:authenticator) { DecisionAgent::Auth::Authenticator.new }

  describe "#create_user" do
    it "creates a new user" do
      user = authenticator.create_user(
        email: "test@example.com",
        password: "password123"
      )

      expect(user.email).to eq("test@example.com")
      expect(user.id).to be_a(String)
    end

    it "creates a user with roles" do
      user = authenticator.create_user(
        email: "admin@example.com",
        password: "password123",
        roles: %i[admin editor]
      )

      expect(user.roles).to include(:admin, :editor)
    end
  end

  describe "#login" do
    before do
      authenticator.create_user(
        email: "test@example.com",
        password: "password123"
      )
    end

    it "returns a session for valid credentials" do
      session = authenticator.login("test@example.com", "password123")

      expect(session).to be_a(DecisionAgent::Auth::Session)
      expect(session.user_id).to be_a(String)
    end

    it "returns nil for invalid email" do
      session = authenticator.login("wrong@example.com", "password123")
      expect(session).to be_nil
    end

    it "returns nil for invalid password" do
      session = authenticator.login("test@example.com", "wrongpassword")
      expect(session).to be_nil
    end

    it "returns nil for inactive user" do
      user = authenticator.find_user_by_email("test@example.com")
      user.active = false

      session = authenticator.login("test@example.com", "password123")
      expect(session).to be_nil
    end
  end

  describe "#logout" do
    it "deletes the session" do
      authenticator.create_user(
        email: "test@example.com",
        password: "password123"
      )

      session = authenticator.login("test@example.com", "password123")
      token = session.token

      authenticator.logout(token)

      expect(authenticator.authenticate(token)).to be_nil
    end
  end

  describe "#authenticate" do
    it "returns user and session for valid token" do
      authenticator.create_user(
        email: "test@example.com",
        password: "password123"
      )

      session = authenticator.login("test@example.com", "password123")
      result = authenticator.authenticate(session.token)

      expect(result).to be_a(Hash)
      expect(result[:user]).to be_a(DecisionAgent::Auth::User)
      expect(result[:session]).to be_a(DecisionAgent::Auth::Session)
    end

    it "returns nil for invalid token" do
      result = authenticator.authenticate("invalid_token")
      expect(result).to be_nil
    end

    it "returns nil for expired session" do
      authenticator.create_user(
        email: "test@example.com",
        password: "password123"
      )

      session = authenticator.login("test@example.com", "password123")
      # Manually expire the session
      session.instance_variable_set(:@expires_at, Time.now.utc - 1)

      result = authenticator.authenticate(session.token)
      expect(result).to be_nil
    end
  end
end
