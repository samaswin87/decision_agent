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

module DecisionAgent
  module Web
    class Server < Sinatra::Base
      set :public_folder, File.expand_path("public", __dir__)
      set :views, File.expand_path("views", __dir__)
      set :bind, "0.0.0.0"
      set :port, 4567

      # In-memory storage for batch test runs
      @@batch_test_storage = {}
      @@batch_test_storage_mutex = Mutex.new

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
        rescue StandardError => e
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
        rescue StandardError => e
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
        rescue StandardError => e
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
        rescue StandardError => e
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
        rescue StandardError => e
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
        rescue StandardError => e
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
        rescue StandardError => e
          status 500
          { error: e.message }.to_json
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

          # Store scenarios with a unique ID
          test_id = SecureRandom.uuid
          @@batch_test_storage_mutex.synchronize do
            @@batch_test_storage[test_id] = {
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
          @@batch_test_storage_mutex.synchronize do
            test_data = @@batch_test_storage[test_id]
          end

          unless test_data
            status 404
            return { error: "Test not found" }.to_json
          end

          # Create agent from rules
          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules_json)
          agent = DecisionAgent::Agent.new(evaluators: [evaluator])

          # Update status
          @@batch_test_storage_mutex.synchronize do
            @@batch_test_storage[test_id][:status] = "running"
            @@batch_test_storage[test_id][:started_at] = Time.now.utc.iso8601
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
          if test_data[:scenarios].any?(&:has_expected_result?)
            comparator = DecisionAgent::Testing::TestResultComparator.new
            comparison = comparator.compare(results, test_data[:scenarios])
          end

          # Calculate coverage
          coverage_analyzer = DecisionAgent::Testing::TestCoverageAnalyzer.new
          coverage = coverage_analyzer.analyze(results, agent)

          # Store results
          @@batch_test_storage_mutex.synchronize do
            @@batch_test_storage[test_id][:status] = "completed"
            @@batch_test_storage[test_id][:results] = results.map(&:to_h)
            @@batch_test_storage[test_id][:comparison] = comparison
            @@batch_test_storage[test_id][:coverage] = coverage.to_h
            @@batch_test_storage[test_id][:statistics] = runner.statistics
            @@batch_test_storage[test_id][:completed_at] = Time.now.utc.iso8601
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
            @@batch_test_storage_mutex.synchronize do
              if @@batch_test_storage[test_id]
                @@batch_test_storage[test_id][:status] = "failed"
                @@batch_test_storage[test_id][:error] = e.message
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
          @@batch_test_storage_mutex.synchronize do
            test_data = @@batch_test_storage[test_id]
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
          @@batch_test_storage_mutex.synchronize do
            test_data = @@batch_test_storage[test_id]
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
  end
end
