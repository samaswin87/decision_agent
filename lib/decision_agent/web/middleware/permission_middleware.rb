require "rack"
require "json"

module DecisionAgent
  module Web
    module Middleware
      class PermissionMiddleware
        def initialize(app, permission_checker:, required_permission: nil, access_audit_logger: nil)
          @app = app
          @permission_checker = permission_checker
          @required_permission = required_permission
          @access_audit_logger = access_audit_logger
        end

        def call(env)
          user = env["decision_agent.user"]

          unless user
            return unauthorized_response("Authentication required")
          end

          # Check if user is active using the adapter
          unless @permission_checker.active?(user)
            return forbidden_response("User account is not active")
          end

          if @required_permission
            resource_type = extract_resource_type(env)
            resource_id = extract_resource_id(env)

            granted = @permission_checker.can?(user, @required_permission, nil)

            if @access_audit_logger
              user_id = @permission_checker.user_id(user)
              @access_audit_logger.log_permission_check(
                user_id: user_id,
                permission: @required_permission,
                resource_type: resource_type,
                resource_id: resource_id,
                granted: granted
              )
            end

            unless granted
              return forbidden_response("Permission denied: #{@required_permission}")
            end
          end

          @app.call(env)
        end

        private

        def extract_resource_type(env)
          request = Rack::Request.new(env)
          # Try to extract from path, e.g., /api/rules/:id -> "rule"
          path = request.path
          if path.match?(%r{/api/(\w+)})
            # Simple singularize: remove trailing 's'
            word = $1
            word&.end_with?("s") ? word[0..-2] : word
          end
        end

        def extract_resource_id(env)
          request = Rack::Request.new(env)
          request.params["id"] || request.params["rule_id"] || request.params["version_id"]
        end

        def unauthorized_response(message)
          [
            401,
            { "Content-Type" => "application/json" },
            [{ error: message }.to_json]
          ]
        end

        def forbidden_response(message)
          [
            403,
            { "Content-Type" => "application/json" },
            [{ error: message }.to_json]
          ]
        end
      end
    end
  end
end

