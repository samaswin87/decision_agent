module DecisionAgent
  module Auth
    # Base adapter interface for RBAC integration
    # Users can extend this to integrate with any authentication/authorization system
    class RbacAdapter
      # Check if a user has a specific permission
      # @param user [Object] The user object from your auth system
      # @param permission [Symbol, String] The permission to check
      # @param resource [Object, nil] Optional resource for resource-level permissions
      # @return [Boolean] true if user has permission, false otherwise
      def can?(user, permission, resource = nil)
        raise NotImplementedError, "Subclasses must implement #can?"
      end

      # Check if a user has a specific role
      # @param user [Object] The user object from your auth system
      # @param role [Symbol, String] The role to check
      # @return [Boolean] true if user has role, false otherwise
      def has_role?(user, role)
        raise NotImplementedError, "Subclasses must implement #has_role?"
      end

      # Check if a user is active/enabled
      # @param user [Object] The user object from your auth system
      # @return [Boolean] true if user is active, false otherwise
      def active?(user)
        return false unless user

        # Default implementation - can be overridden
        user.respond_to?(:active?) ? user.active? : true
      end

      # Get user ID for audit/logging purposes
      # @param user [Object] The user object from your auth system
      # @return [String, Integer] User identifier
      def user_id(user)
        return nil unless user

        user.respond_to?(:id) ? user.id : user.to_s
      end

      # Get user email for display/logging purposes
      # @param user [Object] The user object from your auth system
      # @return [String, nil] User email
      def user_email(user)
        return nil unless user

        user.respond_to?(:email) ? user.email : nil
      end
    end

    # Default adapter using the built-in User/Role/Permission system
    class DefaultAdapter < RbacAdapter
      def can?(user, permission, _resource = nil)
        return false unless user
        return false unless active?(user)

        # Check if user has any role with the required permission
        roles = extract_roles(user)
        roles.any? do |role|
          Role.has_permission?(role, permission)
        end
      end

      def has_role?(user, role)
        return false unless user

        roles = extract_roles(user)
        roles.include?(role.to_sym)
      end

      def active?(user)
        return false unless user

        user.respond_to?(:active) ? user.active : true
      end

      private

      def extract_roles(user)
        if user.respond_to?(:roles)
          Array(user.roles).map(&:to_sym)
        elsif user.respond_to?(:role)
          [user.role.to_sym]
        else
          []
        end
      end
    end

    # Adapter for Devise + CanCanCan integration
    class DeviseCanCanAdapter < RbacAdapter
      def initialize(ability_class: nil)
        super()
        @ability_class = ability_class
      end

      def can?(user, permission, resource = nil)
        return false unless user
        return false unless active?(user)

        # CanCanCan uses :can? method with action and resource
        if user.respond_to?(:can?)
          # Map permission to CanCanCan action
          action = map_permission_to_action(permission)
          user.can?(action, resource || Object)
        elsif @ability_class
          # Use Ability class if provided
          ability = @ability_class.new(user)
          action = map_permission_to_action(permission)
          ability.can?(action, resource || Object)
        else
          false
        end
      end

      def has_role?(user, role)
        return false unless user
        return false unless active?(user)

        # Check if user has role via CanCanCan roles or other methods
        if user.respond_to?(:has_role?)
          user.has_role?(role)
        elsif user.respond_to?(:roles)
          user.roles.any? { |r| r.to_s == role.to_s || r.name.to_s == role.to_s }
        else
          false
        end
      end

      def active?(user)
        return false unless user

        # Devise typically uses active_for_authentication? or active?
        if user.respond_to?(:active_for_authentication?)
          user.active_for_authentication?
        elsif user.respond_to?(:active?)
          user.active?
        else
          true
        end
      end

      private

      def map_permission_to_action(permission)
        # Map decision_agent permissions to CanCanCan actions
        mapping = {
          read: :read,
          write: :create,
          delete: :destroy,
          approve: :approve,
          deploy: :deploy,
          manage_users: :manage,
          audit: :read
        }
        mapping[permission.to_sym] || permission.to_sym
      end
    end

    # Adapter for Pundit authorization
    class PunditAdapter < RbacAdapter
      def can?(user, permission, resource = nil)
        return false unless user
        return false unless active?(user)

        # Pundit uses policy classes
        if resource.respond_to?(:policy_class)
          policy = resource.policy_class.new(user, resource)
          action = map_permission_to_action(permission)
          policy.respond_to?(action) && policy.public_send(action)
        elsif resource
          # Try to infer policy class from resource
          policy_class_name = "#{resource.class.name}Policy"
          if Object.const_defined?(policy_class_name)
            policy_class = Object.const_get(policy_class_name)
            policy = policy_class.new(user, resource)
            action = map_permission_to_action(permission)
            policy.respond_to?(action) && policy.public_send(action)
          else
            false
          end
        else
          false
        end
      end

      def has_role?(user, role)
        return false unless user
        return false unless active?(user)

        if user.respond_to?(:has_role?)
          user.has_role?(role)
        elsif user.respond_to?(:roles)
          user.roles.any? { |r| r.to_s == role.to_s || r.name.to_s == role.to_s }
        else
          false
        end
      end

      private

      def map_permission_to_action(permission)
        mapping = {
          read: :show,
          write: :create,
          delete: :destroy,
          approve: :approve,
          deploy: :deploy,
          manage_users: :manage,
          audit: :audit
        }
        mapping[permission.to_sym] || permission.to_sym
      end
    end

    # Custom adapter that allows users to provide their own logic via blocks/procs
    class CustomAdapter < RbacAdapter
      def initialize(
        can_proc: nil,
        has_role_proc: nil,
        active_proc: nil,
        user_id_proc: nil,
        user_email_proc: nil
      )
        super()
        @can_proc = can_proc
        @has_role_proc = has_role_proc
        @active_proc = active_proc
        @user_id_proc = user_id_proc
        @user_email_proc = user_email_proc
      end

      def can?(user, permission, resource = nil)
        return false unless user
        return false unless active?(user)

        raise NotImplementedError, "CustomAdapter requires can_proc to be provided" unless @can_proc

        @can_proc.call(user, permission, resource)
      end

      def has_role?(user, role)
        return false unless user

        raise NotImplementedError, "CustomAdapter requires has_role_proc to be provided" unless @has_role_proc

        @has_role_proc.call(user, role)
      end

      def active?(user)
        return false unless user

        if @active_proc
          @active_proc.call(user)
        else
          super
        end
      end

      def user_id(user)
        if @user_id_proc
          @user_id_proc.call(user)
        else
          super
        end
      end

      def user_email(user)
        if @user_email_proc
          @user_email_proc.call(user)
        else
          super
        end
      end
    end
  end
end
