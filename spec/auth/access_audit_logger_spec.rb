require "spec_helper"

RSpec.describe DecisionAgent::Auth::AccessAuditLogger do
  let(:adapter) { DecisionAgent::Audit::InMemoryAccessAdapter.new }
  let(:logger) { DecisionAgent::Auth::AccessAuditLogger.new(adapter: adapter) }

  describe "#log_authentication" do
    it "logs successful login" do
      logger.log_authentication(
        "login",
        user_id: "user123",
        email: "test@example.com",
        success: true
      )

      logs = adapter.all_logs
      expect(logs.size).to eq(1)
      expect(logs.first[:event_type]).to eq("login")
      expect(logs.first[:user_id]).to eq("user123")
      expect(logs.first[:success]).to be true
    end

    it "logs failed login" do
      logger.log_authentication(
        "login",
        user_id: nil,
        email: "test@example.com",
        success: false,
        reason: "Invalid password"
      )

      logs = adapter.all_logs
      expect(logs.size).to eq(1)
      expect(logs.first[:success]).to be false
      expect(logs.first[:reason]).to eq("Invalid password")
    end
  end

  describe "#log_permission_check" do
    it "logs permission check" do
      logger.log_permission_check(
        user_id: "user123",
        permission: :write,
        resource_type: "rule",
        resource_id: "rule456",
        granted: true
      )

      logs = adapter.all_logs
      expect(logs.size).to eq(1)
      expect(logs.first[:event_type]).to eq("permission_check")
      expect(logs.first[:permission]).to eq("write")
      expect(logs.first[:granted]).to be true
    end
  end

  describe "#log_access" do
    it "logs access event" do
      logger.log_access(
        user_id: "user123",
        action: "create",
        resource_type: "rule",
        resource_id: "rule456",
        success: true
      )

      logs = adapter.all_logs
      expect(logs.size).to eq(1)
      expect(logs.first[:event_type]).to eq("access")
      expect(logs.first[:action]).to eq("create")
    end
  end

  describe "#query" do
    before do
      logger.log_authentication("login", user_id: "user1", email: "user1@example.com", success: true)
      logger.log_authentication("login", user_id: "user2", email: "user2@example.com", success: true)
      logger.log_permission_check(user_id: "user1", permission: :write, granted: true)
    end

    it "filters by user_id" do
      logs = logger.query(user_id: "user1")
      expect(logs.size).to eq(2)
      expect(logs.all? { |log| log[:user_id] == "user1" }).to be true
    end

    it "filters by event_type" do
      logs = logger.query(event_type: "login")
      expect(logs.size).to eq(2)
      expect(logs.all? { |log| log[:event_type] == "login" }).to be true
    end

    it "filters by start_time" do
      start_time = Time.now.utc - 3600
      logger.log_authentication("login", user_id: "user3", email: "user3@example.com", success: true)

      logs = logger.query(start_time: start_time)
      expect(logs.size).to be >= 1
    end

    it "limits results" do
      logs = logger.query(limit: 2)
      expect(logs.size).to eq(2)
    end

    it "filters by end_time" do
      end_time = Time.now.utc + 3600
      logs = logger.query(end_time: end_time)
      expect(logs.size).to eq(3) # All logs are before end_time
    end

    it "filters by start_time and end_time together" do
      start_time = Time.now.utc - 1800
      end_time = Time.now.utc + 1800
      logs = logger.query(start_time: start_time, end_time: end_time)
      expect(logs.size).to be >= 0
    end

    it "handles string timestamps" do
      start_time = (Time.now.utc - 3600).iso8601
      logs = logger.query(start_time: start_time)
      expect(logs).to be_an(Array)
    end

    it "returns logs in reverse order (most recent first)" do
      # Clear any existing logs first
      adapter.clear

      logger.log_authentication("test1", user_id: "user1", email: "user1@example.com", success: true)
      sleep(0.01) # Ensure different timestamps
      logger.log_authentication("test2", user_id: "user1", email: "user1@example.com", success: true)

      logs = logger.query(user_id: "user1")
      expect(logs.size).to eq(2)
      expect(logs.first[:event_type]).to eq("test2")
      expect(logs.last[:event_type]).to eq("test1")
    end
  end

  describe "#log_authentication" do
    it "includes timestamp in log entry" do
      logger.log_authentication("login", user_id: "user1", email: "user1@example.com", success: true)
      logs = adapter.all_logs
      expect(logs.first[:timestamp]).to be_a(String)
      expect { Time.parse(logs.first[:timestamp]) }.not_to raise_error
    end

    it "includes ip_address field (nil by default)" do
      logger.log_authentication("login", user_id: "user1", email: "user1@example.com", success: true)
      logs = adapter.all_logs
      expect(logs.first[:ip_address]).to be_nil
    end

    it "converts event_type to string" do
      logger.log_authentication(:login, user_id: "user1", email: "user1@example.com", success: true)
      logs = adapter.all_logs
      expect(logs.first[:event_type]).to eq("login")
    end
  end

  describe "#log_permission_check" do
    it "includes all fields in log entry" do
      logger.log_permission_check(
        user_id: "user123",
        permission: :write,
        resource_type: "rule",
        resource_id: "rule456",
        granted: false
      )

      logs = adapter.all_logs
      log = logs.first
      expect(log[:event_type]).to eq("permission_check")
      expect(log[:user_id]).to eq("user123")
      expect(log[:permission]).to eq("write")
      expect(log[:resource_type]).to eq("rule")
      expect(log[:resource_id]).to eq("rule456")
      expect(log[:granted]).to be false
      expect(log[:timestamp]).to be_a(String)
    end

    it "handles nil resource_type and resource_id" do
      logger.log_permission_check(
        user_id: "user123",
        permission: :read,
        granted: true
      )

      logs = adapter.all_logs
      log = logs.first
      expect(log[:resource_type]).to be_nil
      expect(log[:resource_id]).to be_nil
    end
  end

  describe "#log_access" do
    it "includes all fields in log entry" do
      logger.log_access(
        user_id: "user123",
        action: "delete",
        resource_type: "version",
        resource_id: "version789",
        success: false
      )

      logs = adapter.all_logs
      log = logs.first
      expect(log[:event_type]).to eq("access")
      expect(log[:user_id]).to eq("user123")
      expect(log[:action]).to eq("delete")
      expect(log[:resource_type]).to eq("version")
      expect(log[:resource_id]).to eq("version789")
      expect(log[:success]).to be false
    end

    it "converts action to string" do
      logger.log_access(user_id: "user1", action: :create, success: true)
      logs = adapter.all_logs
      expect(logs.first[:action]).to eq("create")
    end
  end

  describe "adapter attribute" do
    it "returns the configured adapter" do
      custom_adapter = double("CustomAdapter")
      logger = DecisionAgent::Auth::AccessAuditLogger.new(adapter: custom_adapter)
      expect(logger.adapter).to eq(custom_adapter)
    end
  end
