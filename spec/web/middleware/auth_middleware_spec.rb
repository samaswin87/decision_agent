require "spec_helper"
require "rack/test"
require_relative "../../../lib/decision_agent/web/middleware/auth_middleware"

RSpec.describe DecisionAgent::Web::Middleware::AuthMiddleware do
  include Rack::Test::Methods

  let(:authenticator) { double("Authenticator") }
  let(:access_audit_logger) { double("AccessAuditLogger") }
  let(:app) { ->(_env) { [200, {}, ["OK"]] } }
  let(:middleware) { described_class.new(app, authenticator: authenticator, access_audit_logger: access_audit_logger) }

  describe "#initialize" do
    it "initializes with app and authenticator" do
      expect(middleware.instance_variable_get(:@app)).to eq(app)
      expect(middleware.instance_variable_get(:@authenticator)).to eq(authenticator)
      expect(middleware.instance_variable_get(:@access_audit_logger)).to eq(access_audit_logger)
    end

    it "initializes without access_audit_logger" do
      middleware = described_class.new(app, authenticator: authenticator)
      expect(middleware.instance_variable_get(:@access_audit_logger)).to be_nil
    end
  end

  describe "#call" do
    context "with Authorization header" do
      it "extracts token from Bearer header" do
        user = double("User", id: "user1")
        session = double("Session", token: "token123")
        auth_result = { user: user, session: session }

        allow(authenticator).to receive(:authenticate).with("token123").and_return(auth_result)

        env = Rack::MockRequest.env_for("/", "HTTP_AUTHORIZATION" => "Bearer token123")
        status, = middleware.call(env)

        expect(status).to eq(200)
        expect(env["decision_agent.user"]).to eq(user)
        expect(env["decision_agent.session"]).to eq(session)
      end

      it "handles missing Bearer prefix" do
        env = Rack::MockRequest.env_for("/", "HTTP_AUTHORIZATION" => "token123")
        status, = middleware.call(env)

        expect(status).to eq(200)
        expect(env["decision_agent.user"]).to be_nil
      end
    end

    context "with session cookie" do
      it "extracts token from cookie" do
        user = double("User", id: "user1")
        session = double("Session", token: "cookie_token")
        auth_result = { user: user, session: session }

        allow(authenticator).to receive(:authenticate).with("cookie_token").and_return(auth_result)

        env = Rack::MockRequest.env_for("/")
        request = Rack::Request.new(env)
        allow(request).to receive(:cookies).and_return("decision_agent_session" => "cookie_token")
        allow(Rack::Request).to receive(:new).and_return(request)

        status, = middleware.call(env)

        expect(status).to eq(200)
        expect(env["decision_agent.user"]).to eq(user)
      end
    end

    context "with query parameter" do
      it "extracts token from query parameter" do
        user = double("User", id: "user1")
        session = double("Session", token: "query_token")
        auth_result = { user: user, session: session }

        allow(authenticator).to receive(:authenticate).with("query_token").and_return(auth_result)

        env = Rack::MockRequest.env_for("/?token=query_token")
        status, = middleware.call(env)

        expect(status).to eq(200)
        expect(env["decision_agent.user"]).to eq(user)
      end
    end

    context "without token" do
      it "calls app without setting user" do
        env = Rack::MockRequest.env_for("/")
        status, = middleware.call(env)

        expect(status).to eq(200)
        expect(env["decision_agent.user"]).to be_nil
        expect(env["decision_agent.session"]).to be_nil
      end
    end

    context "with invalid token" do
      it "calls app without setting user when authentication fails" do
        allow(authenticator).to receive(:authenticate).with("invalid_token").and_return(nil)

        env = Rack::MockRequest.env_for("/", "HTTP_AUTHORIZATION" => "Bearer invalid_token")
        status, = middleware.call(env)

        expect(status).to eq(200)
        expect(env["decision_agent.user"]).to be_nil
        expect(env["decision_agent.session"]).to be_nil
      end
    end

    context "token priority" do
      it "prefers Authorization header over cookie" do
        user_header = double("User", id: "header_user")
        user_cookie = double("User", id: "cookie_user")
        session_header = double("Session")
        session_cookie = double("Session")

        allow(authenticator).to receive(:authenticate).with("header_token").and_return({ user: user_header, session: session_header })
        allow(authenticator).to receive(:authenticate).with("cookie_token").and_return({ user: user_cookie, session: session_cookie })

        env = Rack::MockRequest.env_for("/?token=cookie_token", "HTTP_AUTHORIZATION" => "Bearer header_token")
        request = Rack::Request.new(env)
        allow(request).to receive(:cookies).and_return("decision_agent_session" => "cookie_token")
        allow(Rack::Request).to receive(:new).and_return(request)

        middleware.call(env)

        expect(env["decision_agent.user"]).to eq(user_header)
      end
    end
  end
end
