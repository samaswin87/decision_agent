require "rack"

module DecisionAgent
  module Web
    module Middleware
      class AuthMiddleware
        def initialize(app, authenticator:, access_audit_logger: nil)
          @app = app
          @authenticator = authenticator
          @access_audit_logger = access_audit_logger
        end

        def call(env)
          request = Rack::Request.new(env)
          token = extract_token(request)

          if token
            auth_result = @authenticator.authenticate(token)
            if auth_result
              env["decision_agent.user"] = auth_result[:user]
              env["decision_agent.session"] = auth_result[:session]
            end
          end

          @app.call(env)
        end

        private

        def extract_token(request)
          # Check Authorization header: Bearer <token>
          auth_header = request.get_header("HTTP_AUTHORIZATION")
          if auth_header && auth_header.start_with?("Bearer ")
            return auth_header[7..-1]
          end

          # Check session cookie
          cookie_token = request.cookies["decision_agent_session"]
          return cookie_token if cookie_token

          # Check query parameter (less secure, but useful for some cases)
          request.params["token"]
        end
      end
    end
  end
end