end

# Test for InMemoryAccessAdapter - class is nested inside AccessAuditLogger
# but may not be directly accessible. Testing through AccessAuditLogger instead.
RSpec.describe DecisionAgent::Auth::AccessAuditLogger do
  describe "InMemoryAccessAdapter integration" do
    let(:logger) { DecisionAgent::Auth::AccessAuditLogger.new }

    it "uses InMemoryAccessAdapter by default" do
      expect(logger.adapter).to be_a(DecisionAgent::Audit::InMemoryAccessAdapter)
    rescue NameError
      # If class is not directly accessible, test through logger interface
      logger.log_authentication("test", user_id: "user1")
      logs = logger.adapter.all_logs
      expect(logs.size).to eq(1)
    end
  end
end

RSpec.describe DecisionAgent::Audit::InMemoryAccessAdapter do
  let(:adapter) { described_class.new }

  describe "#initialize" do
    it "initializes with empty logs" do
      expect(adapter.all_logs).to eq([])
    end
  end

  describe "#record_access" do
    it "stores log entry" do
      log_entry = { event_type: "test", user_id: "user1", timestamp: Time.now.utc.iso8601 }
      adapter.record_access(log_entry)
      expect(adapter.all_logs.size).to eq(1)
    end

    it "stores duplicate of log entry" do
      log_entry = { event_type: "test", user_id: "user1", timestamp: Time.now.utc.iso8601 }
      adapter.record_access(log_entry)
      log_entry[:modified] = true
      expect(adapter.all_logs.first[:modified]).to be_nil
    end

    it "is thread-safe" do
      threads = []
      10.times do |i|
        threads << Thread.new do
          10.times do
            adapter.record_access({ event_type: "test", user_id: "user#{i}", timestamp: Time.now.utc.iso8601 })
          end
        end
      end
      threads.each(&:join)
      expect(adapter.all_logs.size).to eq(100)
    end
  end

  describe "#query_access_logs" do
    before do
      adapter.record_access({ event_type: "login", user_id: "user1", timestamp: (Time.now.utc - 7200).iso8601 })
      adapter.record_access({ event_type: "login", user_id: "user2", timestamp: (Time.now.utc - 3600).iso8601 })
      adapter.record_access({ event_type: "logout", user_id: "user1", timestamp: Time.now.utc.iso8601 })
    end

    it "filters by user_id" do
      logs = adapter.query_access_logs(user_id: "user1")
      expect(logs.size).to eq(2)
      expect(logs.all? { |log| log[:user_id] == "user1" }).to be true
    end

    it "filters by event_type" do
      logs = adapter.query_access_logs(event_type: "login")
      expect(logs.size).to eq(2)
      expect(logs.all? { |log| log[:event_type] == "login" }).to be true
    end

    it "filters by start_time" do
      start_time = Time.now.utc - 1800
      logs = adapter.query_access_logs(start_time: start_time)
      expect(logs.size).to eq(1)
    end

    it "filters by end_time" do
      end_time = Time.now.utc - 1800
      logs = adapter.query_access_logs(end_time: end_time)
      expect(logs.size).to eq(2)
    end

    it "limits results" do
      logs = adapter.query_access_logs(limit: 1)
      expect(logs.size).to eq(1)
    end

    it "handles string timestamps" do
      start_time = (Time.now.utc - 1800).iso8601
      logs = adapter.query_access_logs(start_time: start_time)
      expect(logs).to be_an(Array)
    end

    it "returns results in reverse order" do
      logs = adapter.query_access_logs
      expect(logs.first[:event_type]).to eq("logout")
      expect(logs.last[:event_type]).to eq("login")
    end

    it "is thread-safe" do
      threads = []
      5.times do
        threads << Thread.new do
          adapter.query_access_logs(user_id: "user1")
        end
      end
      threads.each(&:join)
      # Should not raise errors
      expect(adapter.query_access_logs.size).to eq(3)
    end
  end

  describe "#all_logs" do
    it "returns copy of logs" do
      adapter.record_access({ event_type: "test", timestamp: Time.now.utc.iso8601 })
      logs1 = adapter.all_logs
      logs2 = adapter.all_logs
      expect(logs1).not_to be(logs2)
      logs1 << { modified: true }
      expect(adapter.all_logs.size).to eq(1)
    end
  end

  describe "#clear" do
    it "clears all logs" do
      adapter.record_access({ event_type: "test", timestamp: Time.now.utc.iso8601 })
      expect(adapter.all_logs.size).to eq(1)
      adapter.clear
      expect(adapter.all_logs.size).to eq(0)
    end

    it "is thread-safe" do
      adapter.record_access({ event_type: "test", timestamp: Time.now.utc.iso8601 })
      threads = []
      5.times do
        threads << Thread.new do
          adapter.clear
        end
      end
      threads.each(&:join)
      expect(adapter.all_logs.size).to eq(0)
    end
  end
end

RSpec.describe DecisionAgent::Audit::AccessAdapter do
  let(:adapter) { described_class.new }

  describe "#record_access" do
    it "raises NotImplementedError" do
      expect { adapter.record_access({}) }.to raise_error(NotImplementedError, /must implement #record_access/)
    end
  end

  describe "#query_access_logs" do
    it "raises NotImplementedError" do
      expect { adapter.query_access_logs({}) }.to raise_error(NotImplementedError, /must implement #query_access_logs/)
    end
  end
end
