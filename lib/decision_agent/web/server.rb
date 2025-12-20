require "sinatra/base"
require "json"

module DecisionAgent
  module Web
    class Server < Sinatra::Base
      set :public_folder, File.expand_path("public", __dir__)
      set :views, File.expand_path("views", __dir__)
      set :bind, "0.0.0.0"
      set :port, 4567

      # Enable CORS for API calls
      before do
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Access-Control-Allow-Methods"] = "GET, POST, DELETE, OPTIONS"
        headers["Access-Control-Allow-Headers"] = "Content-Type"
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

        rescue => e
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

        rescue => e
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
                  if: { field: "amount", op: "gte", value: 10000 },
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

      # Versioning API endpoints

      # Create a new version
      post "/api/versions" do
        content_type :json

        begin
          request_body = request.body.read
          data = JSON.parse(request_body)

          rule_id = data["rule_id"]
          rule_content = data["content"]
          created_by = data["created_by"] || "system"
          changelog = data["changelog"]

          version = version_manager.save_version(
            rule_id: rule_id,
            rule_content: rule_content,
            created_by: created_by,
            changelog: changelog
          )

          status 201
          version.to_json

        rescue => e
          status 500
          { error: e.message }.to_json
        end
      end

      # List all versions for a rule
      get "/api/rules/:rule_id/versions" do
        content_type :json

        begin
          rule_id = params[:rule_id]
          limit = params[:limit]&.to_i

          versions = version_manager.get_versions(rule_id: rule_id, limit: limit)

          versions.to_json

        rescue => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Get version history with metadata
      get "/api/rules/:rule_id/history" do
        content_type :json

        begin
          rule_id = params[:rule_id]
          history = version_manager.get_history(rule_id: rule_id)

          history.to_json

        rescue => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Get a specific version
      get "/api/versions/:version_id" do
        content_type :json

        begin
          version_id = params[:version_id]
          version = version_manager.get_version(version_id: version_id)

          if version
            version.to_json
          else
            status 404
            { error: "Version not found" }.to_json
          end

        rescue => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Activate a version (rollback)
      post "/api/versions/:version_id/activate" do
        content_type :json

        begin
          version_id = params[:version_id]
          request_body = request.body.read
          data = request_body.empty? ? {} : JSON.parse(request_body)
          performed_by = data["performed_by"] || "system"

          version = version_manager.rollback(
            version_id: version_id,
            performed_by: performed_by
          )

          version.to_json

        rescue => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Compare two versions
      get "/api/versions/:version_id_1/compare/:version_id_2" do
        content_type :json

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

        rescue => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Delete a version
      delete "/api/versions/:version_id" do
        content_type :json

        begin
          version_id = params[:version_id]

          version_manager.delete_version(version_id: version_id)

          status 200
          { success: true, message: "Version deleted successfully" }.to_json

        rescue DecisionAgent::NotFoundError => e
          status 404
          { error: e.message }.to_json

        rescue DecisionAgent::ValidationError => e
          status 422
          { error: e.message }.to_json

        rescue => e
          status 500
          { error: e.message }.to_json
        end
      end

      private

      def version_manager
        @version_manager ||= DecisionAgent::Versioning::VersionManager.new
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

      # Class method to start the server
      def self.start!(port: 4567, host: "0.0.0.0")
        set :port, port
        set :bind, host
        run!
      end
    end
  end
end
