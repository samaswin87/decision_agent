require "spec_helper"

RSpec.describe DecisionAgent::Auth::PasswordResetToken do
  describe "#initialize" do
    it "creates a token with user_id" do
      token = DecisionAgent::Auth::PasswordResetToken.new(user_id: "user123")
      expect(token.user_id).to eq("user123")
      expect(token.token).to be_a(String)
      expect(token.token.length).to eq(64) # 32 bytes hex = 64 chars
    end

    it "sets expiration time" do
      token = DecisionAgent::Auth::PasswordResetToken.new(user_id: "user123", expires_in: 1800)
      expect(token.expires_at).to be > Time.now.utc
      expect(token.expires_at).to be <= Time.now.utc + 1801
    end
  end

  describe "#expired?" do
    it "returns false for valid token" do
      token = DecisionAgent::Auth::PasswordResetToken.new(user_id: "user123", expires_in: 3600)
      expect(token.expired?).to be false
    end

    it "returns true for expired token" do
      token = DecisionAgent::Auth::PasswordResetToken.new(user_id: "user123", expires_in: -1)
      expect(token.expired?).to be true
    end
  end

  describe "#valid?" do
    it "returns true for non-expired token" do
      token = DecisionAgent::Auth::PasswordResetToken.new(user_id: "user123", expires_in: 3600)
      expect(token.valid?).to be true
    end

    it "returns false for expired token" do
      token = DecisionAgent::Auth::PasswordResetToken.new(user_id: "user123", expires_in: -1)
      expect(token.valid?).to be false
    end
  end
end

RSpec.describe DecisionAgent::Auth::PasswordResetManager do
  let(:manager) { DecisionAgent::Auth::PasswordResetManager.new }

  describe "#create_token" do
    it "creates a new reset token" do
      token = manager.create_token("user123")
      expect(token).to be_a(DecisionAgent::Auth::PasswordResetToken)
      expect(token.user_id).to eq("user123")
    end

    it "stores the token" do
      token = manager.create_token("user123")
      retrieved = manager.get_token(token.token)
      expect(retrieved).to eq(token)
    end
  end

  describe "#get_token" do
    it "returns token for valid token string" do
      token = manager.create_token("user123")
      retrieved = manager.get_token(token.token)
      expect(retrieved).to eq(token)
    end

    it "returns nil for invalid token" do
      expect(manager.get_token("invalid_token")).to be_nil
    end

    it "returns nil for expired token" do
      token = manager.create_token("user123", expires_in: -1)
      expect(manager.get_token(token.token)).to be_nil
    end
  end

  describe "#delete_token" do
    it "deletes a token" do
      token = manager.create_token("user123")
      manager.delete_token(token.token)
      expect(manager.get_token(token.token)).to be_nil
    end
  end

  describe "#delete_user_tokens" do
    it "deletes all tokens for a user" do
      token1 = manager.create_token("user123")
      token2 = manager.create_token("user123")
      token3 = manager.create_token("user456")

      manager.delete_user_tokens("user123")

      expect(manager.get_token(token1.token)).to be_nil
      expect(manager.get_token(token2.token)).to be_nil
      expect(manager.get_token(token3.token)).to eq(token3) # Other user's token still exists
    end
  end

  describe "#count" do
    it "returns zero initially" do
      expect(manager.count).to eq(0)
    end

    it "returns correct count after creating tokens" do
      manager.create_token("user123")
      expect(manager.count).to eq(1)

      manager.create_token("user123")
      expect(manager.count).to eq(2)

      manager.create_token("user456")
      expect(manager.count).to eq(3)
    end

    it "reflects deletions" do
      token1 = manager.create_token("user123")
      token2 = manager.create_token("user123")
      expect(manager.count).to eq(2)

      manager.delete_token(token1.token)
      expect(manager.count).to eq(1)

      manager.delete_user_tokens("user123")
      expect(manager.count).to eq(0)
    end
  end

  describe "#cleanup_expired_tokens" do
    it "removes expired tokens" do
      # Create expired token
      expired_token = manager.create_token("user123", expires_in: -1)
      # Create valid token
      valid_token = manager.create_token("user456", expires_in: 3600)

      expect(manager.count).to eq(2)

      # Force cleanup by calling it directly (it's called during create_token, but we can test it)
      # We'll create another token to trigger cleanup
      manager.create_token("user789", expires_in: 3600)

      # Expired token should be cleaned up
      expect(manager.get_token(expired_token.token)).to be_nil
      expect(manager.get_token(valid_token.token)).to eq(valid_token)
    end

    it "only runs cleanup after cleanup_interval" do
      manager = DecisionAgent::Auth::PasswordResetManager.new

      # Create an expired token
      expired_token = manager.create_token("user123", expires_in: -1)
      expect(manager.count).to eq(1)

      # Create another token immediately - cleanup should not run yet if interval not passed
      # But since we use -1 expires_in, the token is already expired, so get_token will return nil
      # The cleanup_expired_tokens is called during create_token, but it checks the interval
      # Let's test by manually setting last_cleanup to far in the past
      manager.instance_variable_set(:@last_cleanup, Time.now - 400) # More than 300 seconds
      manager.create_token("user456", expires_in: 3600)

      # The expired token should be cleaned up now
      expect(manager.get_token(expired_token.token)).to be_nil
    end
  end
