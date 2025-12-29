require "spec_helper"

RSpec.describe DecisionAgent::Auth::Session do
  describe "#initialize" do
    it "creates a session with user_id" do
      session = DecisionAgent::Auth::Session.new(user_id: "user123")
      expect(session.user_id).to eq("user123")
      expect(session.token).to be_a(String)
      expect(session.token.length).to eq(64) # 32 bytes hex = 64 chars
    end

    it "sets expiration time" do
      session = DecisionAgent::Auth::Session.new(user_id: "user123", expires_in: 1800)
      expect(session.expires_at).to be > Time.now.utc
      expect(session.expires_at).to be <= Time.now.utc + 1801
    end

    it "uses default expiration of 3600 seconds" do
      session = DecisionAgent::Auth::Session.new(user_id: "user123")
      expected_expiry = session.created_at + 3600
      expect(session.expires_at).to be_within(1).of(expected_expiry)
    end
  end

  describe "#expired?" do
    it "returns false for valid session" do
      session = DecisionAgent::Auth::Session.new(user_id: "user123", expires_in: 3600)
      expect(session.expired?).to be false
    end

    it "returns true for expired session" do
      session = DecisionAgent::Auth::Session.new(user_id: "user123", expires_in: -1)
      expect(session.expired?).to be true
    end
  end

  describe "#valid?" do
    it "returns true for non-expired session" do
      session = DecisionAgent::Auth::Session.new(user_id: "user123", expires_in: 3600)
      expect(session.valid?).to be true
    end

    it "returns false for expired session" do
      session = DecisionAgent::Auth::Session.new(user_id: "user123", expires_in: -1)
      expect(session.valid?).to be false
    end

    it "returns false when expired? returns true" do
      session = DecisionAgent::Auth::Session.new(user_id: "user123", expires_in: -1)
      expect(session.expired?).to be true
      expect(session.valid?).to be false
    end

    it "returns true when expired? returns false" do
      session = DecisionAgent::Auth::Session.new(user_id: "user123", expires_in: 3600)
      expect(session.expired?).to be false
      expect(session.valid?).to be true
    end
  end

  describe "#to_h" do
    it "returns hash with all session attributes" do
      session = DecisionAgent::Auth::Session.new(user_id: "user123", expires_in: 3600)
      hash = session.to_h

      expect(hash).to be_a(Hash)
      expect(hash[:token]).to eq(session.token)
      expect(hash[:user_id]).to eq("user123")
      expect(hash[:created_at]).to be_a(String)
      expect(hash[:expires_at]).to be_a(String)
    end

    it "serializes timestamps as ISO8601 strings" do
      session = DecisionAgent::Auth::Session.new(user_id: "user123")
      hash = session.to_h

      expect { Time.iso8601(hash[:created_at]) }.not_to raise_error
      expect { Time.iso8601(hash[:expires_at]) }.not_to raise_error
    end

    it "includes correct user_id" do
      session = DecisionAgent::Auth::Session.new(user_id: "user456")
      hash = session.to_h
      expect(hash[:user_id]).to eq("user456")
    end

    it "includes correct token" do
      session = DecisionAgent::Auth::Session.new(user_id: "user123")
      hash = session.to_h
      expect(hash[:token]).to eq(session.token)
    end
  end

  describe "#created_at" do
    it "is set to current UTC time" do
      before = Time.now.utc
      session = DecisionAgent::Auth::Session.new(user_id: "user123")
      after = Time.now.utc

      expect(session.created_at).to be >= before
      expect(session.created_at).to be <= after
    end
  end

  describe "#expires_at" do
    it "is set based on expires_in parameter" do
      session = DecisionAgent::Auth::Session.new(user_id: "user123", expires_in: 7200)
      expected = session.created_at + 7200
      expect(session.expires_at).to be_within(1).of(expected)
    end
  end
end

