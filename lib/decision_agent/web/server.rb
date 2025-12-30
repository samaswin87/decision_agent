require "sinatra/base"
require "json"
require "securerandom"
require "tempfile"

# Ensure testing classes are loaded
require_relative "../testing/test_scenario"
require_relative "../testing/batch_test_importer"
require_relative "../testing/batch_test_runner"
require_relative "../testing/test_result_comparator"
require_relative "../testing/test_coverage_analyzer"
require_relative "../evaluators/json_rule_evaluator"
require_relative "../agent"

# Auth components
require_relative "../auth/user"
require_relative "../auth/role"
require_relative "../auth/permission"
require_relative "../auth/session"
require_relative "../auth/session_manager"
require_relative "../auth/authenticator"
require_relative "../auth/permission_checker"
require_relative "../auth/access_audit_logger"
require_relative "middleware/auth_middleware"
require_relative "middleware/permission_middleware"

module DecisionAgent
  module Web
    # rubocop:disable Metrics/ClassLength
    class Server < Sinatra::Base
      set :public_folder, File.expand_path("public", __dir__)
      set :views, File.expand_path("views", __dir__)
      set :bind, "0.0.0.0"
      set :port, 4567

      # In-memory storage for batch test runs
      @batch_test_storage = {}
      @batch_test_storage_mutex = Mutex.new

      # Auth components
      @authenticator = nil
      @permission_checker = nil
      @access_audit_logger = nil

      def self.batch_test_storage
        @batch_test_storage ||= {}
      end

      def self.batch_test_storage_mutex
        @batch_test_storage_mutex ||= Mutex.new
      end

      class << self
        attr_writer :authenticator
      end

      def self.authenticator
        @authenticator ||= Auth::Authenticator.new
      end

      class << self
        attr_writer :permission_checker
      end

      def self.permission_checker
        @permission_checker ||= Auth::PermissionChecker.new(adapter: DecisionAgent.rbac_config.adapter)
      end

      class << self
        attr_writer :access_audit_logger
      end

      def self.access_audit_logger
        @access_audit_logger ||= Auth::AccessAuditLogger.new
      end

      # Enable CORS for API calls
      before do
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Access-Control-Allow-Methods"] = "GET, POST, DELETE, OPTIONS"
        headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
      end

      # Auth middleware - extract user from token
      before do
        token = extract_token
        if token
          auth_result = self.class.authenticator.authenticate(token)
          if auth_result
            @current_user = auth_result[:user]
            @current_session = auth_result[:session]
          end
        end
      end

      # OPTIONS handler for CORS preflight
      options "*" do
        200
      end

      # Main page - serve the rule builder UI
      get "/" do
        send_file File.join(settings.public_folder, "index.html")
      end

      # API: Validate rules
      post "/api/validate" do
        content_type :json

        begin
          # Parse request body
          request_body = request.body.read
          data = JSON.parse(request_body)

          # Validate using DecisionAgent's SchemaValidator
          DecisionAgent::Dsl::SchemaValidator.validate!(data)

          # If validation passes
          {
            valid: true,
            message: "Rules are valid!"
          }.to_json
        rescue JSON::ParserError => e
          status 400
          {
            valid: false,
            errors: ["Invalid JSON: #{e.message}"]
          }.to_json
        rescue DecisionAgent::InvalidRuleDslError => e
          # Validation failed
          status 422
          {
            valid: false,
            errors: parse_validation_errors(e.message)
          }.to_json
        rescue StandardError => e
          # Unexpected error
          status 500
          {
            valid: false,
            errors: ["Server error: #{e.message}"]
          }.to_json
        end
      end

      # API: Test rule evaluation (optional feature)
      post "/api/evaluate" do
        content_type :json

        begin
          request_body = request.body.read
          data = JSON.parse(request_body)

          rules_json = data["rules"]
          context = data["context"] || {}

          # Create evaluator
          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules_json)

          # Evaluate
          result = evaluator.evaluate(DecisionAgent::Context.new(context))

          if result
            {
              success: true,
              decision: result.decision,
              weight: result.weight,
              reason: result.reason,
              evaluator_name: result.evaluator_name,
              metadata: result.metadata
            }.to_json
          else
            {
              success: true,
              decision: nil,
              message: "No rules matched the given context"
            }.to_json
          end
        rescue StandardError => e
          status 500
          {
            success: false,
            error: e.message
          }.to_json
        end
      end

      # API: Get example rules
      get "/api/examples" do
        content_type :json

        examples = [
          {
            name: "Approval Workflow",
            description: "Basic approval rules for requests",
            rules: {
              version: "1.0",
              ruleset: "approval_workflow",
              rules: [
                {
                  id: "admin_auto_approve",
                  if: { field: "user.role", op: "eq", value: "admin" },
                  then: { decision: "approve", weight: 0.95, reason: "Admin user" }
                },
                {
                  id: "low_amount_approve",
                  if: { field: "amount", op: "lt", value: 1000 },
                  then: { decision: "approve", weight: 0.8, reason: "Low amount" }
                },
                {
                  id: "high_amount_review",
                  if: { field: "amount", op: "gte", value: 10_000 },
                  then: { decision: "manual_review", weight: 0.9, reason: "High amount requires review" }
                }
              ]
            }
          },
          {
            name: "User Access Control",
            description: "Role-based access control rules",
            rules: {
              version: "1.0",
              ruleset: "access_control",
              rules: [
                {
                  id: "admin_full_access",
                  if: {
                    all: [
                      { field: "user.role", op: "eq", value: "admin" },
                      { field: "user.active", op: "eq", value: true }
                    ]
                  },
                  then: { decision: "allow", weight: 1.0, reason: "Active admin user" }
                },
                {
                  id: "guest_read_only",
                  if: {
                    all: [
                      { field: "user.role", op: "eq", value: "guest" },
                      { field: "action", op: "eq", value: "read" }
                    ]
                  },
                  then: { decision: "allow", weight: 0.7, reason: "Guest read access" }
                },
                {
                  id: "inactive_user_deny",
                  if: { field: "user.active", op: "eq", value: false },
                  then: { decision: "deny", weight: 1.0, reason: "Inactive user account" }
                }
              ]
            }
          },
          {
            name: "Content Moderation",
            description: "Automatic content moderation rules",
            rules: {
              version: "1.0",
              ruleset: "content_moderation",
              rules: [
                {
                  id: "verified_user_approve",
                  if: {
                    all: [
                      { field: "author.verified", op: "eq", value: true },
                      { field: "content_length", op: "lt", value: 5000 }
                    ]
                  },
                  then: { decision: "approve", weight: 0.85, reason: "Verified author with reasonable length" }
                },
                {
                  id: "missing_content_reject",
                  if: {
                    any: [
                      { field: "content", op: "blank" },
                      { field: "content_length", op: "eq", value: 0 }
                    ]
                  },
                  then: { decision: "reject", weight: 1.0, reason: "Empty content" }
                },
                {
                  id: "flagged_content_review",
                  if: { field: "flags", op: "present" },
                  then: { decision: "manual_review", weight: 0.9, reason: "Content has been flagged" }
                }
              ]
            }
          }
        ]

        examples.to_json
      end

      # Health check
      get "/health" do
        content_type :json
        { status: "ok", version: DecisionAgent::VERSION }.to_json
      end

      # Authentication API endpoints

      # POST /api/auth/login - User login
      post "/api/auth/login" do
        content_type :json

        begin
          request_body = request.body.read
          data = JSON.parse(request_body)

          email = data["email"]
          password = data["password"]

          unless email && password
            status 400
            return { error: "Email and password are required" }.to_json
          end

          session = self.class.authenticator.login(email, password)

          unless session
            self.class.access_audit_logger.log_authentication(
              "login",
              user_id: nil,
              email: email,
              success: false,
              reason: "Invalid credentials"
            )
            status 401
            return { error: "Invalid email or password" }.to_json
          end

          user = self.class.authenticator.find_user(session.user_id)

          self.class.access_audit_logger.log_authentication(
            "login",
            user_id: user.id,
            email: user.email,
            success: true
          )

          {
            token: session.token,
            user: user.to_h,
            expires_at: session.expires_at.iso8601
          }.to_json
        rescue JSON::ParserError
          status 400
          { error: "Invalid JSON" }.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # POST /api/auth/logout - User logout
      post "/api/auth/logout" do
        content_type :json

        begin
          token = extract_token
          if token
            self.class.authenticator.logout(token)
            if @current_user
              checker = self.class.permission_checker
              self.class.access_audit_logger.log_authentication(
                "logout",
                user_id: checker.user_id(@current_user),
                email: checker.user_email(@current_user),
                success: true
              )
            end
          end

          { success: true, message: "Logged out successfully" }.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # GET /api/auth/me - Current user info
      get "/api/auth/me" do
        content_type :json

        if @current_user
          @current_user.to_h.to_json
        else
          status 401
          { error: "Not authenticated" }.to_json
        end
      end

      # GET /api/auth/roles - List all roles
      get "/api/auth/roles" do
        content_type :json
        require_permission!(:read)

        roles = Auth::Role.all.map do |role|
          {
            id: role.to_s,
            name: Auth::Role.name_for(role),
            permissions: Auth::Role.permissions_for(role).map(&:to_s)
          }
        end

        roles.to_json
      end

      # POST /api/auth/users - Create user (admin only)
      post "/api/auth/users" do
        content_type :json
        require_permission!(:manage_users)

        begin
          request_body = request.body.read
          data = JSON.parse(request_body)

          email = data["email"]
          password = data["password"]
          roles = data["roles"] || []

          unless email && password
            status 400
            return { error: "Email and password are required" }.to_json
          end

          # Validate roles
          roles.each do |role|
            unless Auth::Role.exists?(role)
              status 400
              return { error: "Invalid role: #{role}" }.to_json
            end
          end

          user = self.class.authenticator.create_user(
            email: email,
            password: password,
            roles: roles
          )

          checker = self.class.permission_checker
          self.class.access_audit_logger.log_access(
            user_id: checker.user_id(@current_user),
            action: "create_user",
            resource_type: "user",
            resource_id: user.id,
            success: true
          )

          status 201
          user.to_h.to_json
        rescue JSON::ParserError
          status 400
          { error: "Invalid JSON" }.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # GET /api/auth/users - List users (admin only)
      get "/api/auth/users" do
        content_type :json
        require_permission!(:manage_users)

        users = self.class.authenticator.user_store.all.map(&:to_h)
        users.to_json
      end

      # POST /api/auth/users/:id/roles - Assign role to user (admin only)
      post "/api/auth/users/:id/roles" do
        content_type :json
        require_permission!(:manage_users)

        begin
          user_id = params[:id]
          request_body = request.body.read
          data = JSON.parse(request_body)

          role = data["role"]

          unless role
            status 400
            return { error: "Role is required" }.to_json
          end

          unless Auth::Role.exists?(role)
            status 400
            return { error: "Invalid role: #{role}" }.to_json
          end

          user = self.class.authenticator.find_user(user_id)
          unless user
            status 404
            return { error: "User not found" }.to_json
          end

          user.assign_role(role)

          checker = self.class.permission_checker
          self.class.access_audit_logger.log_access(
            user_id: checker.user_id(@current_user),
            action: "assign_role",
            resource_type: "user",
            resource_id: user.id,
            success: true
          )

          user.to_h.to_json
        rescue JSON::ParserError
          status 400
          { error: "Invalid JSON" }.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # DELETE /api/auth/users/:id/roles/:role - Remove role from user (admin only)
      delete "/api/auth/users/:id/roles/:role" do
        content_type :json
        require_permission!(:manage_users)

        begin
          user_id = params[:id]
          role = params[:role]

          user = self.class.authenticator.find_user(user_id)
          unless user
            status 404
            return { error: "User not found" }.to_json
          end

          user.remove_role(role)

          checker = self.class.permission_checker
          self.class.access_audit_logger.log_access(
            user_id: checker.user_id(@current_user),
            action: "remove_role",
            resource_type: "user",
            resource_id: user.id,
            success: true
          )

          user.to_h.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # GET /api/auth/audit - Query access audit logs
      get "/api/auth/audit" do
        content_type :json
        require_permission!(:audit)

        begin
          filters = {}

          filters[:user_id] = params[:user_id] if params[:user_id]
          filters[:event_type] = params[:event_type] if params[:event_type]
          filters[:start_time] = params[:start_time] if params[:start_time]
          filters[:end_time] = params[:end_time] if params[:end_time]
          filters[:limit] = params[:limit]&.to_i if params[:limit]

          logs = self.class.access_audit_logger.query(filters)
          logs.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # POST /api/auth/password/reset-request - Request password reset
      post "/api/auth/password/reset-request" do
        content_type :json

        begin
          request_body = request.body.read
          data = JSON.parse(request_body)

          email = data["email"]

          unless email
            status 400
            return { error: "Email is required" }.to_json
          end

          token = self.class.authenticator.request_password_reset(email)

          # For security, we always return success even if user doesn't exist
          # In production, you would send the token via email
          if token
            self.class.access_audit_logger.log_authentication(
              "password_reset_request",
              user_id: token.user_id,
              email: email,
              success: true
            )

            {
              success: true,
              message: "If the email exists, a password reset token has been generated",
              # In production, remove this token from response and send via email
              token: token.token,
              expires_at: token.expires_at.iso8601
            }.to_json
          else
            # Log failed attempt (but don't reveal if user exists)
            self.class.access_audit_logger.log_authentication(
              "password_reset_request",
              user_id: nil,
              email: email,
              success: false,
              reason: "User not found or inactive"
            )

            {
              success: true,
              message: "If the email exists, a password reset token has been generated"
            }.to_json
          end
        rescue JSON::ParserError
          status 400
          { error: "Invalid JSON" }.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # POST /api/auth/password/reset - Reset password with token
      post "/api/auth/password/reset" do
        content_type :json

        begin
          request_body = request.body.read
          data = JSON.parse(request_body)

          token = data["token"]
          new_password = data["password"]

          unless token && new_password
            status 400
            return { error: "Token and password are required" }.to_json
          end

          unless new_password.length >= 8
            status 400
            return { error: "Password must be at least 8 characters long" }.to_json
          end

          user = self.class.authenticator.reset_password(token, new_password)

          unless user
            status 400
            return { error: "Invalid or expired reset token" }.to_json
          end

          self.class.access_audit_logger.log_authentication(
            "password_reset",
            user_id: user.id,
            email: user.email,
            success: true
          )

          {
            success: true,
            message: "Password has been reset successfully"
          }.to_json
        rescue JSON::ParserError
          status 400
          { error: "Invalid JSON" }.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Versioning API endpoints

      # Create a new version
      post "/api/versions" do
        content_type :json
        require_permission!(:write)

        begin
          request_body = request.body.read
          data = JSON.parse(request_body)

          rule_id = data["rule_id"]
          rule_content = data["content"]
          created_by = data["created_by"] || (@current_user&.email || "system")
          changelog = data["changelog"]

          version = version_manager.save_version(
            rule_id: rule_id,
            rule_content: rule_content,
            created_by: created_by,
            changelog: changelog
          )

          status 201
          version.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # List all versions for a rule
      get "/api/rules/:rule_id/versions" do
        content_type :json
        require_permission!(:read)

        begin
          rule_id = params[:rule_id]
          limit = params[:limit]&.to_i

          versions = version_manager.get_versions(rule_id: rule_id, limit: limit)

          versions.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Get version history with metadata
      get "/api/rules/:rule_id/history" do
        content_type :json
        require_permission!(:read)

        begin
          rule_id = params[:rule_id]
          history = version_manager.get_history(rule_id: rule_id)

          history.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Get a specific version
      get "/api/versions/:version_id" do
        content_type :json
        require_permission!(:read)

        begin
          version_id = params[:version_id]
          version = version_manager.get_version(version_id: version_id)

          if version
            version.to_json
          else
            status 404
            { error: "Version not found" }.to_json
          end
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Activate a version (rollback)
      post "/api/versions/:version_id/activate" do
        content_type :json
        require_permission!(:deploy)

        begin
          version_id = params[:version_id]
          request_body = request.body.read
          data = request_body.empty? ? {} : JSON.parse(request_body)
          performed_by = data["performed_by"] || (@current_user&.email || "system")

          version = version_manager.rollback(
            version_id: version_id,
            performed_by: performed_by
          )

          version.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Compare two versions
      get "/api/versions/:version_id_1/compare/:version_id_2" do
        content_type :json
        require_permission!(:read)

        begin
          version_id_1 = params[:version_id_1]
          version_id_2 = params[:version_id_2]

          comparison = version_manager.compare(
            version_id_1: version_id_1,
            version_id_2: version_id_2
          )

          if comparison
            comparison.to_json
          else
            status 404
            { error: "One or both versions not found" }.to_json
          end
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Delete a version
      delete "/api/versions/:version_id" do
        content_type :json

        begin
          require_permission!(:delete)
          version_id = params[:version_id]

          # Ensure version_id is present
          unless version_id
            status 400
            return { error: "Version ID is required" }.to_json
          end

          result = version_manager.delete_version(version_id: version_id)

          if result == false
            status 404
            { error: "Version not found" }.to_json
          else
            status 200
            { success: true, message: "Version deleted successfully" }.to_json
          end
        rescue DecisionAgent::NotFoundError => e
          status 404
          { error: e.message }.to_json
        rescue DecisionAgent::ValidationError => e
          status 422
          { error: e.message }.to_json
        rescue StandardError
          # Log the error for debugging but return a safe response
          # In production, you might want to log this to a proper logger
          status 500
          { error: "Internal server error" }.to_json
        end
      end

      # Batch Testing API Endpoints

      # POST /api/testing/batch/import - Upload CSV/Excel file
      post "/api/testing/batch/import" do
        content_type :json

        begin
          unless params[:file] && params[:file][:tempfile]
            status 400
            return { error: "No file uploaded" }.to_json
          end

          uploaded_file = params[:file][:tempfile]
          filename = params[:file][:filename] || "uploaded_file"
          file_extension = File.extname(filename).downcase

          # Create temporary file
          temp_file = Tempfile.new(["batch_test", file_extension])
          temp_file.binmode
          temp_file.write(uploaded_file.read)
          temp_file.rewind

          # Import scenarios based on file type
          importer = DecisionAgent::Testing::BatchTestImporter.new

          scenarios = if [".xlsx", ".xls"].include?(file_extension)
                        importer.import_excel(temp_file.path)
                      else
                        importer.import_csv(temp_file.path)
                      end

          temp_file.close
          temp_file.unlink

          # Check for import errors - return error status if there are errors and no scenarios
          if importer.errors.any? && scenarios.empty?
            status 422
            return { error: "Import failed: #{importer.errors.join('; ')}" }.to_json
          end

          # If there are errors but some scenarios were created, still return error status
          # to indicate partial failure
          if importer.errors.any?
            status 422
            return {
              error: "Import completed with errors: #{importer.errors.join('; ')}",
              test_id: nil,
              scenarios_count: scenarios.size,
              errors: importer.errors,
              warnings: importer.warnings
            }.to_json
          end

          # Store scenarios with a unique ID
          test_id = SecureRandom.uuid
          self.class.batch_test_storage_mutex.synchronize do
            self.class.batch_test_storage[test_id] = {
              id: test_id,
              scenarios: scenarios,
              status: "imported",
              created_at: Time.now.utc.iso8601,
              results: nil,
              coverage: nil
            }
          end

          status 201
          {
            test_id: test_id,
            scenarios_count: scenarios.size,
            errors: importer.errors,
            warnings: importer.warnings
          }.to_json
        rescue DecisionAgent::ImportError => e
          status 422
          { error: e.message, errors: importer&.errors || [] }.to_json
        rescue StandardError => e
          status 500
          { error: "Failed to import file: #{e.message}" }.to_json
        end
      end

      # POST /api/testing/batch/run - Execute batch test
      post "/api/testing/batch/run" do
        content_type :json

        begin
          request_body = request.body.read
          data = request_body.empty? ? {} : JSON.parse(request_body)

          test_id = data["test_id"] || params[:test_id]
          rules_json = data["rules"]
          options = data["options"] || {}

          unless test_id
            status 400
            return { error: "test_id is required" }.to_json
          end

          unless rules_json
            status 400
            return { error: "rules JSON is required" }.to_json
          end

          # Get stored scenarios
          test_data = nil
          self.class.batch_test_storage_mutex.synchronize do
            test_data = self.class.batch_test_storage[test_id]
          end

          unless test_data
            status 404
            return { error: "Test not found" }.to_json
          end

          # Create agent from rules
          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules_json)
          agent = DecisionAgent::Agent.new(evaluators: [evaluator])

          # Update status
          self.class.batch_test_storage_mutex.synchronize do
            self.class.batch_test_storage[test_id][:status] = "running"
            self.class.batch_test_storage[test_id][:started_at] = Time.now.utc.iso8601
          end

          # Run batch test
          runner = DecisionAgent::Testing::BatchTestRunner.new(agent)
          results = runner.run(
            test_data[:scenarios],
            parallel: options.fetch("parallel", true),
            thread_count: options.fetch("thread_count", 4),
            checkpoint_file: options["checkpoint_file"]
          )

          # Calculate comparison if expected results exist
          comparison = nil
          if test_data[:scenarios].any?(&:expected_result?)
            comparator = DecisionAgent::Testing::TestResultComparator.new
            comparison = comparator.compare(results, test_data[:scenarios])
          end

          # Calculate coverage
          coverage_analyzer = DecisionAgent::Testing::TestCoverageAnalyzer.new
          coverage = coverage_analyzer.analyze(results, agent)

          # Store results
          self.class.batch_test_storage_mutex.synchronize do
            self.class.batch_test_storage[test_id][:status] = "completed"
            self.class.batch_test_storage[test_id][:results] = results.map(&:to_h)
            self.class.batch_test_storage[test_id][:comparison] = comparison
            self.class.batch_test_storage[test_id][:coverage] = coverage.to_h
            self.class.batch_test_storage[test_id][:statistics] = runner.statistics
            self.class.batch_test_storage[test_id][:completed_at] = Time.now.utc.iso8601
          end

          {
            test_id: test_id,
            status: "completed",
            results_count: results.size,
            statistics: runner.statistics,
            comparison: comparison,
            coverage: coverage.to_h
          }.to_json
        rescue StandardError => e
          # Update status to failed
          if test_id
            self.class.batch_test_storage_mutex.synchronize do
              if self.class.batch_test_storage[test_id]
                self.class.batch_test_storage[test_id][:status] = "failed"
                self.class.batch_test_storage[test_id][:error] = e.message
              end
            end
          end

          status 500
          { error: "Batch test execution failed: #{e.message}" }.to_json
        end
      end

      # GET /api/testing/batch/:id/results - Get batch test results
      get "/api/testing/batch/:id/results" do
        content_type :json

        begin
          test_id = params[:id]

          test_data = nil
          self.class.batch_test_storage_mutex.synchronize do
            test_data = self.class.batch_test_storage[test_id]
          end

          unless test_data
            status 404
            return { error: "Test not found" }.to_json
          end

          {
            test_id: test_data[:id],
            status: test_data[:status],
            created_at: test_data[:created_at],
            started_at: test_data[:started_at],
            completed_at: test_data[:completed_at],
            scenarios_count: test_data[:scenarios]&.size || 0,
            results: test_data[:results],
            comparison: test_data[:comparison],
            statistics: test_data[:statistics],
            error: test_data[:error]
          }.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # GET /api/testing/batch/:id/coverage - Get coverage report
      get "/api/testing/batch/:id/coverage" do
        content_type :json

        begin
          test_id = params[:id]

          test_data = nil
          self.class.batch_test_storage_mutex.synchronize do
            test_data = self.class.batch_test_storage[test_id]
          end

          unless test_data
            status 404
            return { error: "Test not found" }.to_json
          end

          unless test_data[:coverage]
            status 404
            return { error: "Coverage report not available. Run the batch test first." }.to_json
          end

          {
            test_id: test_data[:id],
            coverage: test_data[:coverage]
          }.to_json
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
        end
      end

      # GET /testing/batch - Batch testing UI page
      get "/testing/batch" do
        send_file File.join(settings.public_folder, "batch_testing.html")
      rescue StandardError
        status 404
        "Batch testing page not found"
      end

      # GET /auth/login - Login page
      get "/auth/login" do
        send_file File.join(settings.public_folder, "login.html")
      rescue StandardError
        status 404
        "Login page not found"
      end

      # GET /auth/users - User management page
      get "/auth/users" do
        send_file File.join(settings.public_folder, "users.html")
      rescue StandardError
        status 404
        "User management page not found"
      end

      private

      def version_manager
        @version_manager ||= DecisionAgent::Versioning::VersionManager.new
      end

      def extract_token
        # Check Authorization header: Bearer <token>
        auth_header = request.env["HTTP_AUTHORIZATION"]
        return auth_header[7..] if auth_header&.start_with?("Bearer ")

        # Check session cookie
        cookie_token = request.cookies["decision_agent_session"]
        return cookie_token if cookie_token

        # Check query parameter
        params["token"]
      end

      attr_reader :current_user

      def require_authentication!
        return if @current_user

        content_type :json
        halt 401, { error: "Authentication required" }.to_json
      end

      def require_permission!(permission, resource = nil)
        require_authentication!
        checker = self.class.permission_checker
        unless checker.can?(@current_user, permission, resource)
          begin
            self.class.access_audit_logger.log_permission_check(
              user_id: checker.user_id(@current_user),
              permission: permission,
              resource_type: resource&.class&.name,
              resource_id: resource&.id,
              granted: false
            )
          rescue StandardError
            # If logging fails, continue with permission denial
          ensure
            content_type :json
            halt 403, { error: "Permission denied: #{permission}" }.to_json
          end
        end

        begin
          self.class.access_audit_logger.log_permission_check(
            user_id: checker.user_id(@current_user),
            permission: permission,
            resource_type: resource&.class&.name,
            resource_id: resource&.id,
            granted: true
          )
        rescue StandardError
          # If logging fails, continue - permission was granted
        end
      end

      def parse_validation_errors(error_message)
        # Extract individual errors from the formatted error message
        errors = []

        # The error message is formatted with numbered errors
        lines = error_message.split("\n")

        lines.each do |line|
          # Match lines like "  1. Error message"
          if line.match?(/^\s*\d+\.\s+/)
            error = line.gsub(/^\s*\d+\.\s+/, "").strip
            errors << error unless error.empty?
          end
        end

        # If no errors were parsed, return the full message
        errors.empty? ? [error_message] : errors
      end

      # Class method to start the server (for CLI usage)
      def self.start!(port: 4567, host: "0.0.0.0")
        set :port, port
        set :bind, host
        run!
      end

      # Rack interface for mounting in Rails/Rack apps
      # Example:
      #   # config/routes.rb
      #   mount DecisionAgent::Web::Server, at: "/decision_agent"
      def self.call(env)
        new.call(env)
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