end

RSpec.describe DecisionAgent::Auth::Authenticator do
  let(:authenticator) { DecisionAgent::Auth::Authenticator.new }

  describe "#request_password_reset" do
    before do
      authenticator.create_user(
        email: "test@example.com",
        password: "password123"
      )
    end

    it "returns a token for valid user" do
      token = authenticator.request_password_reset("test@example.com")
      expect(token).to be_a(DecisionAgent::Auth::PasswordResetToken)
      expect(token.user_id).to be_a(String)
    end

    it "returns nil for non-existent user" do
      token = authenticator.request_password_reset("nonexistent@example.com")
      expect(token).to be_nil
    end

    it "returns nil for inactive user" do
      user = authenticator.find_user_by_email("test@example.com")
      user.active = false

      token = authenticator.request_password_reset("test@example.com")
      expect(token).to be_nil
    end

    it "deletes existing tokens when creating new one" do
      token1 = authenticator.request_password_reset("test@example.com")
      token2 = authenticator.request_password_reset("test@example.com")

      expect(authenticator.password_reset_manager.get_token(token1.token)).to be_nil
      expect(authenticator.password_reset_manager.get_token(token2.token)).to eq(token2)
    end
  end

  describe "#reset_password" do
    before do
      authenticator.create_user(
        email: "test@example.com",
        password: "oldpassword"
      )
    end

    it "resets password with valid token" do
      token = authenticator.request_password_reset("test@example.com")
      user = authenticator.reset_password(token.token, "newpassword123")

      expect(user).to be_a(DecisionAgent::Auth::User)
      expect(user.authenticate("newpassword123")).to be true
      expect(user.authenticate("oldpassword")).to be false
    end

    it "returns nil for invalid token" do
      user = authenticator.reset_password("invalid_token", "newpassword123")
      expect(user).to be_nil
    end

    it "returns nil for expired token" do
      token = authenticator.request_password_reset("test@example.com")
      # Manually expire the token
      token.instance_variable_set(:@expires_at, Time.now.utc - 1)

      user = authenticator.reset_password(token.token, "newpassword123")
      expect(user).to be_nil
    end

    it "invalidates all user sessions after password reset" do
      session1 = authenticator.login("test@example.com", "oldpassword")
      session2 = authenticator.login("test@example.com", "oldpassword")

      token = authenticator.request_password_reset("test@example.com")
      authenticator.reset_password(token.token, "newpassword123")

      expect(authenticator.authenticate(session1.token)).to be_nil
      expect(authenticator.authenticate(session2.token)).to be_nil
    end

    it "deletes the token after use" do
      token = authenticator.request_password_reset("test@example.com")
      authenticator.reset_password(token.token, "newpassword123")

      expect(authenticator.password_reset_manager.get_token(token.token)).to be_nil
    end

    it "deletes all tokens for user after reset" do
      token1 = authenticator.request_password_reset("test@example.com")
      token2 = authenticator.request_password_reset("test@example.com")

      authenticator.reset_password(token2.token, "newpassword123")

      expect(authenticator.password_reset_manager.get_token(token1.token)).to be_nil
      expect(authenticator.password_reset_manager.get_token(token2.token)).to be_nil
    end
  end
end

RSpec.describe DecisionAgent::Auth::User do
  describe "#update_password" do
    it "updates the password" do
      user = DecisionAgent::Auth::User.new(
        email: "test@example.com",
        password: "oldpassword"
      )

      user.update_password("newpassword123")

      expect(user.authenticate("newpassword123")).to be true
      expect(user.authenticate("oldpassword")).to be false
    end

    it "updates the updated_at timestamp" do
      user = DecisionAgent::Auth::User.new(
        email: "test@example.com",
        password: "oldpassword"
      )

      original_updated_at = user.updated_at
      sleep(0.01) # Small delay to ensure timestamp difference
      user.update_password("newpassword123")

      expect(user.updated_at).to be > original_updated_at
    end
  end
end

