require "spec_helper"
require "tempfile"

# Conditionally require ActiveRecord for database tests
begin
  require "active_record"
rescue LoadError
  # ActiveRecord not available - skip database tests
end

RSpec.describe DecisionAgent::Simulation::ReplayEngine do
  let(:evaluator) do
    DecisionAgent::Evaluators::JsonRuleEvaluator.new(
      rules_json: {
        version: "1.0",
        ruleset: "test_rules",
        rules: [
          {
            id: "rule_1",
            if: { field: "amount", op: "gt", value: 1000 },
            then: { decision: "approve", weight: 0.9, reason: "High amount" }
          },
          {
            id: "rule_2",
            if: { field: "amount", op: "lte", value: 1000 },
            then: { decision: "reject", weight: 0.8, reason: "Low amount" }
          }
        ]
      }
    )
  end
  let(:agent) { DecisionAgent::Agent.new(evaluators: [evaluator]) }
  let(:version_manager) { DecisionAgent::Versioning::VersionManager.new }
  let(:engine) { described_class.new(agent: agent, version_manager: version_manager) }

  describe "#initialize" do
    it "creates a replay engine with agent and version manager" do
      expect(engine.agent).to eq(agent)
      expect(engine.version_manager).to eq(version_manager)
    end
  end

  describe "#replay" do
    let(:historical_data) do
      [
        { amount: 1500 },
        { amount: 500 },
        { amount: 2000 }
      ]
    end

    # Setup database for tests that use version_manager
    before(:each) do
      if defined?(ActiveRecord)
        # Setup in-memory SQLite database for testing
        ActiveRecord::Base.establish_connection(
          adapter: "sqlite3",
          database: ":memory:"
        )

        # Create the schema
        ActiveRecord::Schema.define do
          create_table :rule_versions, force: true do |t|
            t.string :rule_id, null: false
            t.integer :version_number, null: false
            t.text :content, null: false
            t.string :created_by, null: false, default: "system"
            t.text :changelog
            t.string :status, null: false, default: "draft"
            t.timestamps
          end

          add_index :rule_versions, %i[rule_id version_number], unique: true
          add_index :rule_versions, %i[rule_id status]
        end

        # Define RuleVersion model if not already defined
        unless defined?(RuleVersion)
          class RuleVersion < ActiveRecord::Base
            validates :rule_id, presence: true
            validates :version_number, presence: true, uniqueness: { scope: :rule_id }
            validates :content, presence: true
            validates :status, inclusion: { in: %w[draft active archived] }
            validates :created_by, presence: true
          end
        end
      end
    end

    after(:each) do
      if defined?(ActiveRecord) && ActiveRecord::Base.connected?
        ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS rule_versions")
        ActiveRecord::Base.connection.close
      end
    end

    it "replays historical decisions" do
      results = engine.replay(historical_data: historical_data)

      expect(results[:total_decisions]).to eq(3)
      expect(results[:results].size).to eq(3)
      expect(results[:results][0][:replay_decision]).to eq("approve")
      expect(results[:results][1][:replay_decision]).to eq("reject")
    end

    it "compares with baseline version when provided" do
      # Create baseline version with different rules
      baseline_version = version_manager.save_version(
        rule_id: "test_rule",
        rule_content: {
          version: "1.0",
          ruleset: "test_rules",
          rules: [
            {
              id: "rule_1",
              if: { field: "amount", op: "gt", value: 2000 },
              then: { decision: "approve", weight: 0.9 }
            }
          ]
        },
        created_by: "test"
      )

      results = engine.replay(
        historical_data: historical_data,
        compare_with: baseline_version[:id]
      )

      expect(results[:has_baseline]).to be true
      expect(results[:changed_decisions]).to be > 0
    end

    it "loads historical data from CSV file" do
      csv_file = Tempfile.new(["historical", ".csv"])
      CSV.open(csv_file.path, "w") do |csv|
        csv << ["amount"]
        csv << ["1500"]
        csv << ["500"]
      end

      results = engine.replay(historical_data: csv_file.path)
      expect(results[:total_decisions]).to eq(2)

      csv_file.close
      csv_file.unlink
    end

    it "loads historical data from JSON file" do
      json_file = Tempfile.new(["historical", ".json"])
      json_file.write([{ amount: 1500 }, { amount: 500 }].to_json)
      json_file.close

      results = engine.replay(historical_data: json_file.path)
      expect(results[:total_decisions]).to eq(2)

      json_file.unlink
    end

    it "raises error for unsupported file format" do
      txt_file = Tempfile.new(["historical", ".txt"])
      txt_file.write("test")
      txt_file.close

      expect do
        engine.replay(historical_data: txt_file.path)
      end.to raise_error(DecisionAgent::Simulation::InvalidHistoricalDataError)

      txt_file.unlink
    end

    context "with database queries" do
      before(:all) do
        # Only run database tests if ActiveRecord is available
        unless defined?(ActiveRecord)
          skip "ActiveRecord not available"
        end
      end

      before(:each) do
        # Setup in-memory SQLite database for testing
        # Use a unique database name for each test to avoid conflicts
        @test_db = ":memory:"
        ActiveRecord::Base.establish_connection(
          adapter: "sqlite3",
          database: @test_db
        )

        # Create test table
        ActiveRecord::Schema.define do
          create_table :historical_contexts, force: true do |t|
            t.float :amount
            t.string :status
            t.integer :user_id
            t.timestamps
          end
        end

        # Insert test data
        connection = ActiveRecord::Base.connection
        connection.execute("INSERT INTO historical_contexts (amount, status, user_id, created_at, updated_at) VALUES (1500, 'pending', 1, datetime('now'), datetime('now'))")
        connection.execute("INSERT INTO historical_contexts (amount, status, user_id, created_at, updated_at) VALUES (500, 'pending', 2, datetime('now'), datetime('now'))")
        connection.execute("INSERT INTO historical_contexts (amount, status, user_id, created_at, updated_at) VALUES (2000, 'approved', 3, datetime('now'), datetime('now'))")
      end

      after(:each) do
        if ActiveRecord::Base.connected?
          ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS historical_contexts")
          ActiveRecord::Base.connection.close
        end
      end

      it "loads historical data from database using SQL query" do
        db_config = {
          database: {
            connection: "default",
            query: "SELECT amount, status, user_id FROM historical_contexts WHERE amount > 1000"
          }
        }

        results = engine.replay(historical_data: db_config)
        expect(results[:total_decisions]).to eq(2) # 1500 and 2000
        expect(results[:results].all? { |r| r[:context][:amount].to_f > 1000 }).to be true
      end

      it "loads historical data from database using table name" do
        db_config = {
          database: {
            connection: "default",
            table: "historical_contexts"
          }
        }

        results = engine.replay(historical_data: db_config)
        expect(results[:total_decisions]).to eq(3)
      end

      it "loads historical data from database using table name with where clause" do
        db_config = {
          database: {
            connection: "default",
            table: "historical_contexts",
            where: { status: "pending" }
          }
        }

        results = engine.replay(historical_data: db_config)
        expect(results[:total_decisions]).to eq(2) # Only pending records
        expect(results[:results].all? { |r| r[:context][:status] == "pending" }).to be true
      end

      it "loads historical data using default connection when connection is 'default'" do
        db_config = {
          database: {
            connection: "default",
            query: "SELECT amount, status FROM historical_contexts"
          }
        }

        results = engine.replay(historical_data: db_config)
        expect(results[:total_decisions]).to eq(3)
      end

      it "raises error when database config is missing connection" do
        db_config = {
          database: {
            query: "SELECT * FROM historical_contexts"
          }
        }

        expect do
          engine.replay(historical_data: db_config)
        end.to raise_error(DecisionAgent::Simulation::InvalidHistoricalDataError, /connection/)
      end

      it "raises error when database config is missing query and table" do
        db_config = {
          database: {
            connection: {
              adapter: "sqlite3",
              database: ":memory:"
            }
          }
        }

        expect do
          engine.replay(historical_data: db_config)
        end.to raise_error(DecisionAgent::Simulation::InvalidHistoricalDataError, /query or :table/)
      end

      it "handles JSON columns in database results" do
        # Create table with JSON column
        ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS historical_contexts")
        ActiveRecord::Schema.define do
          create_table :historical_contexts, force: true do |t|
            t.text :context_data
            t.timestamps
          end
        end

        # Insert JSON data
        json_data = { amount: 1500, status: "pending" }.to_json
        ActiveRecord::Base.connection.execute(
          "INSERT INTO historical_contexts (context_data, created_at, updated_at) VALUES (#{ActiveRecord::Base.connection.quote(json_data)}, datetime('now'), datetime('now'))"
        )

        db_config = {
          database: {
            connection: "default",
            query: "SELECT context_data FROM historical_contexts"
          }
        }

        results = engine.replay(historical_data: db_config)
        expect(results[:total_decisions]).to eq(1)
        # JSON should be parsed if possible
        context_data = results[:results][0][:context][:context_data]
        expect([Hash, String]).to include(context_data.class)
      end

      it "loads historical data using custom connection config" do
        # Create a temporary file-based database for this test
        temp_db = Tempfile.new(["test_db", ".sqlite3"])
        temp_db.close
        temp_db_path = temp_db.path
        temp_db.unlink

        # Use ActiveRecord directly to set up the test database
        # The replay engine will create its own connection class
        test_connection = ActiveRecord::Base.establish_connection(
          adapter: "sqlite3",
          database: temp_db_path
        )

        # Create table and insert data using the test connection
        test_connection.connection.execute(
          "CREATE TABLE test_contexts (amount REAL, status TEXT)"
        )
        test_connection.connection.execute(
          "INSERT INTO test_contexts (amount, status) VALUES (1500, 'test')"
        )

        # Close the test connection so the replay engine can create its own
        test_connection.connection.close

        db_config = {
          database: {
            connection: {
              adapter: "sqlite3",
              database: temp_db_path
            },
            query: "SELECT amount, status FROM test_contexts"
          }
        }

        results = engine.replay(historical_data: db_config)
        expect(results[:total_decisions]).to eq(1)
        expect(results[:results][0][:context][:amount]).to eq(1500.0)

        # Cleanup
        File.delete(temp_db_path) if File.exist?(temp_db_path)
      end
    end

    context "without ActiveRecord" do
      it "raises error when trying to use database queries without ActiveRecord" do
        # This test verifies the error message when ActiveRecord is not available
        # Since ActiveRecord is loaded in the test environment, we'll test with an invalid adapter
        # which will raise an error that gets wrapped in InvalidHistoricalDataError
        db_config = {
          database: {
            connection: { adapter: "invalid", database: "test" },
            query: "SELECT * FROM test"
          }
        }

        # This will fail on connection, and the error should be wrapped
        expect do
          engine.replay(historical_data: db_config)
        end.to raise_error(DecisionAgent::Simulation::InvalidHistoricalDataError)
      end
    end
  end

  describe "#backtest" do
    let(:historical_data) { [{ amount: 1500 }, { amount: 500 }] }

    before(:each) do
      # Only run database tests if ActiveRecord is available
      unless defined?(ActiveRecord)
        skip "ActiveRecord not available"
      end

      # Setup in-memory SQLite database for testing
      ActiveRecord::Base.establish_connection(
        adapter: "sqlite3",
        database: ":memory:"
      )

      # Create the schema
      ActiveRecord::Schema.define do
        create_table :rule_versions, force: true do |t|
          t.string :rule_id, null: false
          t.integer :version_number, null: false
          t.text :content, null: false
          t.string :created_by, null: false, default: "system"
          t.text :changelog
          t.string :status, null: false, default: "draft"
          t.timestamps
        end

        add_index :rule_versions, %i[rule_id version_number], unique: true
        add_index :rule_versions, %i[rule_id status]
      end

      # Define RuleVersion model if not already defined
      unless defined?(RuleVersion)
        class RuleVersion < ActiveRecord::Base
          validates :rule_id, presence: true
          validates :version_number, presence: true, uniqueness: { scope: :rule_id }
          validates :content, presence: true
          validates :status, inclusion: { in: %w[draft active archived] }
          validates :created_by, presence: true
        end
      end
    end

    after(:each) do
      if defined?(ActiveRecord) && ActiveRecord::Base.connected?
        ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS rule_versions")
        ActiveRecord::Base.connection.close
      end
    end

    it "backtests proposed version against baseline" do
      # Create versions
      baseline_version = version_manager.save_version(
        rule_id: "test_rule",
        rule_content: {
          version: "1.0",
          ruleset: "test_rules",
          rules: [
            {
              id: "rule_1",
              if: { field: "amount", op: "gt", value: 1000 },
              then: { decision: "approve", weight: 0.9 }
            }
          ]
        },
        created_by: "test"
      )

      proposed_version = version_manager.save_version(
        rule_id: "test_rule",
        rule_content: {
          version: "1.0",
          ruleset: "test_rules",
          rules: [
            {
              id: "rule_1",
              if: { field: "amount", op: "gt", value: 2000 },
              then: { decision: "approve", weight: 0.9 }
            }
          ]
        },
        created_by: "test"
      )

      results = engine.backtest(
        historical_data: historical_data,
        proposed_version: proposed_version[:id],
        baseline_version: baseline_version[:id]
      )

      expect(results[:has_baseline]).to be true
      expect(results[:change_rate]).to be >= 0
    end
  end
end

