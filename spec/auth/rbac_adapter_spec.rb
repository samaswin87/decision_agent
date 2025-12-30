require "spec_helper"
require_relative "../../lib/decision_agent/auth/rbac_adapter"
require_relative "../../lib/decision_agent/auth/user"
require_relative "../../lib/decision_agent/auth/role"

RSpec.describe DecisionAgent::Auth::RbacAdapter do
  describe "base class" do
    let(:adapter) { described_class.new }
    let(:user) { double("User") }

    describe "#can?" do
      it "raises NotImplementedError" do
        expect { adapter.can?(user, :read) }.to raise_error(NotImplementedError, /must implement #can\?/)
      end
    end

    describe "#has_role?" do
      it "raises NotImplementedError" do
        expect { adapter.has_role?(user, :admin) }.to raise_error(NotImplementedError, /must implement #has_role\?/)
      end
    end

    describe "#active?" do
      it "returns false for nil user" do
        expect(adapter.active?(nil)).to be false
      end

      it "returns true for user with active? method returning true" do
        user = double("User", active?: true)
        expect(adapter.active?(user)).to be true
      end

      it "returns false for user with active? method returning false" do
        user = double("User", active?: false)
        expect(adapter.active?(user)).to be false
      end

      it "returns true for user without active? method" do
        user = double("User")
        expect(adapter.active?(user)).to be true
      end
    end

    describe "#user_id" do
      it "returns nil for nil user" do
        expect(adapter.user_id(nil)).to be_nil
      end

      it "returns user.id when user responds to id" do
        user = double("User", id: "user123")
        expect(adapter.user_id(user)).to eq("user123")
      end

      it "returns user.to_s when user doesn't respond to id" do
        user = double("User", to_s: "user_string")
        expect(adapter.user_id(user)).to eq("user_string")
      end
    end

    describe "#user_email" do
      it "returns nil for nil user" do
        expect(adapter.user_email(nil)).to be_nil
      end

      it "returns user.email when user responds to email" do
        user = double("User", email: "user@example.com")
        expect(adapter.user_email(user)).to eq("user@example.com")
      end

      it "returns nil when user doesn't respond to email" do
        user = double("User")
        expect(adapter.user_email(user)).to be_nil
      end
    end
  end

  describe DecisionAgent::Auth::DefaultAdapter do
    let(:adapter) { described_class.new }

    describe "#can?" do
      it "returns false for nil user" do
        expect(adapter.can?(nil, :read)).to be false
      end

      it "returns false for inactive user" do
        user = double("User", active: false, roles: [])
        expect(adapter.can?(user, :read)).to be false
      end

      it "returns true when user has role with permission" do
        user = DecisionAgent::Auth::User.new(
          id: "user1",
          email: "user@example.com",
          password: "password123"
        )
        user.assign_role(:admin)

        expect(adapter.can?(user, :read)).to be true
        expect(adapter.can?(user, :write)).to be true
        expect(adapter.can?(user, :manage_users)).to be true
      end

      it "returns false when user doesn't have role with permission" do
        user = DecisionAgent::Auth::User.new(
          id: "user1",
          email: "user@example.com",
          password: "password123"
        )
        user.assign_role(:guest)

        expect(adapter.can?(user, :manage_users)).to be false
      end

      it "returns true when user has multiple roles and one has permission" do
        user = DecisionAgent::Auth::User.new(
          id: "user1",
          email: "user@example.com",
          password: "password123"
        )
        user.assign_role(:guest)
        user.assign_role(:editor)

        expect(adapter.can?(user, :write)).to be true
      end
    end

    describe "#has_role?" do
      it "returns false for nil user" do
        expect(adapter.has_role?(nil, :admin)).to be false
      end

      it "returns true when user has role" do
        user = DecisionAgent::Auth::User.new(
          id: "user1",
          email: "user@example.com",
          password: "password123"
        )
        user.assign_role(:admin)

        expect(adapter.has_role?(user, :admin)).to be true
        expect(adapter.has_role?(user, :guest)).to be false
      end

      it "handles string role names" do
        user = DecisionAgent::Auth::User.new(
          id: "user1",
          email: "user@example.com",
          password: "password123"
        )
        user.assign_role(:admin)

        expect(adapter.has_role?(user, "admin")).to be true
      end
    end

    describe "#active?" do
      it "returns false for nil user" do
        expect(adapter.active?(nil)).to be false
      end

      it "returns user.active when user responds to active" do
        user = double("User", active: true)
        expect(adapter.active?(user)).to be true

        user = double("User", active: false)
        expect(adapter.active?(user)).to be false
      end

      it "returns true when user doesn't respond to active" do
        user = double("User")
        expect(adapter.active?(user)).to be true
      end
    end

    describe "#extract_roles" do
      it "extracts roles from user.roles" do
        user = double("User", roles: %i[admin editor])
        roles = adapter.send(:extract_roles, user)
        expect(roles).to eq(%i[admin editor])
      end

      it "extracts role from user.role (singular)" do
        user = double("User", role: :admin)
        roles = adapter.send(:extract_roles, user)
        expect(roles).to eq([:admin])
      end

      it "returns empty array when user has no roles" do
        user = double("User")
        roles = adapter.send(:extract_roles, user)
        expect(roles).to eq([])
      end

      it "handles array of roles" do
        user = double("User", roles: %w[admin editor])
        roles = adapter.send(:extract_roles, user)
        expect(roles).to eq(%i[admin editor])
      end
    end
  end

  describe DecisionAgent::Auth::DeviseCanCanAdapter do
    let(:adapter) { described_class.new }

    describe "#initialize" do
      it "initializes without ability_class" do
        adapter = described_class.new
        expect(adapter.instance_variable_get(:@ability_class)).to be_nil
      end

      it "initializes with ability_class" do
        ability_class = Class.new
        adapter = described_class.new(ability_class: ability_class)
        expect(adapter.instance_variable_get(:@ability_class)).to eq(ability_class)
      end
    end

    describe "#can?" do
      it "returns false for nil user" do
        expect(adapter.can?(nil, :read)).to be false
      end

      it "returns false for inactive user" do
        user = double("User", active_for_authentication?: false)
        expect(adapter.can?(user, :read)).to be false
      end

      it "uses user.can? when available" do
        user = double("User", active_for_authentication?: true)
        allow(user).to receive(:can?).with(:read, Object).and_return(true)

        expect(adapter.can?(user, :read)).to be true
        expect(user).to have_received(:can?).with(:read, Object)
      end

      it "uses ability_class when provided" do
        ability_instance = double("Ability", can?: true)
        ability_class = double("AbilityClass", new: ability_instance)
        adapter = described_class.new(ability_class: ability_class)
        user = double("User", active_for_authentication?: true)

        expect(adapter.can?(user, :read)).to be true
        expect(ability_class).to have_received(:new).with(user)
      end

      it "returns false when neither user.can? nor ability_class available" do
        user = double("User", active_for_authentication?: true)
        expect(adapter.can?(user, :read)).to be false
      end

      it "maps permissions to CanCanCan actions" do
        user = double("User", active_for_authentication?: true)
        allow(user).to receive(:can?).and_return(true)

        adapter.can?(user, :read)
        expect(user).to have_received(:can?).with(:read, Object)

        adapter.can?(user, :write)
        expect(user).to have_received(:can?).with(:create, Object)

        adapter.can?(user, :delete)
        expect(user).to have_received(:can?).with(:destroy, Object)
      end
    end

    describe "#has_role?" do
      it "returns false for nil user" do
        expect(adapter.has_role?(nil, :admin)).to be false
      end

      it "returns false for inactive user" do
        user = double("User", active_for_authentication?: false)
        expect(adapter.has_role?(user, :admin)).to be false
      end

      it "uses user.has_role? when available" do
        user = double("User", active_for_authentication?: true, has_role?: true)
        expect(adapter.has_role?(user, :admin)).to be true
      end

      it "checks user.roles when has_role? not available" do
        role = double("Role", name: :admin)
        user = double("User", active_for_authentication?: true, roles: [role])
        expect(adapter.has_role?(user, :admin)).to be true
      end

      it "returns false when no role methods available" do
        user = double("User", active_for_authentication?: true)
        expect(adapter.has_role?(user, :admin)).to be false
      end
    end

    describe "#active?" do
      it "uses active_for_authentication? when available" do
        user = double("User", active_for_authentication?: true)
        expect(adapter.active?(user)).to be true
      end

      it "falls back to active? when active_for_authentication? not available" do
        user = double("User", active?: true)
        expect(adapter.active?(user)).to be true
      end

      it "returns true when neither method available" do
        user = double("User")
        expect(adapter.active?(user)).to be true
      end
    end

    describe "#map_permission_to_action" do
      it "maps known permissions" do
        mapping = adapter.send(:map_permission_to_action, :read)
        expect(mapping).to eq(:read)

        mapping = adapter.send(:map_permission_to_action, :write)
        expect(mapping).to eq(:create)

        mapping = adapter.send(:map_permission_to_action, :delete)
        expect(mapping).to eq(:destroy)

        mapping = adapter.send(:map_permission_to_action, :manage_users)
        expect(mapping).to eq(:manage)
      end

      it "returns permission as-is for unknown permissions" do
        mapping = adapter.send(:map_permission_to_action, :custom_permission)
        expect(mapping).to eq(:custom_permission)
      end
    end
  end

  describe DecisionAgent::Auth::PunditAdapter do
    let(:adapter) { described_class.new }

    describe "#can?" do
      it "returns false for nil user" do
        expect(adapter.can?(nil, :read)).to be false
      end

      it "returns false for inactive user" do
        user = double("User", active?: false)
        expect(adapter.can?(user, :read)).to be false
      end

      it "returns false when no resource provided" do
        user = double("User", active?: true)
        expect(adapter.can?(user, :read)).to be false
      end

      it "uses resource.policy_class when available" do
        policy = double("Policy", show: true)
        policy_class = double("PolicyClass", new: policy)
        resource = double("Resource", policy_class: policy_class)
        user = double("User", active?: true)

        expect(adapter.can?(user, :read, resource)).to be true
        expect(policy_class).to have_received(:new).with(user, resource)
      end

      it "infers policy class from resource class name" do
        policy = double("Policy", show: true)
        policy_class = double("PolicyClass")
        allow(policy_class).to receive(:new).with(anything, anything).and_return(policy)
        allow(Object).to receive(:const_defined?).with("TestResourcePolicy").and_return(true)
        allow(Object).to receive(:const_get).with("TestResourcePolicy").and_return(policy_class)

        resource = double("TestResource", class: double(name: "TestResource"))
        user = double("User", active?: true)

        expect(adapter.can?(user, :read, resource)).to be true
      end

      it "returns false when policy class doesn't exist" do
        resource = double("TestResource", class: double(name: "TestResource"))
        user = double("User", active?: true)

        allow(Object).to receive(:const_defined?).with("TestResourcePolicy").and_return(false)

        expect(adapter.can?(user, :read, resource)).to be false
      end
    end

    describe "#has_role?" do
      it "returns false for nil user" do
        expect(adapter.has_role?(nil, :admin)).to be false
      end

      it "returns false for inactive user" do
        user = double("User", active?: false)
        expect(adapter.has_role?(user, :admin)).to be false
      end

      it "uses user.has_role? when available" do
        user = double("User", active?: true, has_role?: true)
        expect(adapter.has_role?(user, :admin)).to be true
      end

      it "checks user.roles when has_role? not available" do
        role = double("Role", name: :admin, to_s: "admin")
        user = double("User", active?: true, roles: [role])
        expect(adapter.has_role?(user, :admin)).to be true
      end
    end

    describe "#map_permission_to_action" do
      it "maps known permissions" do
        mapping = adapter.send(:map_permission_to_action, :read)
        expect(mapping).to eq(:show)

        mapping = adapter.send(:map_permission_to_action, :write)
        expect(mapping).to eq(:create)

        mapping = adapter.send(:map_permission_to_action, :delete)
        expect(mapping).to eq(:destroy)
      end
    end
  end

  describe DecisionAgent::Auth::CustomAdapter do
    describe "#initialize" do
      it "initializes with procs" do
        can_proc = ->(_u, _p, _r) { true }
        has_role_proc = ->(_u, _r) { true }
        active_proc = ->(_u) { true }
        user_id_proc = ->(_u) { "id" }
        user_email_proc = ->(_u) { "email" }

        adapter = described_class.new(
          can_proc: can_proc,
          has_role_proc: has_role_proc,
          active_proc: active_proc,
          user_id_proc: user_id_proc,
          user_email_proc: user_email_proc
        )

        expect(adapter.instance_variable_get(:@can_proc)).to eq(can_proc)
        expect(adapter.instance_variable_get(:@has_role_proc)).to eq(has_role_proc)
        expect(adapter.instance_variable_get(:@active_proc)).to eq(active_proc)
        expect(adapter.instance_variable_get(:@user_id_proc)).to eq(user_id_proc)
        expect(adapter.instance_variable_get(:@user_email_proc)).to eq(user_email_proc)
      end
    end

    describe "#can?" do
      it "returns false for nil user" do
        adapter = described_class.new(can_proc: ->(_u, _p, _r) { true })
        expect(adapter.can?(nil, :read)).to be false
      end

      it "returns false for inactive user" do
        adapter = described_class.new(
          can_proc: ->(_u, _p, _r) { true },
          active_proc: ->(_u) { false }
        )
        user = double("User")
        expect(adapter.can?(user, :read)).to be false
      end

      it "calls can_proc when provided" do
        can_proc = ->(_u, p, _r) { p == :read }
        adapter = described_class.new(can_proc: can_proc, active_proc: ->(_u) { true })
        user = double("User")

        expect(adapter.can?(user, :read)).to be true
        expect(adapter.can?(user, :write)).to be false
      end

      it "raises error when can_proc not provided" do
        adapter = described_class.new(active_proc: ->(_u) { true })
        user = double("User")

        expect { adapter.can?(user, :read) }.to raise_error(NotImplementedError, /requires can_proc/)
      end
    end

    describe "#has_role?" do
      it "returns false for nil user" do
        adapter = described_class.new(has_role_proc: ->(_u, _r) { true })
        expect(adapter.has_role?(nil, :admin)).to be false
      end

      it "calls has_role_proc when provided" do
        has_role_proc = ->(_u, r) { r == :admin }
        adapter = described_class.new(has_role_proc: has_role_proc)
        user = double("User")

        expect(adapter.has_role?(user, :admin)).to be true
        expect(adapter.has_role?(user, :guest)).to be false
      end

      it "raises error when has_role_proc not provided" do
        adapter = described_class.new
        user = double("User")

        expect { adapter.has_role?(user, :admin) }.to raise_error(NotImplementedError, /requires has_role_proc/)
      end
    end

    describe "#active?" do
      it "calls active_proc when provided" do
        active_proc = ->(u) { u == "active_user" }
        adapter = described_class.new(active_proc: active_proc)

        expect(adapter.active?("active_user")).to be true
        expect(adapter.active?("inactive_user")).to be false
      end

      it "falls back to super when active_proc not provided" do
        adapter = described_class.new
        user = double("User", active?: true)

        expect(adapter.active?(user)).to be true
      end
    end

    describe "#user_id" do
      it "calls user_id_proc when provided" do
        user_id_proc = ->(_u) { "custom_id" }
        adapter = described_class.new(user_id_proc: user_id_proc)
        user = double("User")

        expect(adapter.user_id(user)).to eq("custom_id")
      end

      it "falls back to super when user_id_proc not provided" do
        adapter = described_class.new
        user = double("User", id: "user123")

        expect(adapter.user_id(user)).to eq("user123")
      end
    end

    describe "#user_email" do
      it "calls user_email_proc when provided" do
        user_email_proc = ->(_u) { "custom@example.com" }
        adapter = described_class.new(user_email_proc: user_email_proc)
        user = double("User")

        expect(adapter.user_email(user)).to eq("custom@example.com")
      end

      it "falls back to super when user_email_proc not provided" do
        adapter = described_class.new
        user = double("User", email: "user@example.com")

        expect(adapter.user_email(user)).to eq("user@example.com")
      end
    end
  end
end
