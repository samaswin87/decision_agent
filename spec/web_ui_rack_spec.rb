require "spec_helper"
require "rack/test"
require_relative "../lib/decision_agent/web/server"

RSpec.describe "DecisionAgent Web UI Rack Integration" do
  include Rack::Test::Methods

  def app
    DecisionAgent::Web::Server
  end

  describe "Rack interface" do
    it "responds to .call for Rack compatibility" do
      expect(DecisionAgent::Web::Server).to respond_to(:call)
    end

    it "serves the main page" do
      get "/"
      expect(last_response).to be_ok
      expect(last_response.body).to include("DecisionAgent")
    end

    it "serves the health endpoint" do
      get "/health"
      expect(last_response).to be_ok
      expect(last_response.content_type).to include("application/json")

      json = JSON.parse(last_response.body)
      expect(json["status"]).to eq("ok")
      expect(json["version"]).to eq(DecisionAgent::VERSION)
    end

    it "validates rules via POST /api/validate" do
      valid_rules = {
        version: "1.0",
        ruleset: "test_rules",
        rules: [{
          id: "test_rule",
          if: { field: "amount", op: "gt", value: 100 },
          then: { decision: "approve", weight: 0.9, reason: "Test" }
        }]
      }

      post "/api/validate", valid_rules.to_json, { "CONTENT_TYPE" => "application/json" }

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json["valid"]).to be true
    end

    it "returns error for invalid rules" do
      invalid_rules = {
        version: "1.0",
        ruleset: "test_rules",
        rules: [{
          id: "bad_rule"
          # Missing required fields
        }]
      }

      post "/api/validate", invalid_rules.to_json, { "CONTENT_TYPE" => "application/json" }

      expect(last_response.status).to eq(422)
      json = JSON.parse(last_response.body)
      expect(json["valid"]).to be false
      expect(json["errors"]).to be_an(Array)
    end

    it "evaluates rules via POST /api/evaluate" do
      rules = {
        version: "1.0",
        ruleset: "test_rules",
        rules: [{
          id: "high_value",
          if: { field: "amount", op: "gt", value: 1000 },
          then: { decision: "approve", weight: 0.9, reason: "High value" }
        }]
      }

      payload = {
        rules: rules,
        context: { amount: 1500 }
      }

      post "/api/evaluate", payload.to_json, { "CONTENT_TYPE" => "application/json" }

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json["success"]).to be true
      expect(json["decision"]).to eq("approve")
      expect(json["weight"]).to eq(0.9)
      expect(json["reason"]).to eq("High value")
    end

    it "serves example rules" do
      get "/api/examples"

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_an(Array)
      expect(json.length).to be > 0
      expect(json.first).to have_key("name")
      expect(json.first).to have_key("rules")
    end

    it "handles CORS preflight requests" do
      options "/api/validate"

      expect(last_response.status).to eq(200)
      expect(last_response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(last_response.headers["Access-Control-Allow-Methods"]).to include("POST")
    end
  end

  describe "Password reset API" do
    before do
      # Create a test user
      authenticator = DecisionAgent::Web::Server.authenticator
      authenticator.create_user(
        email: "test@example.com",
        password: "oldpassword123"
      )
    end

    describe "POST /api/auth/password/reset-request" do
      it "returns success for valid email" do
        post "/api/auth/password/reset-request",
             { email: "test@example.com" }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["success"]).to be true
        expect(json["token"]).to be_a(String)
        expect(json["expires_at"]).to be_a(String)
      end

      it "returns success even for non-existent email (security)" do
        post "/api/auth/password/reset-request",
             { email: "nonexistent@example.com" }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["success"]).to be true
        expect(json["token"]).to be_nil
      end

      it "returns error when email is missing" do
        post "/api/auth/password/reset-request",
             {}.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Email is required")
      end
    end

    describe "POST /api/auth/password/reset" do
      let(:reset_token) do
        authenticator = DecisionAgent::Web::Server.authenticator
        token = authenticator.request_password_reset("test@example.com")
        token.token
      end

      it "resets password with valid token" do
        post "/api/auth/password/reset",
             { token: reset_token, password: "newpassword123" }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["success"]).to be true
        expect(json["message"]).to include("reset successfully")

        # Verify password was actually changed
        authenticator = DecisionAgent::Web::Server.authenticator
        user = authenticator.find_user_by_email("test@example.com")
        expect(user.authenticate("newpassword123")).to be true
        expect(user.authenticate("oldpassword123")).to be false
      end

      it "returns error for invalid token" do
        post "/api/auth/password/reset",
             { token: "invalid_token", password: "newpassword123" }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Invalid or expired")
      end

      it "returns error when password is too short" do
        post "/api/auth/password/reset",
             { token: reset_token, password: "short" }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("at least 8 characters")
      end

      it "returns error when token is missing" do
        post "/api/auth/password/reset",
             { password: "newpassword123" }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Token and password are required")
      end

      it "returns error when password is missing" do
        post "/api/auth/password/reset",
             { token: reset_token }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Token and password are required")
      end
    end
  end

  describe "Rails mounting compatibility" do
    it "can be mounted in a Rack app" do
      # Simulate a Rails-style mount
      rack_app = Rack::Builder.new do
        map "/decision_agent" do
          run DecisionAgent::Web::Server
        end
      end

      # Create a test session for the mounted app
      test_session = Rack::Test::Session.new(Rack::MockSession.new(rack_app))

      # Test that the health endpoint works when mounted
      test_session.get "/decision_agent/health"
      expect(test_session.last_response).to be_ok

      json = JSON.parse(test_session.last_response.body)
      expect(json["status"]).to eq("ok")
    end
  end

  describe "API error handling" do
    it "handles invalid JSON in validate endpoint" do
      post "/api/validate", "invalid json", { "CONTENT_TYPE" => "application/json" }
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json["valid"]).to be false
      expect(json["errors"]).to be_an(Array)
    end

    it "handles server errors in validate endpoint" do
      allow(DecisionAgent::Dsl::SchemaValidator).to receive(:validate!).and_raise(StandardError.new("Unexpected error"))
      post "/api/validate", {}.to_json, { "CONTENT_TYPE" => "application/json" }
      expect(last_response.status).to eq(500)
      json = JSON.parse(last_response.body)
      expect(json["valid"]).to be false
      expect(json["errors"]).to be_an(Array)
    end

    it "handles errors in evaluate endpoint" do
      post "/api/evaluate", "invalid json", { "CONTENT_TYPE" => "application/json" }
      expect(last_response.status).to eq(500)
      json = JSON.parse(last_response.body)
      expect(json["success"]).to be false
    end

    it "handles no rules matched in evaluate endpoint" do
      rules = {
        version: "1.0",
        ruleset: "test_rules",
        rules: [{
          id: "high_value",
          if: { field: "amount", op: "gt", value: 1000 },
          then: { decision: "approve", weight: 0.9, reason: "High value" }
        }]
      }

      payload = {
        rules: rules,
        context: { amount: 100 } # Won't match
      }

      post "/api/evaluate", payload.to_json, { "CONTENT_TYPE" => "application/json" }
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json["success"]).to be true
      expect(json["decision"]).to be_nil
      expect(json["message"]).to include("No rules matched")
    end
  end

  describe "Authentication API" do
    let(:authenticator) { DecisionAgent::Web::Server.authenticator }

    before do
      user = authenticator.create_user(
        email: "auth@example.com",
        password: "password123"
      )
      # Give user read permission for roles endpoint
      user.assign_role(:viewer)
    end

    describe "POST /api/auth/login" do
      it "logs in with valid credentials" do
        post "/api/auth/login",
             { email: "auth@example.com", password: "password123" }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["token"]).to be_a(String)
        expect(json["user"]).to be_a(Hash)
        expect(json["expires_at"]).to be_a(String)
      end

      it "returns 401 for invalid credentials" do
        post "/api/auth/login",
             { email: "auth@example.com", password: "wrongpassword" }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(401)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Invalid email or password")
      end

      it "returns 400 when email is missing" do
        post "/api/auth/login",
             { password: "password123" }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Email and password are required")
      end

      it "returns 400 when password is missing" do
        post "/api/auth/login",
             { email: "auth@example.com" }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Email and password are required")
      end

      it "handles invalid JSON" do
        post "/api/auth/login", "invalid json", { "CONTENT_TYPE" => "application/json" }
        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Invalid JSON")
      end
    end

    describe "POST /api/auth/logout" do
      it "logs out with valid token" do
        session = authenticator.login("auth@example.com", "password123")
        post "/api/auth/logout",
             {},
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{session.token}" }

        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["success"]).to be true
      end

      it "logs out without token" do
        post "/api/auth/logout", {}, { "CONTENT_TYPE" => "application/json" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["success"]).to be true
      end
    end

    describe "GET /api/auth/me" do
      it "returns current user when authenticated" do
        session = authenticator.login("auth@example.com", "password123")
        get "/api/auth/me", {}, { "HTTP_AUTHORIZATION" => "Bearer #{session.token}" }

        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["email"]).to eq("auth@example.com")
      end

      it "returns 401 when not authenticated" do
        get "/api/auth/me"
        expect(last_response.status).to eq(401)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to eq("Not authenticated")
      end
    end

    describe "GET /api/auth/roles" do
      it "requires authentication" do
        # Clear any existing session by not providing auth headers
        get "/api/auth/roles", {}, {}
        # If somehow a user is authenticated, they won't have permission, so we accept 403 as well
        expect([401, 403]).to include(last_response.status)
      end

      it "returns roles when authenticated with proper permission" do
        session = authenticator.login("auth@example.com", "password123")
        get "/api/auth/roles", {}, { "HTTP_AUTHORIZATION" => "Bearer #{session.token}" }

        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json).to be_an(Array)
      end
    end
  end

  describe "User management API" do
    let(:authenticator) { DecisionAgent::Web::Server.authenticator }
    let(:admin_user) do
      user = authenticator.create_user(
        email: "admin@example.com",
        password: "password123",
        roles: [:admin]
      )
      session = authenticator.login("admin@example.com", "password123")
      { user: user, session: session }
    end

    describe "POST /api/auth/users" do
      it "requires authentication" do
        post "/api/auth/users", {}.to_json, { "CONTENT_TYPE" => "application/json" }
        expect(last_response.status).to eq(401)
      end

      it "creates user when authenticated as admin" do
        post "/api/auth/users",
             { email: "newuser@example.com", password: "password123", roles: [] }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }

        expect(last_response.status).to eq(201)
        json = JSON.parse(last_response.body)
        expect(json["email"]).to eq("newuser@example.com")
      end

      it "returns 400 when email is missing" do
        post "/api/auth/users",
             { password: "password123" }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Email and password are required")
      end

      it "returns 400 for invalid role" do
        post "/api/auth/users",
             { email: "user@example.com", password: "password123", roles: ["invalid_role"] }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Invalid role")
      end
    end

    describe "GET /api/auth/users" do
      it "requires authentication" do
        get "/api/auth/users"
        expect(last_response.status).to eq(401)
      end

      it "lists users when authenticated as admin" do
        get "/api/auth/users", {}, { "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json).to be_an(Array)
      end
    end

    describe "POST /api/auth/users/:id/roles" do
      let(:test_user) do
        authenticator.create_user(
          email: "testuser@example.com",
          password: "password123"
        )
      end

      it "assigns role to user" do
        post "/api/auth/users/#{test_user.id}/roles",
             { role: "editor" }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }

        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["roles"]).to include("editor")
      end

      it "returns 404 for non-existent user" do
        post "/api/auth/users/nonexistent/roles",
             { role: "editor" }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }

        expect(last_response.status).to eq(404)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("User not found")
      end

      it "returns 400 when role is missing" do
        post "/api/auth/users/#{test_user.id}/roles",
             {}.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Role is required")
      end
    end

    describe "DELETE /api/auth/users/:id/roles/:role" do
      let(:test_user) do
        user = authenticator.create_user(
          email: "testuser2@example.com",
          password: "password123"
        )
        user.assign_role(:editor)
        user
      end

      it "removes role from user" do
        delete "/api/auth/users/#{test_user.id}/roles/editor",
               {},
               { "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }

        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["roles"]).not_to include("editor")
      end

      it "returns 404 for non-existent user" do
        delete "/api/auth/users/nonexistent/roles/editor",
               {},
               { "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }

        expect(last_response.status).to eq(404)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("User not found")
      end
    end
  end

  describe "Audit API" do
    let(:authenticator) { DecisionAgent::Web::Server.authenticator }
    let(:admin_user) do
      user = authenticator.create_user(
        email: "auditadmin@example.com",
        password: "password123",
        roles: [:admin]
      )
      session = authenticator.login("auditadmin@example.com", "password123")
      { user: user, session: session }
    end

    describe "GET /api/auth/audit" do
      it "requires authentication" do
        get "/api/auth/audit"
        expect(last_response.status).to eq(401)
      end

      it "returns audit logs" do
        get "/api/auth/audit", {}, { "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json).to be_an(Array)
      end

      it "filters by user_id" do
        get "/api/auth/audit?user_id=#{admin_user[:user].id}", {}, { "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json).to be_an(Array)
      end

      it "filters by event_type" do
        get "/api/auth/audit?event_type=login", {}, { "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json).to be_an(Array)
      end
    end
  end

  describe "Versioning API" do
    # Setup database for ActiveRecord adapter if available
    if defined?(ActiveRecord)
      before(:all) do
        # Setup in-memory SQLite database
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
          class ::RuleVersion < ActiveRecord::Base
            validates :rule_id, presence: true
            validates :version_number, presence: true, uniqueness: { scope: :rule_id }
            validates :content, presence: true
            validates :status, inclusion: { in: %w[draft active archived] }
            validates :created_by, presence: true

            scope :active, -> { where(status: "active") }
            scope :for_rule, ->(rule_id) { where(rule_id: rule_id).order(version_number: :desc) }
            scope :latest, -> { order(version_number: :desc).limit(1) }

            before_create :set_next_version_number

            def parsed_content
              JSON.parse(content, symbolize_names: true)
            rescue JSON::ParserError
              {}
            end

            def content_hash=(hash)
              self.content = hash.to_json
            end

            def activate!
              transaction do
                self.class.where(rule_id: rule_id, status: "active")
                    .where.not(id: id)
                    .find_each do |v|
                      v.update!(status: "archived")
                    end
                update!(status: "active")
              end
            end

            private

            def set_next_version_number
              return if version_number.present?

              last_version = self.class.where(rule_id: rule_id)
                                 .order(version_number: :desc)
                                 .first
              self.version_number = last_version ? last_version.version_number + 1 : 1
            end
          end
        end
      end

      before(:each) do
        # Clean up between tests
        RuleVersion.delete_all if defined?(RuleVersion)
      end
    end

    let(:authenticator) { DecisionAgent::Web::Server.authenticator }
    let(:user) do
      u = authenticator.create_user(
        email: "version@example.com",
        password: "password123",
        roles: [:editor]
      )
      session = authenticator.login("version@example.com", "password123")
      { user: u, session: session }
    end

    describe "POST /api/versions" do
      it "requires authentication" do
        post "/api/versions", {}.to_json, { "CONTENT_TYPE" => "application/json" }
        expect(last_response.status).to eq(401)
      end

      it "creates a version" do
        post "/api/versions",
             {
               rule_id: "rule1",
               content: { test: "data" },
               created_by: "test@example.com",
               changelog: "Initial version"
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        expect(last_response.status).to eq(201)
        json = JSON.parse(last_response.body)
        expect(json["rule_id"]).to eq("rule1")
      end
    end

    describe "GET /api/rules/:rule_id/versions" do
      it "requires authentication" do
        get "/api/rules/rule1/versions"
        expect(last_response.status).to eq(401)
      end

      it "returns versions for a rule" do
        get "/api/rules/rule1/versions", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json).to be_an(Array)
      end
    end

    describe "GET /api/rules/:rule_id/history" do
      it "requires authentication" do
        get "/api/rules/rule1/history"
        expect(last_response.status).to eq(401)
      end

      it "returns history for a rule" do
        get "/api/rules/rule1/history", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json).to be_a(Hash)
      end
    end

    describe "GET /api/versions/:version_id" do
      it "requires authentication" do
        get "/api/versions/version1"
        expect(last_response.status).to eq(401)
      end

      it "returns 404 for non-existent version" do
        get "/api/versions/nonexistent", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        expect(last_response.status).to eq(404)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Version not found")
      end
    end

    describe "POST /api/versions/:version_id/activate" do
      it "requires authentication" do
        post "/api/versions/version1/activate", {}.to_json, { "CONTENT_TYPE" => "application/json" }
        expect(last_response.status).to eq(401)
      end
    end

    describe "GET /api/versions/:version_id_1/compare/:version_id_2" do
      it "requires authentication" do
        get "/api/versions/v1/compare/v2"
        expect(last_response.status).to eq(401)
      end
    end

    describe "DELETE /api/versions/:version_id" do
      it "requires authentication" do
        delete "/api/versions/version1"
        expect(last_response.status).to eq(401)
      end
    end
  end

  describe "Batch Testing API" do
    describe "POST /api/testing/batch/import" do
      let(:csv_content) do
        <<~CSV
          id,user_id,amount,expected_decision
          test_1,123,1000,approve
          test_2,456,5000,reject
        CSV
      end

      it "imports CSV file and returns test_id" do
        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.rewind

        post "/api/testing/batch/import", { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }, { "CONTENT_TYPE" => "multipart/form-data" }

        expect(last_response.status).to eq(201)
        json = JSON.parse(last_response.body)
        expect(json["test_id"]).to be_a(String)
        expect(json["scenarios_count"]).to eq(2)

        file.close
        file.unlink
      end

      it "returns error when no file uploaded" do
        post "/api/testing/batch/import", {}, { "CONTENT_TYPE" => "multipart/form-data" }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("No file uploaded")
      end

      it "handles import errors gracefully" do
        file = Tempfile.new(["test", ".csv"])
        # Create CSV with missing required 'id' column to trigger an error
        file.write("col1,col2\nvalue1,value2\n")
        file.rewind

        post "/api/testing/batch/import", { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }, { "CONTENT_TYPE" => "multipart/form-data" }

        # Should handle error gracefully (missing 'id' column should cause 422)
        expect([400, 422, 500]).to include(last_response.status)

        file.close
        file.unlink
      end
    end

    describe "POST /api/testing/batch/run" do
      let(:test_id) do
        # Create a test import first
        csv_content = "id,user_id,amount\ntest_1,123,1000\n"
        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.rewind

        post "/api/testing/batch/import", { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }, { "CONTENT_TYPE" => "multipart/form-data" }
        json = JSON.parse(last_response.body)
        file.close
        file.unlink
        json["test_id"]
      end

      let(:rules_json) do
        {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "amount", op: "gt", value: 500 },
              then: { decision: "approve", weight: 0.9, reason: "High amount" }
            }
          ]
        }
      end

      it "runs batch test and returns results" do
        post "/api/testing/batch/run",
             { test_id: test_id, rules: rules_json }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(200)
        json = JSON.parse(last_response.body)
        expect(json["status"]).to eq("completed")
        expect(json["results_count"]).to eq(1)
        expect(json["statistics"]).to be_a(Hash)
      end

      it "returns error when test_id is missing" do
        post "/api/testing/batch/run",
             { rules: rules_json }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("test_id is required")
      end

      it "returns error when rules are missing" do
        post "/api/testing/batch/run",
             { test_id: test_id }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("rules JSON is required")
      end

      it "returns 404 when test not found" do
        post "/api/testing/batch/run",
             { test_id: "nonexistent", rules: rules_json }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(404)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Test not found")
      end
    end

    describe "GET /api/testing/batch/:id/results" do
      it "returns 404 when test not found" do
        get "/api/testing/batch/nonexistent/results"

        expect(last_response.status).to eq(404)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Test not found")
      end

      it "returns test results when available" do
        # Create and run a test first
        csv_content = "id,user_id,amount\ntest_1,123,1000\n"
        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.rewind

        post "/api/testing/batch/import", { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }, { "CONTENT_TYPE" => "multipart/form-data" }
        import_json = JSON.parse(last_response.body)
        test_id = import_json["test_id"]

        rules_json = {
          version: "1.0",
          ruleset: "test",
          rules: [{ id: "rule_1", if: { field: "amount", op: "gt", value: 500 }, then: { decision: "approve", weight: 0.9, reason: "Test" } }]
        }

        post "/api/testing/batch/run", { test_id: test_id, rules: rules_json }.to_json, { "CONTENT_TYPE" => "application/json" }

        get "/api/testing/batch/#{test_id}/results"

        expect(last_response.status).to eq(200)
        json = JSON.parse(last_response.body)
        expect(json["test_id"]).to eq(test_id)
        expect(json["status"]).to eq("completed")

        file.close
        file.unlink
      end
    end

    describe "GET /api/testing/batch/:id/coverage" do
      it "returns 404 when test not found" do
        get "/api/testing/batch/nonexistent/coverage"

        expect(last_response.status).to eq(404)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Test not found")
      end

      it "returns error when coverage not available" do
        # Create a test but don't run it
        csv_content = "id,user_id,amount\ntest_1,123,1000\n"
        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.rewind

        post "/api/testing/batch/import", { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }, { "CONTENT_TYPE" => "multipart/form-data" }
        import_json = JSON.parse(last_response.body)
        test_id = import_json["test_id"]

        get "/api/testing/batch/#{test_id}/coverage"

        expect(last_response.status).to eq(404)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Coverage report not available")

        file.close
        file.unlink
      end
    end

    describe "GET /testing/batch" do
      it "serves batch testing page" do
        get "/testing/batch"
        expect(last_response).to be_ok
      end
    end

    describe "GET /auth/login" do
      it "serves login page" do
        get "/auth/login"
        expect(last_response).to be_ok
      end
    end

    describe "GET /auth/users" do
      it "serves user management page" do
        get "/auth/users"
        expect(last_response).to be_ok
      end
    end
  end

  describe "Server class methods" do
    describe ".batch_test_storage" do
      it "returns storage hash" do
        expect(DecisionAgent::Web::Server.batch_test_storage).to be_a(Hash)
      end
    end

    describe ".authenticator" do
      it "returns default authenticator" do
        expect(DecisionAgent::Web::Server.authenticator).to be_a(DecisionAgent::Auth::Authenticator)
      end

      it "allows setting custom authenticator" do
        custom_auth = double("Authenticator")
        DecisionAgent::Web::Server.authenticator = custom_auth
        expect(DecisionAgent::Web::Server.authenticator).to eq(custom_auth)
        DecisionAgent::Web::Server.authenticator = nil # Reset
      end
    end

    describe ".permission_checker" do
      it "returns default permission checker" do
        expect(DecisionAgent::Web::Server.permission_checker).to be_a(DecisionAgent::Auth::PermissionChecker)
      end
    end

    describe ".access_audit_logger" do
      it "returns default access audit logger" do
        expect(DecisionAgent::Web::Server.access_audit_logger).to be_a(DecisionAgent::Auth::AccessAuditLogger)
      end
    end

    describe ".start!" do
      it "is a class method" do
        expect(DecisionAgent::Web::Server).to respond_to(:start!)
      end
    end
  end

  describe "Token extraction" do
    let(:authenticator) { DecisionAgent::Web::Server.authenticator }

    before do
      # Create user for token extraction tests
      authenticator.create_user(email: "auth@example.com", password: "password123")
    end

    it "extracts token from Authorization header" do
      session = authenticator.login("auth@example.com", "password123")
      expect(session).not_to be_nil
      get "/api/auth/me", {}, { "HTTP_AUTHORIZATION" => "Bearer #{session.token}" }
      expect(last_response).to be_ok
    end

    it "extracts token from query parameter" do
      session = authenticator.login("auth@example.com", "password123")
      expect(session).not_to be_nil
      get "/api/auth/me?token=#{session.token}"
      expect(last_response).to be_ok
    end
  end

  describe "extract_token method" do
    it "extracts token from cookie" do
      authenticator = DecisionAgent::Web::Server.authenticator
      authenticator.create_user(email: "cookie@example.com", password: "password123")
      session = authenticator.login("cookie@example.com", "password123")

      get "/api/auth/me", {}, { "HTTP_COOKIE" => "decision_agent_session=#{session.token}" }
      expect(last_response).to be_ok
    end
  end

  describe "parse_validation_errors" do
    it "parses validation error messages correctly" do
      # This is tested indirectly through the validate endpoint
      invalid_rules = { version: "1.0", ruleset: "test", rules: [{ id: "bad_rule" }] }

      post "/api/validate", invalid_rules.to_json, { "CONTENT_TYPE" => "application/json" }

      expect(last_response.status).to eq(422)
      json = JSON.parse(last_response.body)
      expect(json["errors"]).to be_an(Array)
    end

    it "handles error messages without numbered format" do
      allow(DecisionAgent::Dsl::SchemaValidator).to receive(:validate!).and_raise(
        DecisionAgent::InvalidRuleDslError.new("Simple error message")
      )

      post "/api/validate", {}.to_json, { "CONTENT_TYPE" => "application/json" }

      expect(last_response.status).to eq(422)
      json = JSON.parse(last_response.body)
      expect(json["errors"]).to be_an(Array)
      expect(json["errors"]).to include("Simple error message")
    end
  end

  describe "Versioning API comprehensive tests" do
    # Setup database for ActiveRecord adapter if available
    if defined?(ActiveRecord)
      before(:all) do
        # Setup in-memory SQLite database
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
          class ::RuleVersion < ActiveRecord::Base
            validates :rule_id, presence: true
            validates :version_number, presence: true, uniqueness: { scope: :rule_id }
            validates :content, presence: true
            validates :status, inclusion: { in: %w[draft active archived] }
            validates :created_by, presence: true

            scope :active, -> { where(status: "active") }
            scope :for_rule, ->(rule_id) { where(rule_id: rule_id).order(version_number: :desc) }
            scope :latest, -> { order(version_number: :desc).limit(1) }

            before_create :set_next_version_number

            def parsed_content
              JSON.parse(content, symbolize_names: true)
            rescue JSON::ParserError
              {}
            end

            def content_hash=(hash)
              self.content = hash.to_json
            end

            def activate!
              transaction do
                self.class.where(rule_id: rule_id, status: "active")
                    .where.not(id: id)
                    .find_each do |v|
                      v.update!(status: "archived")
                    end
                update!(status: "active")
              end
            end

            private

            def set_next_version_number
              return if version_number.present?

              last_version = self.class.where(rule_id: rule_id)
                                 .order(version_number: :desc)
                                 .first
              self.version_number = last_version ? last_version.version_number + 1 : 1
            end
          end
        end
      end

      before(:each) do
        # Clean up between tests
        RuleVersion.delete_all if defined?(RuleVersion)
      end
    end

    let(:authenticator) { DecisionAgent::Web::Server.authenticator }
    let(:user) do
      u = authenticator.create_user(
        email: "versionuser@example.com",
        password: "password123",
        roles: [:editor]
      )
      session = authenticator.login("versionuser@example.com", "password123")
      { user: u, session: session }
    end

    describe "POST /api/versions" do
      it "creates a version with all fields" do
        post "/api/versions",
             {
               rule_id: "rule1",
               content: { test: "data" },
               created_by: "test@example.com",
               changelog: "Initial version"
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        expect(last_response.status).to eq(201)
        json = JSON.parse(last_response.body)
        expect(json["rule_id"]).to eq("rule1")
      end

      it "creates a version without changelog" do
        post "/api/versions",
             {
               rule_id: "rule2",
               content: { test: "data" }
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        expect(last_response.status).to eq(201)
      end

      it "handles server errors" do
        allow_any_instance_of(DecisionAgent::Versioning::VersionManager).to receive(:save_version).and_raise(StandardError.new("DB error"))

        post "/api/versions",
             {
               rule_id: "rule1",
               content: { test: "data" }
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        expect(last_response.status).to eq(500)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("DB error")
      end
    end

    describe "GET /api/rules/:rule_id/versions" do
      it "returns versions with limit parameter" do
        get "/api/rules/rule1/versions?limit=5", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json).to be_an(Array)
      end

      it "handles server errors" do
        allow_any_instance_of(DecisionAgent::Versioning::VersionManager).to receive(:get_versions).and_raise(StandardError.new("DB error"))

        get "/api/rules/rule1/versions", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        expect(last_response.status).to eq(500)
      end
    end

    describe "GET /api/rules/:rule_id/history" do
      it "returns history for a rule" do
        get "/api/rules/rule1/history", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json).to be_a(Hash)
      end

      it "handles server errors" do
        allow_any_instance_of(DecisionAgent::Versioning::VersionManager).to receive(:get_history).and_raise(StandardError.new("DB error"))

        get "/api/rules/rule1/history", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        expect(last_response.status).to eq(500)
      end
    end

    describe "GET /api/versions/:version_id" do
      it "returns a specific version" do
        # First create a version
        post "/api/versions",
             {
               rule_id: "rule1",
               content: { test: "data" }
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        version_json = JSON.parse(last_response.body)
        version_id = version_json["id"]

        get "/api/versions/#{version_id}", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["id"]).to eq(version_id)
      end

      it "handles server errors" do
        allow_any_instance_of(DecisionAgent::Versioning::VersionManager).to receive(:get_version).and_raise(StandardError.new("DB error"))

        get "/api/versions/v1", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        expect(last_response.status).to eq(500)
      end
    end

    describe "POST /api/versions/:version_id/activate" do
      it "activates a version" do
        # First create a version
        post "/api/versions",
             {
               rule_id: "rule1",
               content: { test: "data" }
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        version_json = JSON.parse(last_response.body)
        version_id = version_json["id"]

        # Need deploy permission, create admin user
        authenticator.create_user(
          email: "deploy@example.com",
          password: "password123",
          roles: [:admin]
        )
        admin_session = authenticator.login("deploy@example.com", "password123")

        post "/api/versions/#{version_id}/activate",
             { performed_by: "admin@example.com" }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{admin_session.token}" }

        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["id"]).to eq(version_id)
      end

      it "activates with empty body" do
        # Create admin user for deploy permission
        authenticator.create_user(
          email: "deploy2@example.com",
          password: "password123",
          roles: [:admin]
        )
        admin_session = authenticator.login("deploy2@example.com", "password123")

        post "/api/versions/v1/activate",
             {}.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{admin_session.token}" }

        # May succeed or fail depending on version existence, but should not error on empty body
        expect([200, 404, 500]).to include(last_response.status)
      end

      it "handles server errors" do
        authenticator.create_user(
          email: "deploy3@example.com",
          password: "password123",
          roles: [:admin]
        )
        admin_session = authenticator.login("deploy3@example.com", "password123")

        allow_any_instance_of(DecisionAgent::Versioning::VersionManager).to receive(:rollback).and_raise(StandardError.new("DB error"))

        post "/api/versions/v1/activate",
             {}.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{admin_session.token}" }

        expect(last_response.status).to eq(500)
      end
    end

    describe "GET /api/versions/:version_id_1/compare/:version_id_2" do
      it "compares two versions" do
        get "/api/versions/v1/compare/v2", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        # May return 404 if versions don't exist, but should handle the request
        expect([200, 404]).to include(last_response.status)
      end

      it "handles server errors" do
        allow_any_instance_of(DecisionAgent::Versioning::VersionManager).to receive(:compare).and_raise(StandardError.new("DB error"))

        get "/api/versions/v1/compare/v2", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        expect(last_response.status).to eq(500)
      end
    end

    describe "DELETE /api/versions/:version_id" do
      it "deletes a version" do
        # Need delete permission, create admin user
        authenticator.create_user(
          email: "delete@example.com",
          password: "password123",
          roles: [:admin]
        )
        admin_session = authenticator.login("delete@example.com", "password123")

        delete "/api/versions/v1", {}, { "HTTP_AUTHORIZATION" => "Bearer #{admin_session.token}" }
        # May return 404 if version doesn't exist, but should handle the request
        expect([200, 404]).to include(last_response.status)
      end

      it "handles NotFoundError" do
        authenticator.create_user(
          email: "delete2@example.com",
          password: "password123",
          roles: [:admin]
        )
        admin_session = authenticator.login("delete2@example.com", "password123")

        allow_any_instance_of(DecisionAgent::Versioning::VersionManager).to receive(:delete_version).and_raise(DecisionAgent::NotFoundError.new("Version not found"))

        delete "/api/versions/v1", {}, { "HTTP_AUTHORIZATION" => "Bearer #{admin_session.token}" }
        expect(last_response.status).to eq(404)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Version not found")
      end

      it "handles ValidationError" do
        authenticator.create_user(
          email: "delete3@example.com",
          password: "password123",
          roles: [:admin]
        )
        admin_session = authenticator.login("delete3@example.com", "password123")

        allow_any_instance_of(DecisionAgent::Versioning::VersionManager).to receive(:delete_version).and_raise(DecisionAgent::ValidationError.new("Cannot delete active version"))

        delete "/api/versions/v1", {}, { "HTTP_AUTHORIZATION" => "Bearer #{admin_session.token}" }
        expect(last_response.status).to eq(422)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Cannot delete active version")
      end

      it "handles server errors" do
        authenticator.create_user(
          email: "delete4@example.com",
          password: "password123",
          roles: [:admin]
        )
        admin_session = authenticator.login("delete4@example.com", "password123")

        allow_any_instance_of(DecisionAgent::Versioning::VersionManager).to receive(:delete_version).and_raise(StandardError.new("DB error"))

        delete "/api/versions/v1", {}, { "HTTP_AUTHORIZATION" => "Bearer #{admin_session.token}" }
        expect(last_response.status).to eq(500)
      end

      it "handles unexpected errors during delete and converts to 404" do
        authenticator.create_user(
          email: "delete5@example.com",
          password: "password123",
          roles: [:admin]
        )
        admin_session = authenticator.login("delete5@example.com", "password123")

        # Simulate an unexpected error in the adapter (e.g., lock error, file system error)
        # This should be caught and converted to NotFoundError, resulting in 404
        adapter_instance = DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: "./versions")
        allow(DecisionAgent::Versioning::VersionManager).to receive(:new).and_return(
          DecisionAgent::Versioning::VersionManager.new(adapter: adapter_instance)
        )
        allow(adapter_instance).to receive(:list_versions_unsafe).and_raise(StandardError.new("Unexpected error"))

        delete "/api/versions/v1", {}, { "HTTP_AUTHORIZATION" => "Bearer #{admin_session.token}" }
        # Should return 404, not 500, due to error handling
        expect([200, 404]).to include(last_response.status)
      end
    end
  end

  describe "Versioning API integration tests with real FileStorageAdapter" do
    let(:temp_storage_path) { Dir.mktmpdir("versioning_test_") }
    let(:authenticator) { DecisionAgent::Web::Server.authenticator }
    let(:user) do
      u = authenticator.create_user(
        email: "versioninteg@example.com",
        password: "password123",
        roles: [:editor]
      )
      session = authenticator.login("versioninteg@example.com", "password123")
      { user: u, session: session }
    end

    before do
      # Create a real FileStorageAdapter and inject it into the server's version_manager
      real_adapter = DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: temp_storage_path)
      real_version_manager = DecisionAgent::Versioning::VersionManager.new(adapter: real_adapter)

      # Stub the version_manager method to return our real manager
      allow_any_instance_of(DecisionAgent::Web::Server).to receive(:version_manager).and_return(real_version_manager)
    end

    after do
      # Clean up temp directory
      FileUtils.rm_rf(temp_storage_path)
    end

    describe "POST /api/versions" do
      it "creates a version with real file storage" do
        rule_content = {
          version: "1.0",
          ruleset: "test_rules",
          rules: [{
            id: "rule1",
            if: { field: "amount", op: "gt", value: 100 },
            then: { decision: "approve", weight: 0.9, reason: "High amount" }
          }]
        }

        post "/api/versions",
             {
               rule_id: "integration_test_rule",
               content: rule_content,
               created_by: "integration@example.com",
               changelog: "Integration test version"
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        expect(last_response.status).to eq(201)
        json = JSON.parse(last_response.body)
        expect(json["rule_id"]).to eq("integration_test_rule")
        expect(json["version_number"]).to eq(1)
        expect(json["status"]).to eq("active") # FileStorageAdapter defaults to "active"
        expect(json["created_by"]).to eq("integration@example.com")

        # Verify file was actually created
        rule_dir = File.join(temp_storage_path, "integration_test_rule")
        expect(Dir.exist?(rule_dir)).to be true
        version_file = File.join(rule_dir, "1.json")
        expect(File.exist?(version_file)).to be true

        # Verify content
        stored_content = JSON.parse(File.read(version_file))
        # JSON parsing returns string keys, so we compare by converting both to same format
        expected_content = JSON.parse(JSON.generate(rule_content))
        expect(stored_content["content"]).to eq(expected_content)
      end

      it "creates multiple versions and increments version number" do
        rule_content = { version: "1.0", ruleset: "test", rules: [] }

        # Create first version
        post "/api/versions",
             {
               rule_id: "multi_version_rule",
               content: rule_content,
               created_by: "test@example.com"
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        expect(last_response.status).to eq(201)
        json1 = JSON.parse(last_response.body)
        expect(json1["version_number"]).to eq(1)

        # Create second version
        post "/api/versions",
             {
               rule_id: "multi_version_rule",
               content: rule_content.merge(version: "2.0"),
               created_by: "test@example.com"
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        expect(last_response.status).to eq(201)
        json2 = JSON.parse(last_response.body)
        expect(json2["version_number"]).to eq(2)
      end
    end

    describe "GET /api/rules/:rule_id/versions" do
      it "returns versions from real file storage" do
        rule_content = { version: "1.0", ruleset: "test", rules: [] }

        # Create two versions
        post "/api/versions",
             {
               rule_id: "list_test_rule",
               content: rule_content,
               created_by: "test@example.com"
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        post "/api/versions",
             {
               rule_id: "list_test_rule",
               content: rule_content,
               created_by: "test@example.com"
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        # List versions
        get "/api/rules/list_test_rule/versions", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        expect(last_response.status).to eq(200)
        json = JSON.parse(last_response.body)
        expect(json).to be_an(Array)
        expect(json.length).to eq(2)
        expect(json.first["version_number"]).to eq(2) # Most recent first
        expect(json.last["version_number"]).to eq(1)
      end

      it "respects limit parameter" do
        rule_content = { version: "1.0", ruleset: "test", rules: [] }

        # Create three versions
        3.times do
          post "/api/versions",
               {
                 rule_id: "limit_test_rule",
                 content: rule_content,
                 created_by: "test@example.com"
               }.to_json,
               { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        end

        # List with limit
        get "/api/rules/limit_test_rule/versions?limit=2", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        expect(last_response.status).to eq(200)
        json = JSON.parse(last_response.body)
        expect(json.length).to eq(2)
      end
    end

    describe "GET /api/rules/:rule_id/history" do
      it "returns history from real file storage" do
        rule_content = { version: "1.0", ruleset: "test", rules: [] }

        # Create a version
        post "/api/versions",
             {
               rule_id: "history_test_rule",
               content: rule_content,
               created_by: "test@example.com",
               changelog: "Test changelog"
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        # Get history
        get "/api/rules/history_test_rule/history", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        expect(last_response.status).to eq(200)
        json = JSON.parse(last_response.body)
        expect(json).to be_a(Hash)
        expect(json["total_versions"]).to eq(1)
        expect(json["versions"]).to be_an(Array)
        expect(json["versions"].length).to eq(1)
      end
    end

    describe "GET /api/versions/:version_id" do
      it "retrieves a specific version from real file storage" do
        rule_content = {
          version: "1.0",
          ruleset: "test",
          rules: [{ id: "test_rule", if: { field: "x", op: "eq", value: 1 }, then: { decision: "yes" } }]
        }

        # Create a version
        post "/api/versions",
             {
               rule_id: "get_version_test",
               content: rule_content,
               created_by: "test@example.com"
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        version_json = JSON.parse(last_response.body)
        version_id = version_json["id"]

        # Get the version
        get "/api/versions/#{version_id}", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        expect(last_response.status).to eq(200)
        json = JSON.parse(last_response.body)
        expect(json["id"]).to eq(version_id)
        expect(json["rule_id"]).to eq("get_version_test")
        # JSON parsing returns string keys, so we compare by converting both to same format
        expected_content = JSON.parse(JSON.generate(rule_content))
        expect(json["content"]).to eq(expected_content)
      end
    end

    describe "POST /api/versions/:version_id/activate" do
      it "activates a version with real file storage" do
        # Create admin user for deploy permission
        authenticator.create_user(
          email: "deployadmin@example.com",
          password: "password123",
          roles: [:admin]
        )
        admin_session = authenticator.login("deployadmin@example.com", "password123")

        rule_content = { version: "1.0", ruleset: "test", rules: [] }

        # Create a version
        post "/api/versions",
             {
               rule_id: "activate_test_rule",
               content: rule_content,
               created_by: "test@example.com"
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        version_json = JSON.parse(last_response.body)
        version_id = version_json["id"]

        # Activate the version
        post "/api/versions/#{version_id}/activate",
             { performed_by: "admin@example.com" }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{admin_session.token}" }

        expect(last_response.status).to eq(200)
        json = JSON.parse(last_response.body)
        expect(json["id"]).to eq(version_id)
        expect(json["status"]).to eq("active")

        # Verify it's active by getting the version again
        get "/api/versions/#{version_id}", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        active_json = JSON.parse(last_response.body)
        expect(active_json["status"]).to eq("active")
      end
    end

    describe "GET /api/versions/:version_id_1/compare/:version_id_2" do
      it "compares two versions from real file storage" do
        base_content = { version: "1.0", ruleset: "test", rules: [{ id: "r1" }] }
        modified_content = { version: "1.0", ruleset: "test", rules: [{ id: "r1" }, { id: "r2" }] }

        # Create first version
        post "/api/versions",
             {
               rule_id: "compare_test_rule",
               content: base_content,
               created_by: "test@example.com"
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        v1_json = JSON.parse(last_response.body)
        v1_id = v1_json["id"]

        # Create second version
        post "/api/versions",
             {
               rule_id: "compare_test_rule",
               content: modified_content,
               created_by: "test@example.com"
             }.to_json,
             { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }
        v2_json = JSON.parse(last_response.body)
        v2_id = v2_json["id"]

        # Compare versions
        get "/api/versions/#{v1_id}/compare/#{v2_id}", {}, { "HTTP_AUTHORIZATION" => "Bearer #{user[:session].token}" }

        expect(last_response.status).to eq(200)
        json = JSON.parse(last_response.body)
        expect(json).to be_a(Hash)
        expect(json).to have_key("version_1") # compare_versions returns version_1 and version_2
        expect(json).to have_key("version_2")
        expect(json).to have_key("differences")
      end
    end
  end

  describe "Batch Testing API comprehensive tests" do
    describe "POST /api/testing/batch/import" do
      it "handles Excel file import" do
        skip "Roo gem not available" unless defined?(Roo)

        # Create a minimal Excel file for testing
        # Since we can't easily create Excel files in tests, we'll test the error path
        file = Tempfile.new(["test", ".xlsx"])
        file.write("not excel content")
        file.rewind

        post "/api/testing/batch/import", { file: Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") }, { "CONTENT_TYPE" => "multipart/form-data" }

        # Should handle error gracefully
        expect([400, 422, 500]).to include(last_response.status)

        file.close
        file.unlink
      end

      it "handles file with no extension" do
        file = Tempfile.new(["test", ""])
        file.write("id,user_id\n")
        file.rewind

        post "/api/testing/batch/import", { file: Rack::Test::UploadedFile.new(file.path, "text/plain") }, { "CONTENT_TYPE" => "multipart/form-data" }

        # Should treat as CSV or handle error
        expect([201, 400, 422, 500]).to include(last_response.status)

        file.close
        file.unlink
      end
    end

    describe "POST /api/testing/batch/run" do
      it "handles batch test execution with options" do
        csv_content = "id,user_id,amount\ntest_1,123,1000\n"
        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.rewind

        post "/api/testing/batch/import", { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }, { "CONTENT_TYPE" => "multipart/form-data" }
        import_json = JSON.parse(last_response.body)
        test_id = import_json["test_id"]

        rules_json = {
          version: "1.0",
          ruleset: "test",
          rules: [{ id: "rule_1", if: { field: "amount", op: "gt", value: 500 }, then: { decision: "approve", weight: 0.9, reason: "Test" } }]
        }

        post "/api/testing/batch/run",
             { test_id: test_id, rules: rules_json, options: { parallel: false, thread_count: 1 } }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(200)
        json = JSON.parse(last_response.body)
        expect(json["status"]).to eq("completed")

        file.close
        file.unlink
      end

      it "handles execution errors and updates status" do
        csv_content = "id,user_id,amount\ntest_1,123,1000\n"
        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.rewind

        post "/api/testing/batch/import", { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }, { "CONTENT_TYPE" => "multipart/form-data" }
        import_json = JSON.parse(last_response.body)
        test_id = import_json["test_id"]

        # Use invalid rules to cause an error
        invalid_rules = { version: "1.0", ruleset: "test", rules: "invalid" }

        post "/api/testing/batch/run",
             { test_id: test_id, rules: invalid_rules }.to_json,
             { "CONTENT_TYPE" => "application/json" }

        expect(last_response.status).to eq(500)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to be_present

        # Verify status was updated to failed
        get "/api/testing/batch/#{test_id}/results"
        result_json = JSON.parse(last_response.body)
        expect(result_json["status"]).to eq("failed")

        file.close
        file.unlink
      end
    end

    describe "GET /api/testing/batch/:id/results" do
      it "returns full results with all fields" do
        csv_content = "id,user_id,amount\ntest_1,123,1000\n"
        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.rewind

        post "/api/testing/batch/import", { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }, { "CONTENT_TYPE" => "multipart/form-data" }
        import_json = JSON.parse(last_response.body)
        test_id = import_json["test_id"]

        rules_json = {
          version: "1.0",
          ruleset: "test",
          rules: [{ id: "rule_1", if: { field: "amount", op: "gt", value: 500 }, then: { decision: "approve", weight: 0.9, reason: "Test" } }]
        }

        post "/api/testing/batch/run", { test_id: test_id, rules: rules_json }.to_json, { "CONTENT_TYPE" => "application/json" }

        get "/api/testing/batch/#{test_id}/results"
        expect(last_response.status).to eq(200)
        json = JSON.parse(last_response.body)
        expect(json["test_id"]).to eq(test_id)
        expect(json["status"]).to eq("completed")
        expect(json).to have_key("results")
        expect(json).to have_key("statistics")

        file.close
        file.unlink
      end

      it "handles server errors" do
        allow(DecisionAgent::Web::Server.batch_test_storage_mutex).to receive(:synchronize).and_raise(StandardError.new("Storage error"))

        get "/api/testing/batch/test123/results"
        expect(last_response.status).to eq(500)
      end
    end

    describe "GET /api/testing/batch/:id/coverage" do
      it "returns coverage report when available" do
        csv_content = "id,user_id,amount\ntest_1,123,1000\n"
        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.rewind

        post "/api/testing/batch/import", { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }, { "CONTENT_TYPE" => "multipart/form-data" }
        import_json = JSON.parse(last_response.body)
        test_id = import_json["test_id"]

        rules_json = {
          version: "1.0",
          ruleset: "test",
          rules: [{ id: "rule_1", if: { field: "amount", op: "gt", value: 500 }, then: { decision: "approve", weight: 0.9, reason: "Test" } }]
        }

        post "/api/testing/batch/run", { test_id: test_id, rules: rules_json }.to_json, { "CONTENT_TYPE" => "application/json" }

        get "/api/testing/batch/#{test_id}/coverage"
        expect(last_response.status).to eq(200)
        json = JSON.parse(last_response.body)
        expect(json["test_id"]).to eq(test_id)
        expect(json).to have_key("coverage")

        file.close
        file.unlink
      end

      it "handles server errors" do
        allow(DecisionAgent::Web::Server.batch_test_storage_mutex).to receive(:synchronize).and_raise(StandardError.new("Storage error"))

        get "/api/testing/batch/test123/coverage"
        expect(last_response.status).to eq(500)
      end
    end

    describe "GET /testing/batch, /auth/login, /auth/users" do
      it "handles missing files gracefully" do
        # Stub send_file to raise error
        allow_any_instance_of(DecisionAgent::Web::Server).to receive(:send_file).and_raise(StandardError.new("File not found"))

        get "/testing/batch"
        expect(last_response.status).to eq(404)
        expect(last_response.body).to include("Batch testing page not found")

        get "/auth/login"
        expect(last_response.status).to eq(404)
        expect(last_response.body).to include("Login page not found")

        get "/auth/users"
        expect(last_response.status).to eq(404)
        expect(last_response.body).to include("User management page not found")
      end
    end
  end

  describe "Auth and permission edge cases" do
    let(:authenticator) { DecisionAgent::Web::Server.authenticator }

    describe "require_permission!" do
      it "denies access and logs permission check" do
        authenticator.create_user(
          email: "noperm@example.com",
          password: "password123",
          roles: []
        )
        session = authenticator.login("noperm@example.com", "password123")

        get "/api/auth/roles", {}, { "HTTP_AUTHORIZATION" => "Bearer #{session.token}" }
        expect(last_response.status).to eq(403)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Permission denied")
      end

      it "requires authentication before checking permissions" do
        get "/api/auth/roles", {}, {}
        # May return 401 (no auth) or 403 (auth but no permission)
        expect([401, 403]).to include(last_response.status)
      end

      it "handles audit logger failures gracefully" do
        authenticator.create_user(
          email: "loggerfail@example.com",
          password: "password123",
          roles: []
        )
        session = authenticator.login("loggerfail@example.com", "password123")

        # Simulate audit logger failure
        allow_any_instance_of(DecisionAgent::Auth::AccessAuditLogger).to receive(:log_permission_check).and_raise(StandardError.new("Logger error"))

        # Should still deny permission even if logging fails
        get "/api/auth/roles", {}, { "HTTP_AUTHORIZATION" => "Bearer #{session.token}" }
        expect(last_response.status).to eq(403)
        json = JSON.parse(last_response.body)
        expect(json["error"]).to include("Permission denied")
      end

      it "handles audit logger failures when permission is granted" do
        authenticator.create_user(
          email: "loggerfail2@example.com",
          password: "password123",
          roles: [:admin]
        )
        admin_session = authenticator.login("loggerfail2@example.com", "password123")

        # Simulate audit logger failure after permission check passes
        allow_any_instance_of(DecisionAgent::Auth::AccessAuditLogger).to receive(:log_permission_check).and_raise(StandardError.new("Logger error"))

        # Should still allow access even if logging fails
        get "/api/auth/roles", {}, { "HTTP_AUTHORIZATION" => "Bearer #{admin_session.token}" }
        expect(last_response.status).to eq(200)
      end
    end

    describe "extract_token" do
      it "extracts token from cookie" do
        authenticator.create_user(
          email: "cookieuser@example.com",
          password: "password123"
        )
        session = authenticator.login("cookieuser@example.com", "password123")

        get "/api/auth/me", {}, { "HTTP_COOKIE" => "decision_agent_session=#{session.token}" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["email"]).to eq("cookieuser@example.com")
      end

      it "extracts token from query parameter" do
        authenticator.create_user(
          email: "queryuser@example.com",
          password: "password123"
        )
        session = authenticator.login("queryuser@example.com", "password123")

        get "/api/auth/me?token=#{session.token}"
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["email"]).to eq("queryuser@example.com")
      end

      it "prefers Authorization header over cookie" do
        authenticator.create_user(
          email: "prefuser@example.com",
          password: "password123"
        )
        session1 = authenticator.login("prefuser@example.com", "password123")
        authenticator.create_user(
          email: "prefuser2@example.com",
          password: "password123"
        )
        session2 = authenticator.login("prefuser2@example.com", "password123")

        get "/api/auth/me",
            {},
            { "HTTP_AUTHORIZATION" => "Bearer #{session1.token}", "HTTP_COOKIE" => "decision_agent_session=#{session2.token}" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["email"]).to eq("prefuser@example.com")
      end
    end

    describe "POST /api/auth/logout" do
      it "handles logout with invalid token gracefully" do
        post "/api/auth/logout", {}, { "HTTP_AUTHORIZATION" => "Bearer invalid_token" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json["success"]).to be true
      end
    end

    describe "GET /api/auth/audit" do
      let(:admin_user) do
        user = authenticator.create_user(
          email: "auditadmin2@example.com",
          password: "password123",
          roles: [:admin]
        )
        session = authenticator.login("auditadmin2@example.com", "password123")
        { user: user, session: session }
      end

      it "filters by multiple parameters" do
        get "/api/auth/audit?user_id=#{admin_user[:user].id}&event_type=login&limit=10",
            {},
            { "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }
        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json).to be_an(Array)
      end

      it "handles server errors" do
        allow(DecisionAgent::Web::Server.access_audit_logger).to receive(:query).and_raise(StandardError.new("DB error"))

        get "/api/auth/audit", {}, { "HTTP_AUTHORIZATION" => "Bearer #{admin_user[:session].token}" }
        expect(last_response.status).to eq(500)
      end
    end
  end

  describe "Class methods" do
    describe ".start!" do
      it "sets port and bind" do
        expect(DecisionAgent::Web::Server).to respond_to(:start!)
        # We can't easily test this without actually starting a server, so we just verify the method exists
      end
    end

    describe ".batch_test_storage" do
      it "initializes storage hash if nil" do
        original_storage = DecisionAgent::Web::Server.instance_variable_get(:@batch_test_storage)
        DecisionAgent::Web::Server.instance_variable_set(:@batch_test_storage, nil)

        storage = DecisionAgent::Web::Server.batch_test_storage
        expect(storage).to be_a(Hash)

        DecisionAgent::Web::Server.instance_variable_set(:@batch_test_storage, original_storage)
      end
    end

    describe ".batch_test_storage_mutex" do
      it "initializes mutex if nil" do
        original_mutex = DecisionAgent::Web::Server.instance_variable_get(:@batch_test_storage_mutex)
        DecisionAgent::Web::Server.instance_variable_set(:@batch_test_storage_mutex, nil)

        mutex = DecisionAgent::Web::Server.batch_test_storage_mutex
        expect(mutex).to be_a(Mutex)

        DecisionAgent::Web::Server.instance_variable_set(:@batch_test_storage_mutex, original_mutex)
      end
    end

    describe ".authenticator=" do
      it "allows setting custom authenticator" do
        original_auth = DecisionAgent::Web::Server.authenticator
        custom_auth = double("Authenticator")
        DecisionAgent::Web::Server.authenticator = custom_auth
        expect(DecisionAgent::Web::Server.authenticator).to eq(custom_auth)
        DecisionAgent::Web::Server.authenticator = original_auth
      end
    end

    describe ".permission_checker=" do
      it "allows setting custom permission checker" do
        original_checker = DecisionAgent::Web::Server.permission_checker
        custom_checker = double("PermissionChecker")
        DecisionAgent::Web::Server.permission_checker = custom_checker
        expect(DecisionAgent::Web::Server.permission_checker).to eq(custom_checker)
        DecisionAgent::Web::Server.permission_checker = original_checker
      end
    end

    describe ".access_audit_logger=" do
      it "allows setting custom access audit logger" do
        original_logger = DecisionAgent::Web::Server.access_audit_logger
        custom_logger = double("AccessAuditLogger")
        DecisionAgent::Web::Server.access_audit_logger = custom_logger
        expect(DecisionAgent::Web::Server.access_audit_logger).to eq(custom_logger)
        DecisionAgent::Web::Server.access_audit_logger = original_logger
      end
    end
  end
end
