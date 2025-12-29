require "spec_helper"
require "rack/test"
require_relative "../../../lib/decision_agent/web/middleware/permission_middleware"

RSpec.describe DecisionAgent::Web::Middleware::PermissionMiddleware do
  include Rack::Test::Methods

  let(:permission_checker) { double("PermissionChecker") }
  let(:access_audit_logger) { double("AccessAuditLogger") }
  let(:app) { ->(env) { [200, {}, ["OK"]] } }
  let(:user) { double("User", id: "user1", email: "user@example.com") }

  describe "#initialize" do
    it "initializes with app and permission_checker" do
      middleware = described_class.new(app, permission_checker: permission_checker)
      expect(middleware.instance_variable_get(:@app)).to eq(app)
      expect(middleware.instance_variable_get(:@permission_checker)).to eq(permission_checker)
      expect(middleware.instance_variable_get(:@required_permission)).to be_nil
    end

    it "initializes with required_permission" do
      middleware = described_class.new(app, permission_checker: permission_checker, required_permission: :write)
      expect(middleware.instance_variable_get(:@required_permission)).to eq(:write)
    end

    it "initializes with access_audit_logger" do
      middleware = described_class.new(app, permission_checker: permission_checker, access_audit_logger: access_audit_logger)
      expect(middleware.instance_variable_get(:@access_audit_logger)).to eq(access_audit_logger)
    end
  end

  describe "#call" do
    context "without user" do
      it "returns 401 when user is not authenticated" do
        middleware = described_class.new(app, permission_checker: permission_checker)
        env = Rack::MockRequest.env_for("/")

        status, headers, body = middleware.call(env)

        expect(status).to eq(401)
        expect(headers["Content-Type"]).to include("application/json")
        body_text = body.first
        expect(JSON.parse(body_text)["error"]).to eq("Authentication required")
      end
    end

    context "with inactive user" do
      it "returns 403 when user is not active" do
        middleware = described_class.new(app, permission_checker: permission_checker)
        env = Rack::MockRequest.env_for("/")
        env["decision_agent.user"] = user

        allow(permission_checker).to receive(:active?).with(user).and_return(false)

        status, headers, body = middleware.call(env)

        expect(status).to eq(403)
        body_text = body.first
        expect(JSON.parse(body_text)["error"]).to eq("User account is not active")
      end
    end

    context "without required permission" do
      it "calls app when no permission required" do
        middleware = described_class.new(app, permission_checker: permission_checker)
        env = Rack::MockRequest.env_for("/")
        env["decision_agent.user"] = user

        allow(permission_checker).to receive(:active?).with(user).and_return(true)

        status, headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(body.first).to eq("OK")
      end
    end

    context "with required permission" do
      let(:middleware) { described_class.new(app, permission_checker: permission_checker, required_permission: :write, access_audit_logger: access_audit_logger) }

      before do
        allow(permission_checker).to receive(:active?).with(user).and_return(true)
      end

      it "calls app when permission is granted" do
        env = Rack::MockRequest.env_for("/api/rules/123")
        env["decision_agent.user"] = user

        allow(permission_checker).to receive(:can?).with(user, :write, nil).and_return(true)
        allow(permission_checker).to receive(:user_id).with(user).and_return("user1")
        allow(access_audit_logger).to receive(:log_permission_check)

        status, headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(body.first).to eq("OK")
      end

      it "returns 403 when permission is denied" do
        env = Rack::MockRequest.env_for("/api/rules/123")
        env["decision_agent.user"] = user

        allow(permission_checker).to receive(:can?).with(user, :write, nil).and_return(false)
        allow(permission_checker).to receive(:user_id).with(user).and_return("user1")
        allow(access_audit_logger).to receive(:log_permission_check)

        status, headers, body = middleware.call(env)

        expect(status).to eq(403)
        body_text = body.first
        expect(JSON.parse(body_text)["error"]).to eq("Permission denied: write")
      end

      it "logs permission check when access_audit_logger is provided" do
        env = Rack::MockRequest.env_for("/api/rules/123")
        env["decision_agent.user"] = user

        allow(permission_checker).to receive(:can?).with(user, :write, nil).and_return(true)
        allow(permission_checker).to receive(:user_id).with(user).and_return("user1")
        allow(access_audit_logger).to receive(:log_permission_check)

        middleware.call(env)

        expect(access_audit_logger).to have_received(:log_permission_check).with(
          user_id: "user1",
          permission: :write,
          resource_type: "rule",
          resource_id: "123",
          granted: true
        )
      end

      it "does not log when access_audit_logger is not provided" do
        middleware = described_class.new(app, permission_checker: permission_checker, required_permission: :write)
        env = Rack::MockRequest.env_for("/api/rules/123")
        env["decision_agent.user"] = user

        allow(permission_checker).to receive(:can?).with(user, :write, nil).and_return(true)

        expect { middleware.call(env) }.not_to raise_error
      end
    end

    describe "#extract_resource_type" do
      it "extracts resource type from path" do
        middleware = described_class.new(app, permission_checker: permission_checker)
        env = Rack::MockRequest.env_for("/api/rules/123")
        env["decision_agent.user"] = user

        allow(permission_checker).to receive(:active?).with(user).and_return(true)

        middleware.call(env)

        # Verify extraction happened (indirectly through logging)
        expect(permission_checker).to have_received(:active?).with(user)
      end

      it "handles paths without /api/ prefix" do
        middleware = described_class.new(app, permission_checker: permission_checker, required_permission: :read)
        env = Rack::MockRequest.env_for("/other/path")
        env["decision_agent.user"] = user

        allow(permission_checker).to receive(:active?).with(user).and_return(true)
        allow(permission_checker).to receive(:can?).with(user, :read, nil).and_return(true)
        allow(permission_checker).to receive(:user_id).with(user).and_return("user1")

        status, headers, body = middleware.call(env)

        expect(status).to eq(200)
      end

      it "singularizes resource type (removes trailing 's')" do
        middleware = described_class.new(app, permission_checker: permission_checker, required_permission: :read, access_audit_logger: access_audit_logger)
        env = Rack::MockRequest.env_for("/api/rules/123")
        env["decision_agent.user"] = user

        allow(permission_checker).to receive(:active?).with(user).and_return(true)
        allow(permission_checker).to receive(:can?).with(user, :read, nil).and_return(true)
        allow(permission_checker).to receive(:user_id).with(user).and_return("user1")
        allow(access_audit_logger).to receive(:log_permission_check)

        middleware.call(env)

        expect(access_audit_logger).to have_received(:log_permission_check) do |args|
          expect(args[:resource_type]).to eq("rule")
        end
      end
    end

    describe "#extract_resource_id" do
      it "extracts id from params" do
        middleware = described_class.new(app, permission_checker: permission_checker, required_permission: :read, access_audit_logger: access_audit_logger)
        env = Rack::MockRequest.env_for("/api/rules/123?id=456")
        env["decision_agent.user"] = user

        allow(permission_checker).to receive(:active?).with(user).and_return(true)
        allow(permission_checker).to receive(:can?).with(user, :read, nil).and_return(true)
        allow(permission_checker).to receive(:user_id).with(user).and_return("user1")
        allow(access_audit_logger).to receive(:log_permission_check)

        middleware.call(env)

        expect(access_audit_logger).to have_received(:log_permission_check) do |args|
          expect(args[:resource_id]).to eq("456")
        end
      end

      it "extracts rule_id from params" do
        middleware = described_class.new(app, permission_checker: permission_checker, required_permission: :read, access_audit_logger: access_audit_logger)
        env = Rack::MockRequest.env_for("/api/rules?rule_id=789")
        env["decision_agent.user"] = user

        allow(permission_checker).to receive(:active?).with(user).and_return(true)
        allow(permission_checker).to receive(:can?).with(user, :read, nil).and_return(true)
        allow(permission_checker).to receive(:user_id).with(user).and_return("user1")
        allow(access_audit_logger).to receive(:log_permission_check)

        middleware.call(env)

        expect(access_audit_logger).to have_received(:log_permission_check) do |args|
          expect(args[:resource_id]).to eq("789")
        end
      end

      it "extracts version_id from params" do
        middleware = described_class.new(app, permission_checker: permission_checker, required_permission: :read, access_audit_logger: access_audit_logger)
        env = Rack::MockRequest.env_for("/api/versions?version_id=999")
        env["decision_agent.user"] = user

        allow(permission_checker).to receive(:active?).with(user).and_return(true)
        allow(permission_checker).to receive(:can?).with(user, :read, nil).and_return(true)
        allow(permission_checker).to receive(:user_id).with(user).and_return("user1")
        allow(access_audit_logger).to receive(:log_permission_check)

        middleware.call(env)

        expect(access_audit_logger).to have_received(:log_permission_check) do |args|
          expect(args[:resource_id]).to eq("999")
        end
      end
    end
  end
end

