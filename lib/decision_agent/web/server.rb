# frozen_string_literal: true

require "rack"
require "rack/static"
require "rack/file"
require "json"
require "securerandom"
require "tempfile"
require_relative "rack_helpers"
require_relative "rack_request_helpers"

# Ensure testing classes are loaded
require_relative "../testing/test_scenario"
require_relative "../testing/batch_test_importer"
require_relative "../testing/batch_test_runner"
require_relative "../testing/test_result_comparator"
require_relative "../testing/test_coverage_analyzer"
require_relative "../evaluators/json_rule_evaluator"
require_relative "../agent"

# DMN components
require_relative "../dmn/importer"
require_relative "../dmn/exporter"
require_relative "dmn_editor"

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

# Simulation components
require_relative "../simulation/replay_engine"
require_relative "../simulation/what_if_analyzer"
require_relative "../simulation/impact_analyzer"
require_relative "../simulation/shadow_test_engine"
require_relative "../simulation/scenario_engine"
require_relative "../simulation/scenario_library"
require_relative "../versioning/version_manager"

module DecisionAgent
  module Web
    # rubocop:disable Metrics/ClassLength
    # Framework-agnostic Rack application - works with any Rack-compatible server
    class Server
      include RackHelpers
      include RackRequestHelpers

      PUBLIC_FOLDER = File.expand_path("public", __dir__)
      VIEWS_FOLDER = File.expand_path("views", __dir__)

      @public_folder = PUBLIC_FOLDER
      @views_folder = VIEWS_FOLDER
      @bind = "0.0.0.0"
      @port = 4567

      # In-memory storage for batch test runs
      @batch_test_storage = {}
      @batch_test_storage_mutex = Mutex.new

      # In-memory storage for simulation runs
      @simulation_storage = {}
      @simulation_storage_mutex = Mutex.new

      # Auth components
      @authenticator = nil
      @permission_checker = nil
      @access_audit_logger = nil
      @auth_mutex = Mutex.new

      # Router instance (initialized lazily)
      @router = nil

      class << self
        attr_accessor :public_folder, :views_folder, :bind, :port
        attr_reader :batch_test_storage, :batch_test_storage_mutex, :simulation_storage, :simulation_storage_mutex
        attr_writer :authenticator, :permission_checker, :access_audit_logger

        alias simulation_storage simulation_storage if method_defined?(:simulation_storage)
      end

      def self.authenticator
        return @authenticator if @authenticator

        @auth_mutex.synchronize do
          @authenticator ||= Auth::Authenticator.new
        end
      end

      def self.permission_checker
        return @permission_checker if @permission_checker

        @auth_mutex.synchronize do
          @permission_checker ||= Auth::PermissionChecker.new(adapter: DecisionAgent.rbac_config.adapter)
        end
      end

      def self.access_audit_logger
        return @access_audit_logger if @access_audit_logger

        @auth_mutex.synchronize do
          @access_audit_logger ||= Auth::AccessAuditLogger.new
        end
      end

      # Initialize router and define routes
      def self.router
        return @router if @router

        @router = Router.new

        # Enable CORS for API calls
        @router.before do |ctx|
          ctx.headers["Access-Control-Allow-Origin"] = "*"
          ctx.headers["Access-Control-Allow-Methods"] = "GET, POST, DELETE, OPTIONS, PUT"
          ctx.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        end

        # Auth middleware - extract user from token
        @router.before do |ctx|
          token = Server.extract_token_from_context(ctx)
          if token
            auth_result = Server.authenticator.authenticate(token)
            if auth_result
              ctx.current_user = auth_result[:user]
              ctx.current_session = auth_result[:session]
            end
          end
        end

        # Define all routes
        define_routes(@router)

        @router
      end

      # Rack call method - entry point for Rack requests
      def self.call(env)
        new.call(env)
      end

      def call(env)
        # Try to serve static files first
        path = env["PATH_INFO"] || "/"
        static_file = serve_static_file(path, env)
        return static_file if static_file

        # Route the request
        route_match = self.class.router.match(env)
        return [404, { "Content-Type" => "application/json" }, [{ error: "Not Found", path: path }.to_json]] unless route_match

        # Create request context with route params
        ctx = RequestContext.new(env, route_match[:params] || {})

        # Run before filters
        route_match[:before_filters].each do |filter|
          filter.call(ctx)
          return ctx.to_rack_response if ctx.halted?
        end

        # Execute route handler
        begin
          route_match[:handler].call(ctx)
          ctx.to_rack_response
        rescue StandardError => e
          [500, { "Content-Type" => "application/json" }, [{ error: e.message }.to_json]]
        end
      end

      private

      def serve_static_file(path, _env)
        # Serve static files from public folder
        static_paths = ["/styles.css", "/app.js", "/index.html", "/batch_testing.html", "/simulation.html", "/login.html", "/users.html",
                        "/dmn-editor.html"]
        static_extensions = [".css", ".js", ".html", ".svg", ".png", ".jpg", ".gif", ".json", ".xml", ".csv", ".xlsx"]

        return nil unless static_paths.include?(path) || static_extensions.any? { |ext| path.end_with?(ext) }

        # Remove leading slash for file path
        file_name = path.start_with?("/") ? path[1..] : path
        file_path = File.join(self.class.public_folder || PUBLIC_FOLDER, file_name)
        return nil unless File.exist?(file_path) && File.file?(file_path)

        ext = File.extname(file_path).downcase
        mime_types = {
          ".css" => "text/css",
          ".js" => "application/javascript",
          ".html" => "text/html",
          ".json" => "application/json",
          ".xml" => "application/xml",
          ".svg" => "image/svg+xml",
          ".png" => "image/png",
          ".jpg" => "image/jpeg",
          ".jpeg" => "image/jpeg",
          ".gif" => "image/gif",
          ".csv" => "text/csv",
          ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        }

        content_type = mime_types[ext] || "application/octet-stream"
        [200, { "Content-Type" => content_type }, [File.read(file_path)]]
      end

      def self.extract_token_from_context(ctx)
        # Check Authorization header: Bearer <token>
        auth_header = ctx.request.get_header("HTTP_AUTHORIZATION")
        return auth_header[7..] if auth_header&.start_with?("Bearer ")

        # Check session cookie
        cookie_token = ctx.cookies["decision_agent_session"]
        return cookie_token if cookie_token

        # Check query parameter
        ctx.params["token"] || ctx.params[:token]
      end

      # Helper methods for routes - work with RequestContext
      def self.extract_token(ctx)
        extract_token_from_context(ctx)
      end

      def self.require_authentication!(ctx)
        return if ctx.current_user

        ctx.content_type "application/json"
        ctx.halt(401, { error: "Authentication required" }.to_json)
      end

      def self.require_permission!(ctx, permission, resource = nil)
        # Skip all permission checks if disabled via environment variable
        return true if permissions_disabled?

        # Require authentication only if permissions are enabled
        require_authentication!(ctx)
        return if ctx.halted?

        checker = Server.permission_checker
        granted = checker.can?(ctx.current_user, permission, resource)

        unless granted
          # Log the permission denial
          begin
            user_id = checker.user_id(ctx.current_user)
            Server.access_audit_logger.log_permission_check(
              user_id: user_id,
              permission: permission,
              resource_type: resource&.class&.name,
              resource_id: resource&.id,
              granted: false
            )
          rescue StandardError
            # If logging fails, continue with permission denial
          end
          ctx.content_type "application/json"
          ctx.halt(403, { error: "Permission denied: #{permission}" }.to_json)
        end

        # Log successful permission check
        begin
          user_id = checker.user_id(ctx.current_user)
          Server.access_audit_logger.log_permission_check(
            user_id: user_id,
            permission: permission,
            resource_type: resource&.class&.name,
            resource_id: resource&.id,
            granted: true
          )
        rescue StandardError
          # If logging fails, continue - permission was granted
        end
      end

      def self.permissions_disabled?
        # Check explicit environment variable first
        disable_flag = ENV.fetch("DISABLE_WEBUI_PERMISSIONS", nil)
        if disable_flag
          normalized = disable_flag.to_s.strip.downcase
          return true if %w[true 1 yes].include?(normalized)
          return false if %w[false 0 no].include?(normalized)
        end

        # Auto-disable in development environments if not explicitly set
        env = ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
        env == "development"
      end

      def self.parse_validation_errors(error_message)
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

      def self.version_manager
        @version_manager ||= DecisionAgent::Versioning::VersionManager.new
      end

      def self.dmn_editor
        @dmn_editor ||= DecisionAgent::Web::DmnEditor.new
      end

      # Define all routes (will be populated below)
      def self.define_routes(router)
        # OPTIONS handler for CORS preflight
        router.options "*" do |ctx|
          ctx.status(200)
          ctx.body("")
        end

        # Main page - serve the rule builder UI
        router.get "/" do |ctx|
          html_file = File.join(Server.public_folder, "index.html")
          unless File.exist?(html_file)
            ctx.status(404)
            ctx.body("Index page not found")
            next
          end

          html_content = File.read(html_file, encoding: "UTF-8")

          # Determine the base path from the request
          base_path = ctx.script_name.empty? ? "./" : "#{ctx.script_name}/"

          # Inject or update base tag
          base_tag = "<base href=\"#{base_path}\">"
          html_content = if html_content.include?("<base")
                           html_content.sub(/<base[^>]*>/, base_tag)
                         else
                           html_content.sub("<head>", "<head>\n    #{base_tag}")
                         end

          ctx.content_type "text/html"
          ctx.body(html_content)
        rescue StandardError => e
          ctx.status(500)
          ctx.content_type "text/html"
          ctx.body("Error loading page: #{e.message}")
        end

        # Serve static assets explicitly
        router.get "/styles.css" do |ctx|
          ctx.content_type "text/css"
          css_file = File.join(Server.public_folder, "styles.css")
          ctx.send_file(css_file) if File.exist?(css_file)
        end

        router.get "/app.js" do |ctx|
          ctx.content_type "application/javascript"
          js_file = File.join(Server.public_folder, "app.js")
          ctx.send_file(js_file) if File.exist?(js_file)
        end

        # API: Validate rules
        router.post "/api/validate" do |ctx|
          ctx.content_type "application/json"

          begin
            # Parse request body
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            # Validate using DecisionAgent's SchemaValidator
            DecisionAgent::Dsl::SchemaValidator.validate!(data)

            # If validation passes
            ctx.json({
                       valid: true,
                       message: "Rules are valid!"
                     })
          rescue JSON::ParserError => e
            ctx.status(400)
            ctx.json({
                       valid: false,
                       errors: ["Invalid JSON: #{e.message}"]
                     })
          rescue DecisionAgent::InvalidRuleDslError => e
            # Validation failed
            ctx.status(422)
            ctx.json({
                       valid: false,
                       errors: Server.parse_validation_errors(e.message)
                     })
          rescue StandardError => e
            # Unexpected error
            ctx.status(500)
            ctx.json({
                       valid: false,
                       errors: ["Server error: #{e.message}"]
                     })
          end
        end

        # API: Test rule evaluation (optional feature)
        router.post "/api/evaluate" do |ctx|
          ctx.content_type "application/json"

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            rules_json = data["rules"]
            context = data["context"] || {}

            # Create evaluator
            evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules_json)

            # Evaluate
            result = evaluator.evaluate(DecisionAgent::Context.new(context))

            if result
              # Get explainability data from metadata if available
              explainability = result.metadata[:explainability] if result.metadata.is_a?(Hash)

              # Structure response as explainability by default
              # This makes explainability the primary format for decision results
              response = if explainability
                           {
                             success: true,
                             decision: explainability[:decision] || result.decision,
                             because: explainability[:because] || [],
                             failed_conditions: explainability[:failed_conditions] || [],
                             # Include additional metadata for completeness
                             confidence: result.weight,
                             reason: result.reason,
                             evaluator_name: result.evaluator_name,
                             # Full explainability data (includes rule_traces in verbose mode)
                             explainability: explainability
                           }
                         else
                           # Fallback if explainability is not available
                           {
                             success: true,
                             decision: result.decision,
                             because: [],
                             failed_conditions: [],
                             confidence: result.weight,
                             reason: result.reason,
                             evaluator_name: result.evaluator_name,
                             explainability: {
                               decision: result.decision,
                               because: [],
                               failed_conditions: []
                             }
                           }
                         end

              ctx.json(response)
            else
              ctx.json({
                         success: true,
                         decision: nil,
                         because: [],
                         failed_conditions: [],
                         message: "No rules matched the given context",
                         explainability: {
                           decision: nil,
                           because: [],
                           failed_conditions: []
                         }
                       })
            end
          rescue StandardError => e
            ctx.status(500)
            ctx.json({
                       success: false,
                       error: e.message
                     })
          end
        end

        # API: Get example rules
        router.get "/api/examples" do |ctx|
          ctx.content_type "application/json"

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

          ctx.json(examples)
        end

        # Health check
        router.get "/health" do |ctx|
          ctx.content_type "application/json"
          ctx.json({ status: "ok", version: DecisionAgent::VERSION })
        end

        # Authentication API endpoints

        # POST /api/auth/login - User login
        router.post "/api/auth/login" do |ctx|
          ctx.content_type "application/json"

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            email = data["email"]
            password = data["password"]

            unless email && password
              ctx.status(400)
              ctx.json({ error: "Email and password are required" })
              next
            end

            session = Server.authenticator.login(email, password)

            unless session
              Server.access_audit_logger.log_authentication(
                "login",
                user_id: nil,
                email: email,
                success: false,
                reason: "Invalid credentials"
              )
              ctx.status(401)
              ctx.json({ error: "Invalid email or password" })
              next
            end

            user = Server.authenticator.find_user(session.user_id)

            Server.access_audit_logger.log_authentication(
              "login",
              user_id: user.id,
              email: user.email,
              success: true
            )

            ctx.json({
                       token: session.token,
                       user: user.to_h,
                       expires_at: session.expires_at.iso8601
                     })
          rescue JSON::ParserError
            ctx.status(400)
            ctx.json({ error: "Invalid JSON" })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # POST /api/auth/logout - User logout
        router.post "/api/auth/logout" do |ctx|
          ctx.content_type "application/json"

          begin
            token = Server.extract_token(ctx)
            if token
              Server.authenticator.logout(token)
              if ctx.current_user
                checker = Server.permission_checker
                Server.access_audit_logger.log_authentication(
                  "logout",
                  user_id: checker.user_id(ctx.current_user),
                  email: checker.user_email(ctx.current_user),
                  success: true
                )
              end
            end

            ctx.json({ success: true, message: "Logged out successfully" })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # GET /api/auth/me - Current user info
        router.get "/api/auth/me" do |ctx|
          ctx.content_type "application/json"

          if ctx.current_user
            ctx.json(ctx.current_user.to_h)
          else
            ctx.status(401)
            ctx.json({ error: "Not authenticated" })
          end
        end

        # GET /api/auth/roles - List all roles
        router.get "/api/auth/roles" do |ctx|
          ctx.content_type "application/json"
          Server.require_permission!(ctx, :read)
          next if ctx.halted?

          roles = Auth::Role.all.map do |role|
            {
              id: role.to_s,
              name: Auth::Role.name_for(role),
              permissions: Auth::Role.permissions_for(role).map(&:to_s)
            }
          end

          ctx.json(roles)
        end

        # POST /api/auth/users - Create user (admin only)
        router.post "/api/auth/users" do |ctx|
          ctx.content_type "application/json"
          Server.require_permission!(ctx, :manage_users)
          next if ctx.halted?

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            email = data["email"]
            password = data["password"]
            roles = data["roles"] || []

            unless email && password
              ctx.status(400)
              ctx.json({ error: "Email and password are required" })
              next
            end

            # Validate roles
            invalid_role = nil
            roles.each do |role|
              unless Auth::Role.exists?(role)
                invalid_role = role
                break
              end
            end

            if invalid_role
              ctx.status(400)
              ctx.json({ error: "Invalid role: #{invalid_role}" })
              next
            end

            user = Server.authenticator.create_user(
              email: email,
              password: password,
              roles: roles
            )

            checker = Server.permission_checker
            Server.access_audit_logger.log_access(
              user_id: checker.user_id(ctx.current_user),
              action: "create_user",
              resource_type: "user",
              resource_id: user.id,
              success: true
            )

            ctx.status(201)
            ctx.json(user.to_h)
          rescue JSON::ParserError
            ctx.status(400)
            ctx.json({ error: "Invalid JSON" })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # GET /api/auth/users - List users (admin only)
        router.get "/api/auth/users" do |ctx|
          ctx.content_type "application/json"
          Server.require_permission!(ctx, :manage_users)
          next if ctx.halted?

          users = Server.authenticator.user_store.all.map(&:to_h)
          ctx.json(users)
        end

        # POST /api/auth/users/:id/roles - Assign role to user (admin only)
        router.post "/api/auth/users/:id/roles" do |ctx|
          ctx.content_type "application/json"
          Server.require_permission!(ctx, :manage_users)
          next if ctx.halted?

          begin
            user_id = ctx.params[:id] || ctx.params["id"]
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            role = data["role"]

            unless role
              ctx.status(400)
              ctx.json({ error: "Role is required" })
              next
            end

            unless Auth::Role.exists?(role)
              ctx.status(400)
              ctx.json({ error: "Invalid role: #{role}" })
              next
            end

            user = Server.authenticator.find_user(user_id)
            unless user
              ctx.status(404)
              ctx.json({ error: "User not found" })
              next
            end

            user.assign_role(role)

            checker = Server.permission_checker
            Server.access_audit_logger.log_access(
              user_id: checker.user_id(ctx.current_user),
              action: "assign_role",
              resource_type: "user",
              resource_id: user.id,
              success: true
            )

            ctx.json(user.to_h)
          rescue JSON::ParserError
            ctx.status(400)
            ctx.json({ error: "Invalid JSON" })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # DELETE /api/auth/users/:id/roles/:role - Remove role from user (admin only)
        router.delete "/api/auth/users/:id/roles/:role" do |ctx|
          ctx.content_type "application/json"
          Server.require_permission!(ctx, :manage_users)
          next if ctx.halted?

          begin
            user_id = ctx.params[:id] || ctx.params["id"]
            role = ctx.params[:role] || ctx.params["role"]

            user = Server.authenticator.find_user(user_id)
            unless user
              ctx.status(404)
              ctx.json({ error: "User not found" })
              next
            end

            user.remove_role(role)

            checker = Server.permission_checker
            Server.access_audit_logger.log_access(
              user_id: checker.user_id(ctx.current_user),
              action: "remove_role",
              resource_type: "user",
              resource_id: user.id,
              success: true
            )

            ctx.json(user.to_h)
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # GET /api/auth/audit - Query access audit logs
        router.get "/api/auth/audit" do |ctx|
          ctx.content_type "application/json"
          Server.require_permission!(ctx, :audit)
          next if ctx.halted?

          begin
            filters = {}

            filters[:user_id] = ctx.params[:user_id] || ctx.params["user_id"] if ctx.params[:user_id] || ctx.params["user_id"]
            filters[:event_type] = ctx.params[:event_type] || ctx.params["event_type"] if ctx.params[:event_type] || ctx.params["event_type"]
            filters[:start_time] = ctx.params[:start_time] || ctx.params["start_time"] if ctx.params[:start_time] || ctx.params["start_time"]
            filters[:end_time] = ctx.params[:end_time] || ctx.params["end_time"] if ctx.params[:end_time] || ctx.params["end_time"]
            filters[:limit] = (ctx.params[:limit] || ctx.params["limit"])&.to_i if ctx.params[:limit] || ctx.params["limit"]

            logs = Server.access_audit_logger.query(filters)
            ctx.json(logs)
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # POST /api/auth/password/reset-request - Request password reset
        router.post "/api/auth/password/reset-request" do |ctx|
          ctx.content_type "application/json"

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            email = data["email"]

            unless email
              ctx.status(400)
              ctx.json({ error: "Email is required" })
              next
            end

            token = Server.authenticator.request_password_reset(email)

            # For security, we always return success even if user doesn't exist
            # In production, you would send the token via email
            if token
              Server.access_audit_logger.log_authentication(
                "password_reset_request",
                user_id: token.user_id,
                email: email,
                success: true
              )

              ctx.json({
                         success: true,
                         message: "If the email exists, a password reset token has been generated",
                         # In production, remove this token from response and send via email
                         token: token.token,
                         expires_at: token.expires_at.iso8601
                       })
            else
              # Log failed attempt (but don't reveal if user exists)
              Server.access_audit_logger.log_authentication(
                "password_reset_request",
                user_id: nil,
                email: email,
                success: false,
                reason: "User not found or inactive"
              )

              ctx.json({
                         success: true,
                         message: "If the email exists, a password reset token has been generated"
                       })
            end
          rescue JSON::ParserError
            ctx.status(400)
            ctx.json({ error: "Invalid JSON" })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # POST /api/auth/password/reset - Reset password with token
        router.post "/api/auth/password/reset" do |ctx|
          ctx.content_type "application/json"

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            token = data["token"]
            new_password = data["password"]

            unless token && new_password
              ctx.status(400)
              ctx.json({ error: "Token and password are required" })
              next
            end

            unless new_password.length >= 8
              ctx.status(400)
              ctx.json({ error: "Password must be at least 8 characters long" })
              next
            end

            user = Server.authenticator.reset_password(token, new_password)

            unless user
              ctx.status(400)
              ctx.json({ error: "Invalid or expired reset token" })
              next
            end

            Server.access_audit_logger.log_authentication(
              "password_reset",
              user_id: user.id,
              email: user.email,
              success: true
            )

            ctx.json({
                       success: true,
                       message: "Password has been reset successfully"
                     })
          rescue JSON::ParserError
            ctx.status(400)
            ctx.json({ error: "Invalid JSON" })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # Versioning API endpoints

        # Create a new version
        router.post "/api/versions" do |ctx|
          ctx.content_type "application/json"
          Server.require_permission!(ctx, :write)
          next if ctx.halted?

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            rule_id = data["rule_id"]
            rule_content = data["content"]
            created_by = data["created_by"] || (ctx.current_user&.email || "system")
            changelog = data["changelog"]

            version = Server.version_manager.save_version(
              rule_id: rule_id,
              rule_content: rule_content,
              created_by: created_by,
              changelog: changelog
            )

            ctx.status(201)
            ctx.json(version)
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # List all versions for a rule
        router.get "/api/rules/:rule_id/versions" do |ctx|
          ctx.content_type "application/json"
          Server.require_permission!(ctx, :read)
          next if ctx.halted?

          begin
            rule_id = ctx.params[:rule_id] || ctx.params["rule_id"]
            limit = (ctx.params[:limit] || ctx.params["limit"])&.to_i

            versions = Server.version_manager.get_versions(rule_id: rule_id, limit: limit)

            ctx.json(versions)
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # Get version history with metadata
        router.get "/api/rules/:rule_id/history" do |ctx|
          ctx.content_type "application/json"
          Server.require_permission!(ctx, :read)
          next if ctx.halted?

          begin
            rule_id = ctx.params[:rule_id] || ctx.params["rule_id"]
            history = Server.version_manager.get_history(rule_id: rule_id)

            ctx.json(history)
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # Get a specific version
        router.get "/api/versions/:version_id" do |ctx|
          ctx.content_type "application/json"
          Server.require_permission!(ctx, :read)
          next if ctx.halted?

          begin
            version_id = ctx.params[:version_id] || ctx.params["version_id"]
            version = Server.version_manager.get_version(version_id: version_id)

            if version
              ctx.json(version)
            else
              ctx.status(404)
              ctx.json({ error: "Version not found" })
            end
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # Activate a version (rollback)
        router.post "/api/versions/:version_id/activate" do |ctx|
          ctx.content_type "application/json"
          Server.require_permission!(ctx, :deploy)
          next if ctx.halted?

          begin
            version_id = ctx.params[:version_id] || ctx.params["version_id"]
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = request_body.empty? ? {} : JSON.parse(request_body)
            performed_by = data["performed_by"] || (ctx.current_user&.email || "system")

            version = Server.version_manager.rollback(
              version_id: version_id,
              performed_by: performed_by
            )

            ctx.json(version)
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # Compare two versions
        router.get "/api/versions/:version_id_1/compare/:version_id_2" do |ctx|
          ctx.content_type "application/json"
          Server.require_permission!(ctx, :read)
          next if ctx.halted?

          begin
            version_id_1 = ctx.params[:version_id_1] || ctx.params["version_id_1"]
            version_id_2 = ctx.params[:version_id_2] || ctx.params["version_id_2"]

            comparison = Server.version_manager.compare(
              version_id_1: version_id_1,
              version_id_2: version_id_2
            )

            if comparison
              ctx.json(comparison)
            else
              ctx.status(404)
              ctx.json({ error: "One or both versions not found" })
            end
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # Delete a version
        router.delete "/api/versions/:version_id" do |ctx|
          ctx.content_type "application/json"

          begin
            Server.require_permission!(ctx, :delete)
            next if ctx.halted?

            version_id = ctx.params[:version_id] || ctx.params["version_id"]

            # Ensure version_id is present
            unless version_id
              ctx.status(400)
              ctx.json({ error: "Version ID is required" })
              next
            end

            result = Server.version_manager.delete_version(version_id: version_id)

            if result == false
              ctx.status(404)
              ctx.json({ error: "Version not found" })
            else
              ctx.status(200)
              ctx.json({ success: true, message: "Version deleted successfully" })
            end
          rescue DecisionAgent::NotFoundError => e
            ctx.status(404)
            ctx.json({ error: e.message })
          rescue DecisionAgent::ValidationError => e
            ctx.status(422)
            ctx.json({ error: e.message })
          rescue StandardError
            # Log the error for debugging but return a safe response
            ctx.status(500)
            ctx.json({ error: "Internal server error" })
          end
        end

        # Batch Testing API Endpoints

        # POST /api/testing/batch/import - Upload CSV/Excel file
        router.post "/api/testing/batch/import" do |ctx|
          ctx.content_type "application/json"

          begin
            # Handle file upload from multipart form data
            file_param = ctx.params[:file] || ctx.params["file"]

            unless file_param && (file_param[:tempfile] || file_param["tempfile"])
              ctx.status(400)
              ctx.json({ error: "No file uploaded" })
              next
            end

            uploaded_file = file_param[:tempfile] || file_param["tempfile"]
            filename = file_param[:filename] || file_param["filename"] || "uploaded_file"
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
              ctx.status(422)
              ctx.json({ error: "Import failed: #{importer.errors.join('; ')}" })
              next
            end

            # If there are errors but some scenarios were created, still return error status
            if importer.errors.any?
              ctx.status(422)
              ctx.json({
                         error: "Import completed with errors: #{importer.errors.join('; ')}",
                         test_id: nil,
                         scenarios_count: scenarios.size,
                         errors: importer.errors,
                         warnings: importer.warnings
                       })
              next
            end

            # Store scenarios with a unique ID
            test_id = SecureRandom.uuid
            Server.batch_test_storage_mutex.synchronize do
              Server.batch_test_storage[test_id] = {
                id: test_id,
                scenarios: scenarios,
                status: "imported",
                created_at: Time.now.utc.iso8601,
                results: nil,
                coverage: nil
              }
            end

            ctx.status(201)
            ctx.json({
                       test_id: test_id,
                       scenarios_count: scenarios.size,
                       errors: importer.errors,
                       warnings: importer.warnings
                     })
          rescue DecisionAgent::ImportError => e
            ctx.status(422)
            ctx.json({ error: e.message, errors: importer&.errors || [] })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: "Failed to import file: #{e.message}" })
          end
        end

        # POST /api/testing/batch/run - Execute batch test
        router.post "/api/testing/batch/run" do |ctx|
          ctx.content_type "application/json"

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = request_body.empty? ? {} : JSON.parse(request_body)

            test_id = data["test_id"] || (ctx.params[:test_id] || ctx.params["test_id"])
            rules_json = data["rules"]
            options = data["options"] || {}

            unless test_id
              ctx.status(400)
              ctx.json({ error: "test_id is required" })
              next
            end

            unless rules_json
              ctx.status(400)
              ctx.json({ error: "rules JSON is required" })
              next
            end

            # Get stored scenarios
            test_data = nil
            Server.batch_test_storage_mutex.synchronize do
              test_data = Server.batch_test_storage[test_id]
            end

            unless test_data
              ctx.status(404)
              ctx.json({ error: "Test not found" })
              next
            end

            # Create agent from rules
            evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules_json)
            agent = DecisionAgent::Agent.new(evaluators: [evaluator])

            # Update status
            Server.batch_test_storage_mutex.synchronize do
              Server.batch_test_storage[test_id][:status] = "running"
              Server.batch_test_storage[test_id][:started_at] = Time.now.utc.iso8601
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
            Server.batch_test_storage_mutex.synchronize do
              Server.batch_test_storage[test_id][:status] = "completed"
              Server.batch_test_storage[test_id][:results] = results.map(&:to_h)
              Server.batch_test_storage[test_id][:comparison] = comparison
              Server.batch_test_storage[test_id][:coverage] = coverage.to_h
              Server.batch_test_storage[test_id][:statistics] = runner.statistics
              Server.batch_test_storage[test_id][:completed_at] = Time.now.utc.iso8601
            end

            ctx.json({
                       test_id: test_id,
                       status: "completed",
                       results_count: results.size,
                       statistics: runner.statistics,
                       comparison: comparison,
                       coverage: coverage.to_h
                     })
          rescue StandardError => e
            # Update status to failed
            test_id_for_error = test_id || (data && data["test_id"])
            if test_id_for_error
              Server.batch_test_storage_mutex.synchronize do
                if Server.batch_test_storage[test_id_for_error]
                  Server.batch_test_storage[test_id_for_error][:status] = "failed"
                  Server.batch_test_storage[test_id_for_error][:error] = e.message
                end
              end
            end

            ctx.status(500)
            ctx.json({ error: "Batch test execution failed: #{e.message}" })
          end
        end

        # GET /api/testing/batch/:id/results - Get batch test results
        router.get "/api/testing/batch/:id/results" do |ctx|
          ctx.content_type "application/json"

          begin
            test_id = ctx.params[:id] || ctx.params["id"]

            test_data = nil
            Server.batch_test_storage_mutex.synchronize do
              test_data = Server.batch_test_storage[test_id]
            end

            unless test_data
              ctx.status(404)
              ctx.json({ error: "Test not found" })
              next
            end

            ctx.json({
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
                     })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # GET /api/testing/batch/:id/coverage - Get coverage report
        router.get "/api/testing/batch/:id/coverage" do |ctx|
          ctx.content_type "application/json"

          begin
            test_id = ctx.params[:id] || ctx.params["id"]

            test_data = nil
            Server.batch_test_storage_mutex.synchronize do
              test_data = Server.batch_test_storage[test_id]
            end

            unless test_data
              ctx.status(404)
              ctx.json({ error: "Test not found" })
              next
            end

            unless test_data[:coverage]
              ctx.status(404)
              ctx.json({ error: "Coverage report not available. Run the batch test first." })
              next
            end

            ctx.json({
                       test_id: test_data[:id],
                       coverage: test_data[:coverage]
                     })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # GET /testing/batch - Batch testing UI page
        router.get "/testing/batch" do |ctx|
          batch_file = File.join(Server.public_folder, "batch_testing.html")
          if File.exist?(batch_file)
            ctx.send_file(batch_file)
          else
            ctx.status(404)
            ctx.body("Batch testing page not found")
          end
        rescue StandardError => e
          ctx.status(404)
          ctx.body("Batch testing page not found: #{e.message}")
        end

        # Simulation API Endpoints

        # POST /api/simulation/replay - Historical replay/backtesting
        router.post "/api/simulation/replay" do |ctx|
          ctx.content_type "application/json"

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = request_body.empty? ? {} : JSON.parse(request_body)

            historical_data = data["historical_data"]
            rule_version = data["rule_version"]
            compare_with = data["compare_with"]
            options = data["options"] || {}

            unless historical_data
              ctx.status(400)
              ctx.json({ error: "historical_data is required" })
              next
            end

            # Get rules for agent creation
            rules_json = data["rules"]
            unless rules_json
              ctx.status(400)
              ctx.json({ error: "rules JSON is required" })
              next
            end

            # Create agent
            evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules_json)
            agent = DecisionAgent::Agent.new(evaluators: [evaluator])
            version_manager = DecisionAgent::Versioning::VersionManager.new

            # Create replay engine
            replay_engine = DecisionAgent::Simulation::ReplayEngine.new(
              agent: agent,
              version_manager: version_manager
            )

            # Convert historical data if it's a file path (for future file upload support)
            contexts = if historical_data.is_a?(Array)
                         historical_data
                       else
                         # Assume it's a file path - load it
                         raise ArgumentError, "File not found: #{historical_data}" unless File.exist?(historical_data)

                         if historical_data.end_with?(".json")
                           JSON.parse(File.read(historical_data))
                         elsif historical_data.end_with?(".csv")
                           # Simple CSV parsing
                           require "csv"
                           csv_data = CSV.read(historical_data, headers: true)
                           csv_data.map(&:to_h)
                         else
                           raise ArgumentError, "Unsupported file format"
                         end
                       end

            # Execute replay
            results = if compare_with
                        replay_engine.replay(
                          historical_data: contexts,
                          rule_version: rule_version,
                          compare_with: compare_with
                        )
                      else
                        replay_engine.replay(
                          historical_data: contexts,
                          rule_version: rule_version,
                          options: options
                        )
                      end

            # Store results
            replay_id = SecureRandom.uuid
            Server.simulation_storage_mutex.synchronize do
              Server.simulation_storage[replay_id] = {
                id: replay_id,
                type: "replay",
                status: "completed",
                created_at: Time.now.utc.iso8601,
                results: results
              }
            end

            ctx.json({
                       replay_id: replay_id,
                       results: results
                     })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: "Replay failed: #{e.message}" })
          end
        end

        # POST /api/simulation/whatif - What-if analysis
        router.post "/api/simulation/whatif" do |ctx|
          ctx.content_type "application/json"

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = request_body.empty? ? {} : JSON.parse(request_body)

            scenarios = data["scenarios"]
            rule_version = data["rule_version"]
            options = data["options"] || {}

            unless scenarios.is_a?(Array)
              ctx.status(400)
              ctx.json({ error: "scenarios array is required" })
              next
            end

            # Get rules for agent creation
            rules_json = data["rules"]
            unless rules_json
              ctx.status(400)
              ctx.json({ error: "rules JSON is required" })
              next
            end

            # Create agent
            evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules_json)
            agent = DecisionAgent::Agent.new(evaluators: [evaluator])
            version_mgr = Server.version_manager

            # Create what-if analyzer
            analyzer = DecisionAgent::Simulation::WhatIfAnalyzer.new(
              agent: agent,
              version_manager: version_mgr
            )

            # Execute analysis
            results = analyzer.analyze(
              scenarios: scenarios,
              rule_version: rule_version,
              options: options
            )

            # Store results
            analysis_id = SecureRandom.uuid
            Server.simulation_storage_mutex.synchronize do
              Server.simulation_storage[analysis_id] = {
                id: analysis_id,
                type: "whatif",
                status: "completed",
                created_at: Time.now.utc.iso8601,
                results: results
              }
            end

            ctx.json({
                       analysis_id: analysis_id,
                       results: results
                     })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: "What-if analysis failed: #{e.message}" })
          end
        end

        # POST /api/simulation/whatif/sensitivity - Sensitivity analysis
        router.post "/api/simulation/whatif/sensitivity" do |ctx|
          ctx.content_type "application/json"

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = request_body.empty? ? {} : JSON.parse(request_body)

            base_scenario = data["base_scenario"]
            variations = data["variations"]
            rule_version = data["rule_version"]

            unless base_scenario && variations
              ctx.status(400)
              ctx.json({ error: "base_scenario and variations are required" })
              next
            end

            # Get rules for agent creation
            rules_json = data["rules"]
            unless rules_json
              ctx.status(400)
              ctx.json({ error: "rules JSON is required" })
              next
            end

            # Create agent
            evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules_json)
            agent = DecisionAgent::Agent.new(evaluators: [evaluator])
            version_mgr = Server.version_manager

            # Create what-if analyzer
            analyzer = DecisionAgent::Simulation::WhatIfAnalyzer.new(
              agent: agent,
              version_manager: version_mgr
            )

            # Execute sensitivity analysis
            results = analyzer.sensitivity_analysis(
              base_scenario: base_scenario,
              variations: variations,
              rule_version: rule_version
            )

            ctx.json({ results: results })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: "Sensitivity analysis failed: #{e.message}" })
          end
        end

        # POST /api/simulation/impact - Impact analysis
        router.post "/api/simulation/impact" do |ctx|
          ctx.content_type "application/json"

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = request_body.empty? ? {} : JSON.parse(request_body)

            baseline_version = data["baseline_version"]
            proposed_version = data["proposed_version"]
            test_data = data["test_data"]
            options = data["options"] || {}

            unless baseline_version && proposed_version && test_data
              ctx.status(400)
              ctx.json({ error: "baseline_version, proposed_version, and test_data are required" })
              next
            end

            version_mgr = Server.version_manager

            # Create impact analyzer
            analyzer = DecisionAgent::Simulation::ImpactAnalyzer.new(
              version_manager: version_mgr
            )

            # Execute impact analysis
            results = analyzer.analyze(
              baseline_version: baseline_version,
              proposed_version: proposed_version,
              test_data: test_data,
              options: options
            )

            # Store results
            impact_id = SecureRandom.uuid
            Server.simulation_storage_mutex.synchronize do
              Server.simulation_storage[impact_id] = {
                id: impact_id,
                type: "impact",
                status: "completed",
                created_at: Time.now.utc.iso8601,
                results: results
              }
            end

            ctx.json({
                       impact_id: impact_id,
                       results: results
                     })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: "Impact analysis failed: #{e.message}" })
          end
        end

        # POST /api/simulation/shadow - Shadow testing
        router.post "/api/simulation/shadow" do |ctx|
          ctx.content_type "application/json"

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = request_body.empty? ? {} : JSON.parse(request_body)

            context = data["context"]
            shadow_version = data["shadow_version"]
            production_rules = data["production_rules"]
            shadow_rules = data["shadow_rules"]
            options = data["options"] || {}

            unless context
              ctx.status(400)
              ctx.json({ error: "context is required" })
              next
            end

            unless (production_rules && shadow_rules) || shadow_version
              ctx.status(400)
              ctx.json({ error: "Either (production_rules and shadow_rules) or shadow_version is required" })
              next
            end

            version_mgr = Server.version_manager

            # Create production agent
            if production_rules
              prod_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: production_rules)
              production_agent = DecisionAgent::Agent.new(evaluators: [prod_evaluator])
            else
              # Use active version
              active_version = version_mgr.get_active_version
              if active_version
                prod_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: active_version[:content])
                production_agent = DecisionAgent::Agent.new(evaluators: [prod_evaluator])
              else
                ctx.status(400)
                ctx.json({ error: "No active version found and production_rules not provided" })
                next
              end
            end

            # Create shadow test engine
            shadow_engine = DecisionAgent::Simulation::ShadowTestEngine.new(
              production_agent: production_agent,
              version_manager: version_mgr
            )

            # Execute shadow test
            if shadow_rules
              # Create a temporary version for shadow rules
              temp_version = {
                content: shadow_rules,
                rule_id: "shadow_temp",
                version_number: 1
              }
              result = shadow_engine.test(
                context: context,
                shadow_version: temp_version,
                options: options
              )
            else
              result = shadow_engine.test(
                context: context,
                shadow_version: shadow_version,
                options: options
              )
            end

            ctx.json({ result: result })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: "Shadow test failed: #{e.message}" })
          end
        end

        # POST /api/simulation/shadow/batch - Batch shadow testing
        router.post "/api/simulation/shadow/batch" do |ctx|
          ctx.content_type "application/json"

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = request_body.empty? ? {} : JSON.parse(request_body)

            contexts = data["contexts"]
            shadow_version = data["shadow_version"]
            production_rules = data["production_rules"]
            shadow_rules = data["shadow_rules"]
            options = data["options"] || {}

            unless contexts.is_a?(Array)
              ctx.status(400)
              ctx.json({ error: "contexts array is required" })
              next
            end

            unless (production_rules && shadow_rules) || shadow_version
              ctx.status(400)
              ctx.json({ error: "Either (production_rules and shadow_rules) or shadow_version is required" })
              next
            end

            version_mgr = Server.version_manager

            # Create production agent
            if production_rules
              prod_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: production_rules)
              production_agent = DecisionAgent::Agent.new(evaluators: [prod_evaluator])
            else
              # Use active version
              active_version = version_mgr.get_active_version
              if active_version
                prod_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: active_version[:content])
                production_agent = DecisionAgent::Agent.new(evaluators: [prod_evaluator])
              else
                ctx.status(400)
                ctx.json({ error: "No active version found and production_rules not provided" })
                next
              end
            end

            # Create shadow test engine
            shadow_engine = DecisionAgent::Simulation::ShadowTestEngine.new(
              production_agent: production_agent,
              version_manager: version_mgr
            )

            # Execute batch shadow test
            if shadow_rules
              # Create a temporary version for shadow rules
              temp_version = {
                content: shadow_rules,
                rule_id: "shadow_temp",
                version_number: 1
              }
              results = shadow_engine.batch_test(
                contexts: contexts,
                shadow_version: temp_version,
                options: options
              )
            else
              results = shadow_engine.batch_test(
                contexts: contexts,
                shadow_version: shadow_version,
                options: options
              )
            end

            ctx.json({ results: results })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: "Batch shadow test failed: #{e.message}" })
          end
        end

        # GET /api/simulation/:id - Get simulation results
        router.get "/api/simulation/:id" do |ctx|
          ctx.content_type "application/json"

          begin
            sim_id = ctx.params[:id] || ctx.params["id"]

            sim_data = nil
            Server.simulation_storage_mutex.synchronize do
              sim_data = Server.simulation_storage[sim_id]
            end

            unless sim_data
              ctx.status(404)
              ctx.json({ error: "Simulation not found" })
              next
            end

            ctx.json(sim_data)
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # GET /api/versions - List all versions (for simulation dropdowns)
        router.get "/api/versions" do |ctx|
          ctx.content_type "application/json"

          begin
            version_mgr = Server.version_manager
            versions = version_mgr.list_all_versions

            ctx.json({
                       versions: versions.map do |v|
                         {
                           id: v[:id] || v["id"],
                           rule_id: v[:rule_id] || v["rule_id"],
                           version_number: v[:version_number] || v["version_number"],
                           status: v[:status] || v["status"],
                           created_at: v[:created_at] || v["created_at"]
                         }
                       end
                     })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # GET /simulation - Simulation dashboard UI page
        router.get "/simulation" do |ctx|
          sim_file = File.join(Server.public_folder, "simulation.html")
          if File.exist?(sim_file)
            ctx.send_file(sim_file)
          else
            ctx.status(404)
            ctx.body("Simulation page not found")
          end
        rescue StandardError
          ctx.status(404)
          ctx.body("Simulation page not found")
        end

        # GET /simulation/replay - Historical replay UI page
        router.get "/simulation/replay" do |ctx|
          replay_file = File.join(Server.public_folder, "simulation_replay.html")
          if File.exist?(replay_file)
            ctx.send_file(replay_file)
          else
            ctx.status(404)
            ctx.body("Historical replay page not found")
          end
        rescue StandardError
          ctx.status(404)
          ctx.body("Historical replay page not found")
        end

        # GET /simulation/whatif - What-if analysis UI page
        router.get "/simulation/whatif" do |ctx|
          whatif_file = File.join(Server.public_folder, "simulation_whatif.html")
          if File.exist?(whatif_file)
            ctx.send_file(whatif_file)
          else
            ctx.status(404)
            ctx.body("What-if analysis page not found")
          end
        rescue StandardError
          ctx.status(404)
          ctx.body("What-if analysis page not found")
        end

        # GET /simulation/impact - Impact analysis UI page
        router.get "/simulation/impact" do |ctx|
          impact_file = File.join(Server.public_folder, "simulation_impact.html")
          if File.exist?(impact_file)
            ctx.send_file(impact_file)
          else
            ctx.status(404)
            ctx.body("Impact analysis page not found")
          end
        rescue StandardError
          ctx.status(404)
          ctx.body("Impact analysis page not found")
        end

        # GET /simulation/shadow - Shadow testing UI page
        router.get "/simulation/shadow" do |ctx|
          shadow_file = File.join(Server.public_folder, "simulation_shadow.html")
          if File.exist?(shadow_file)
            ctx.send_file(shadow_file)
          else
            ctx.status(404)
            ctx.body("Shadow testing page not found")
          end
        rescue StandardError
          ctx.status(404)
          ctx.body("Shadow testing page not found")
        end

        # GET /auth/login - Login page
        router.get "/auth/login" do |ctx|
          login_file = File.join(Server.public_folder, "login.html")
          if File.exist?(login_file)
            ctx.send_file(login_file)
          else
            ctx.status(404)
            ctx.body("Login page not found")
          end
        rescue StandardError
          ctx.status(404)
          ctx.body("Login page not found")
        end

        # GET /auth/users - User management page
        router.get "/auth/users" do |ctx|
          users_file = File.join(Server.public_folder, "users.html")
          if File.exist?(users_file)
            ctx.send_file(users_file)
          else
            ctx.status(404)
            ctx.body("User management page not found")
          end
        rescue StandardError
          ctx.status(404)
          ctx.body("User management page not found")
        end

        # DMN Editor Routes

        # GET /dmn/editor - DMN Editor UI page
        router.get "/dmn/editor" do |ctx|
          dmn_file = File.join(Server.public_folder, "dmn-editor.html")
          if File.exist?(dmn_file)
            ctx.send_file(dmn_file)
          else
            ctx.status(404)
            ctx.body("DMN Editor page not found")
          end
        rescue StandardError
          ctx.status(404)
          ctx.body("DMN Editor page not found")
        end

        # API: List all DMN models
        router.get "/api/dmn/models" do |ctx|
          ctx.content_type "application/json"
          ctx.json(Server.dmn_editor.list_models)
        end

        # API: Create new DMN model
        router.post "/api/dmn/models" do |ctx|
          ctx.content_type "application/json"

          begin
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            model = Server.dmn_editor.create_model(
              name: data["name"],
              namespace: data["namespace"]
            )

            ctx.status(201)
            ctx.json(model)
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # API: Get DMN model
        router.get "/api/dmn/models/:id" do |ctx|
          ctx.content_type "application/json"

          model_id = ctx.params[:id] || ctx.params["id"]
          model = Server.dmn_editor.get_model(model_id)
          if model
            ctx.json(model)
          else
            ctx.status(404)
            ctx.json({ error: "Model not found" })
          end
        end

        # API: Update DMN model
        router.put "/api/dmn/models/:id" do |ctx|
          ctx.content_type "application/json"

          begin
            model_id = ctx.params[:id] || ctx.params["id"]
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            model = Server.dmn_editor.update_model(
              model_id,
              name: data["name"],
              namespace: data["namespace"]
            )

            if model
              ctx.json(model)
            else
              ctx.status(404)
              ctx.json({ error: "Model not found" })
            end
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # API: Delete DMN model
        router.delete "/api/dmn/models/:id" do |ctx|
          ctx.content_type "application/json"

          model_id = ctx.params[:id] || ctx.params["id"]
          result = Server.dmn_editor.delete_model(model_id)
          ctx.json({ success: result })
        end

        # API: Add decision to model
        router.post "/api/dmn/models/:model_id/decisions" do |ctx|
          ctx.content_type "application/json"

          begin
            model_id = ctx.params[:model_id] || ctx.params["model_id"]
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            decision = Server.dmn_editor.add_decision(
              model_id: model_id,
              decision_id: data["decision_id"],
              name: data["name"],
              type: data["type"] || "decision_table"
            )

            if decision
              ctx.status(201)
              ctx.json(decision)
            else
              ctx.status(404)
              ctx.json({ error: "Model not found" })
            end
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # API: Update decision
        router.put "/api/dmn/models/:model_id/decisions/:decision_id" do |ctx|
          ctx.content_type "application/json"

          begin
            model_id = ctx.params[:model_id] || ctx.params["model_id"]
            decision_id = ctx.params[:decision_id] || ctx.params["decision_id"]
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            decision = Server.dmn_editor.update_decision(
              model_id: model_id,
              decision_id: decision_id,
              name: data["name"],
              logic: data["logic"]
            )

            if decision
              ctx.json(decision)
            else
              ctx.status(404)
              ctx.json({ error: "Decision not found" })
            end
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # API: Delete decision
        router.delete "/api/dmn/models/:model_id/decisions/:decision_id" do |ctx|
          ctx.content_type "application/json"

          model_id = ctx.params[:model_id] || ctx.params["model_id"]
          decision_id = ctx.params[:decision_id] || ctx.params["decision_id"]
          result = Server.dmn_editor.delete_decision(
            model_id: model_id,
            decision_id: decision_id
          )

          ctx.json({ success: result })
        end

        # API: Add input column
        router.post "/api/dmn/models/:model_id/decisions/:decision_id/inputs" do |ctx|
          ctx.content_type "application/json"

          begin
            model_id = ctx.params[:model_id] || ctx.params["model_id"]
            decision_id = ctx.params[:decision_id] || ctx.params["decision_id"]
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            input = Server.dmn_editor.add_input(
              model_id: model_id,
              decision_id: decision_id,
              input_id: data["input_id"],
              label: data["label"],
              type_ref: data["type_ref"],
              expression: data["expression"]
            )

            if input
              ctx.status(201)
              ctx.json(input)
            else
              ctx.status(404)
              ctx.json({ error: "Decision not found" })
            end
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # API: Add output column
        router.post "/api/dmn/models/:model_id/decisions/:decision_id/outputs" do |ctx|
          ctx.content_type "application/json"

          begin
            model_id = ctx.params[:model_id] || ctx.params["model_id"]
            decision_id = ctx.params[:decision_id] || ctx.params["decision_id"]
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            output = Server.dmn_editor.add_output(
              model_id: model_id,
              decision_id: decision_id,
              output_id: data["output_id"],
              label: data["label"],
              type_ref: data["type_ref"],
              name: data["name"]
            )

            if output
              ctx.status(201)
              ctx.json(output)
            else
              ctx.status(404)
              ctx.json({ error: "Decision not found" })
            end
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # API: Add rule
        router.post "/api/dmn/models/:model_id/decisions/:decision_id/rules" do |ctx|
          ctx.content_type "application/json"

          begin
            model_id = ctx.params[:model_id] || ctx.params["model_id"]
            decision_id = ctx.params[:decision_id] || ctx.params["decision_id"]
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            rule = Server.dmn_editor.add_rule(
              model_id: model_id,
              decision_id: decision_id,
              rule_id: data["rule_id"],
              input_entries: data["input_entries"],
              output_entries: data["output_entries"],
              description: data["description"]
            )

            if rule
              ctx.status(201)
              ctx.json(rule)
            else
              ctx.status(404)
              ctx.json({ error: "Decision not found" })
            end
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # API: Update rule
        router.put "/api/dmn/models/:model_id/decisions/:decision_id/rules/:rule_id" do |ctx|
          ctx.content_type "application/json"

          begin
            model_id = ctx.params[:model_id] || ctx.params["model_id"]
            decision_id = ctx.params[:decision_id] || ctx.params["decision_id"]
            rule_id = ctx.params[:rule_id] || ctx.params["rule_id"]
            request_body = RackRequestHelpers.read_body(ctx.env)
            data = JSON.parse(request_body)

            rule = Server.dmn_editor.update_rule(
              model_id: model_id,
              decision_id: decision_id,
              rule_id: rule_id,
              input_entries: data["input_entries"],
              output_entries: data["output_entries"],
              description: data["description"]
            )

            if rule
              ctx.json(rule)
            else
              ctx.status(404)
              ctx.json({ error: "Rule not found" })
            end
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: e.message })
          end
        end

        # API: Delete rule
        router.delete "/api/dmn/models/:model_id/decisions/:decision_id/rules/:rule_id" do |ctx|
          ctx.content_type "application/json"

          model_id = ctx.params[:model_id] || ctx.params["model_id"]
          decision_id = ctx.params[:decision_id] || ctx.params["decision_id"]
          rule_id = ctx.params[:rule_id] || ctx.params["rule_id"]
          result = Server.dmn_editor.delete_rule(
            model_id: model_id,
            decision_id: decision_id,
            rule_id: rule_id
          )

          ctx.json({ success: result })
        end

        # API: Validate DMN model
        router.get "/api/dmn/models/:id/validate" do |ctx|
          ctx.content_type "application/json"
          model_id = ctx.params[:id] || ctx.params["id"]
          ctx.json(Server.dmn_editor.validate_model(model_id))
        end

        # API: Export DMN model to XML
        router.get "/api/dmn/models/:id/export" do |ctx|
          ctx.content_type "application/xml"

          model_id = ctx.params[:id] || ctx.params["id"]
          xml = Server.dmn_editor.export_to_xml(model_id)
          if xml
            ctx.body(xml)
          else
            ctx.status(404)
            ctx.body("Model not found")
          end
        end

        # API: Visualize decision tree
        router.get "/api/dmn/models/:model_id/decisions/:decision_id/visualize/tree" do |ctx|
          model_id = ctx.params[:model_id] || ctx.params["model_id"]
          decision_id = ctx.params[:decision_id] || ctx.params["decision_id"]
          format = (ctx.params[:format] || ctx.params["format"]) || "svg"

          visualization = Server.dmn_editor.visualize_tree(
            model_id: model_id,
            decision_id: decision_id,
            format: format
          )

          if visualization
            ctx.content_type(format == "svg" ? "image/svg+xml" : "text/plain")
            ctx.body(visualization)
          else
            ctx.status(404)
            ctx.body("Decision not found or not a tree")
          end
        end

        # API: Visualize decision graph
        router.get "/api/dmn/models/:id/visualize/graph" do |ctx|
          model_id = ctx.params[:id] || ctx.params["id"]
          format = (ctx.params[:format] || ctx.params["format"]) || "svg"

          visualization = Server.dmn_editor.visualize_graph(
            model_id: model_id,
            format: format
          )

          if visualization
            ctx.content_type(format == "svg" ? "image/svg+xml" : "text/plain")
            ctx.body(visualization)
          else
            ctx.status(404)
            ctx.body("Model not found")
          end
        end

        # API: Import DMN file (uploads and imports to versioning system)
        router.post "/api/dmn/import" do |ctx|
          ctx.content_type "application/json"

          begin
            # Check if request has multipart form data (file upload)
            file_param = ctx.params[:file] || ctx.params["file"]
            content_type_header = ctx.request.content_type || ""

            if file_param && (file_param[:tempfile] || file_param["tempfile"])
              # File upload
              file = file_param[:tempfile] || file_param["tempfile"]
              xml_content = file.read
              filename = file_param[:filename] || file_param["filename"] || ""
              ruleset_name = (ctx.params[:ruleset_name] || ctx.params["ruleset_name"]) || filename.gsub(/\.dmn$/i, "")
              created_by = ctx.current_user ? ctx.current_user.id.to_s : (ctx.params[:created_by] || ctx.params["created_by"] || "system")
            elsif content_type_header.include?("application/json")
              # JSON body with XML content
              request_body = RackRequestHelpers.read_body(ctx.env)
              data = JSON.parse(request_body)
              xml_content = data["xml"] || data["content"]
              ruleset_name = data["ruleset_name"] || data["name"]
              created_by = ctx.current_user ? ctx.current_user.id.to_s : (data["created_by"] || "system")
            elsif content_type_header.include?("application/xml") || content_type_header.include?("text/xml")
              # Direct XML upload
              xml_content = RackRequestHelpers.read_body(ctx.env)
              ruleset_name = ctx.params[:ruleset_name] || ctx.params["ruleset_name"] || "imported_dmn"
              created_by = ctx.current_user ? ctx.current_user.id.to_s : (ctx.params[:created_by] || ctx.params["created_by"] || "system")
            else
              ctx.status(400)
              ctx.json({ error: "Invalid request. Expected file upload, JSON with 'xml' field, or XML content." })
              next
            end

            raise ArgumentError, "DMN XML content is required" if xml_content.nil? || xml_content.strip.empty?

            # Import using DMN Importer
            importer = Dmn::Importer.new(version_manager: Server.version_manager)
            result = importer.import_from_xml(
              xml_content,
              ruleset_name: ruleset_name,
              created_by: created_by
            )

            ctx.status(201)
            ctx.json({
                       success: true,
                       ruleset_name: ruleset_name,
                       decisions_imported: result[:decisions_imported],
                       model: {
                         id: result[:model].id,
                         name: result[:model].name,
                         namespace: result[:model].namespace,
                         decisions: result[:model].decisions.map do |d|
                           {
                             id: d.id,
                             name: d.name
                           }
                         end
                       },
                       versions: result[:versions].map do |v|
                         {
                           version: v[:version],
                           rule_id: v[:rule_id],
                           created_by: v[:created_by],
                           created_at: v[:created_at]
                         }
                       end
                     })
          rescue Dmn::InvalidDmnModelError, Dmn::DmnParseError => e
            ctx.status(400)
            ctx.json({ error: "DMN validation error", message: e.message })
          rescue StandardError => e
            ctx.status(500)
            ctx.json({ error: "Import failed", message: e.message })
          end
        end

        # API: Export ruleset as DMN XML
        router.get "/api/dmn/export/:ruleset_id" do |ctx|
          ctx.content_type "application/xml"

          begin
            ruleset_id = ctx.params[:ruleset_id] || ctx.params["ruleset_id"]
            exporter = Dmn::Exporter.new(version_manager: Server.version_manager)
            dmn_xml = exporter.export(ruleset_id)

            ctx.headers["Content-Disposition"] = "attachment; filename=\"#{ruleset_id}.dmn\""
            ctx.body(dmn_xml)
          rescue Dmn::InvalidDmnModelError => e
            ctx.status(404)
            ctx.content_type "application/json"
            ctx.json({ error: "Ruleset not found", message: e.message })
          rescue StandardError => e
            ctx.status(500)
            ctx.content_type "application/json"
            ctx.json({ error: "Export failed", message: e.message })
          end
        end
      end

      # Class method to start the server (for CLI usage)
      # Framework-agnostic: uses Rack::Server which supports any Rack-compatible server
      def self.start!(port: 4567, host: "0.0.0.0")
        @port = port
        @bind = host

        puts "🎯 DecisionAgent Web UI starting..."
        puts "📍 Server: http://#{host == '0.0.0.0' ? 'localhost' : host}:#{port}"
        puts "⚡️  Press Ctrl+C to stop"
        puts ""

        # Use Rack::Server which automatically selects the best available handler
        # Supports: Puma, WEBrick, Thin, Unicorn, etc. (any Rack-compatible server)
        Rack::Server.start(
          app: self,
          Port: port,
          Host: host,
          server: ENV.fetch("RACK_HANDLER", nil), # Allows override via ENV
          environment: ENV.fetch("RACK_ENV", "development")
        )
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
