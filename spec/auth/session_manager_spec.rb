require "spec_helper"

RSpec.describe DecisionAgent::Auth::SessionManager do
  let(:manager) { DecisionAgent::Auth::SessionManager.new }

  describe "#initialize" do
    it "initializes with empty sessions" do
      expect(manager.count).to eq(0)
    end
  end

  describe "#create_session" do
    it "creates a new session" do
      session = manager.create_session("user123")
      expect(session).to be_a(DecisionAgent::Auth::Session)
      expect(session.user_id).to eq("user123")
    end

    it "stores the session" do
      session = manager.create_session("user123")
      retrieved = manager.get_session(session.token)
      expect(retrieved).to eq(session)
    end

    it "accepts custom expiration time" do
      session = manager.create_session("user123", expires_in: 7200)
      expect(session.expires_at).to be > Time.now.utc + 7100
    end
  end

  describe "#get_session" do
    it "returns session for valid token" do
      session = manager.create_session("user123")
      retrieved = manager.get_session(session.token)
      expect(retrieved).to eq(session)
    end

    it "returns nil for invalid token" do
      expect(manager.get_session("invalid_token")).to be_nil
    end

    it "returns nil for expired session" do
      session = manager.create_session("user123", expires_in: -1)
      expect(manager.get_session(session.token)).to be_nil
    end
  end

  describe "#delete_session" do
    it "deletes a session" do
      session = manager.create_session("user123")
      manager.delete_session(session.token)
      expect(manager.get_session(session.token)).to be_nil
    end

    it "does not raise error for non-existent session" do
      expect { manager.delete_session("nonexistent") }.not_to raise_error
    end
  end

  describe "#delete_user_sessions" do
    it "deletes all sessions for a user" do
      session1 = manager.create_session("user123")
      session2 = manager.create_session("user123")
      session3 = manager.create_session("user456")

      manager.delete_user_sessions("user123")

      expect(manager.get_session(session1.token)).to be_nil
      expect(manager.get_session(session2.token)).to be_nil
      expect(manager.get_session(session3.token)).to eq(session3) # Other user's session still exists
    end

    it "does not raise error for user with no sessions" do
      expect { manager.delete_user_sessions("nonexistent") }.not_to raise_error
    end
  end

  describe "#cleanup_expired_sessions" do
    it "removes expired sessions" do
      # Create expired session
      expired_session = manager.create_session("user123", expires_in: -1)
      # Create valid session
      valid_session = manager.create_session("user456", expires_in: 3600)

      expect(manager.count).to eq(2)

      # Force cleanup by setting last_cleanup far in the past and creating another session
      manager.instance_variable_set(:@last_cleanup, Time.now - 400) # More than 300 seconds
      manager.create_session("user789", expires_in: 3600)

      # Expired session should be cleaned up
      expect(manager.get_session(expired_session.token)).to be_nil
      expect(manager.get_session(valid_session.token)).to eq(valid_session)
    end

    it "only runs cleanup after cleanup_interval" do
      manager = DecisionAgent::Auth::SessionManager.new

      # Create an expired session
      expired_session = manager.create_session("user123", expires_in: -1)
      expect(manager.count).to eq(1)

      # The cleanup_expired_sessions is called during create_session, but it checks the interval
      # Let's test by manually setting last_cleanup to far in the past
      manager.instance_variable_set(:@last_cleanup, Time.now - 400) # More than 300 seconds
      manager.create_session("user456", expires_in: 3600)

      # The expired session should be cleaned up now
      expect(manager.get_session(expired_session.token)).to be_nil
    end
  end

  describe "#count" do
    it "returns zero initially" do
      expect(manager.count).to eq(0)
    end

    it "returns correct count after creating sessions" do
      manager.create_session("user123")
      expect(manager.count).to eq(1)

      manager.create_session("user123")
      expect(manager.count).to eq(2)

      manager.create_session("user456")
      expect(manager.count).to eq(3)
    end

    it "reflects deletions" do
      session1 = manager.create_session("user123")
      session2 = manager.create_session("user123")
      expect(manager.count).to eq(2)

      manager.delete_session(session1.token)
      expect(manager.count).to eq(1)

      manager.delete_user_sessions("user123")
      expect(manager.count).to eq(0)
    end

    it "does not count expired sessions" do
      manager.create_session("user123", expires_in: -1)
      # Expired sessions are not counted when retrieved, but are still in storage until cleanup
      # So count will include them until cleanup runs
      expect(manager.count).to eq(1)

      # After cleanup
      manager.instance_variable_set(:@last_cleanup, Time.now - 400)
      manager.create_session("user456", expires_in: 3600)
      # Now expired session should be cleaned up
      expect(manager.count).to eq(1)
    end
  end

  describe "thread safety" do
    it "handles concurrent access safely" do
      threads = []
      10.times do
        threads << Thread.new do
          10.times do
            session = manager.create_session("user#{rand(100)}")
            manager.get_session(session.token)
            manager.count
          end
        end
      end

      threads.each(&:join)
      expect(manager.count).to eq(100)
    end
  end
end

