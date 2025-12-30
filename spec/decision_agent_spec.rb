require "spec_helper"

RSpec.describe DecisionAgent do
  before do
    # Reset permission_checker between tests to avoid leakage
    DecisionAgent.permission_checker = nil
  end

  describe ".rbac_config" do
    it "returns the global RBAC configuration" do
      expect(DecisionAgent.rbac_config).to be_a(DecisionAgent::Auth::RbacConfig)
    end
  end

  describe ".configure_rbac" do
    context "with adapter_type and options" do
      it "configures RBAC with adapter type" do
        result = DecisionAgent.configure_rbac(:default)
        expect(result).to be_a(DecisionAgent::Auth::RbacConfig)
        expect(DecisionAgent.rbac_config.adapter).to be_a(DecisionAgent::Auth::RbacAdapter)
      end

      it "configures RBAC with custom options" do
        result = DecisionAgent.configure_rbac(:custom,
                                              can_proc: ->(_user, _permission, _resource) { true },
                                              has_role_proc: ->(_user, _role) { false },
                                              active_proc: ->(_user) { true })
        expect(result).to be_a(DecisionAgent::Auth::RbacConfig)
      end
    end

    context "with block" do
      it "yields the config block" do
        # Now test setting a custom adapter via block
        custom_adapter = DecisionAgent::Auth::DefaultAdapter.new
        result = DecisionAgent.configure_rbac do |config|
          config.adapter = custom_adapter
        end

        expect(result).to be_a(DecisionAgent::Auth::RbacConfig)
        expect(DecisionAgent.rbac_config.adapter).to eq(custom_adapter)
      end
    end

    context "with no arguments" do
      it "returns the rbac_config" do
        result = DecisionAgent.configure_rbac
        expect(result).to be_a(DecisionAgent::Auth::RbacConfig)
      end
    end
  end

  describe ".permission_checker" do
    it "returns a PermissionChecker instance" do
      checker = DecisionAgent.permission_checker
      expect(checker).to be_a(DecisionAgent::Auth::PermissionChecker)
    end

    it "creates a new PermissionChecker if not set" do
      # Reset permission_checker
      DecisionAgent.permission_checker = nil
      checker = DecisionAgent.permission_checker
      expect(checker).to be_a(DecisionAgent::Auth::PermissionChecker)
    end

    it "returns the same instance on subsequent calls" do
      checker1 = DecisionAgent.permission_checker
      checker2 = DecisionAgent.permission_checker
      expect(checker1).to eq(checker2)
    end

    it "uses the rbac_config adapter" do
      DecisionAgent.configure_rbac(:default)
      checker = DecisionAgent.permission_checker
      adapter = checker.instance_variable_get(:@adapter)
      expect(adapter).to be_a(DecisionAgent::Auth::RbacAdapter)
      expect(DecisionAgent.rbac_config.adapter).to be_a(DecisionAgent::Auth::RbacAdapter)
    end
  end

  describe ".permission_checker=" do
    it "sets a custom permission checker" do
      custom_checker = double("CustomChecker")
      DecisionAgent.permission_checker = custom_checker
      expect(DecisionAgent.permission_checker).to eq(custom_checker)
    end

    it "overrides the default permission checker" do
      original_checker = DecisionAgent.permission_checker
      custom_checker = double("CustomChecker")
      DecisionAgent.permission_checker = custom_checker
      expect(DecisionAgent.permission_checker).not_to eq(original_checker)
      expect(DecisionAgent.permission_checker).to eq(custom_checker)
    end
  end
end
