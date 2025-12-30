module DecisionAgent
  module Auth
    class Permission
      PERMISSIONS = {
        read: "Read access to rules and versions",
        write: "Create and modify rules",
        delete: "Delete rules and versions",
        approve: "Approve rule changes",
        deploy: "Deploy rule versions",
        manage_users: "Manage users and roles",
        audit: "Access audit logs"
      }.freeze

      class << self
        def all
          PERMISSIONS.keys
        end

        def exists?(permission)
          PERMISSIONS.key?(permission.to_sym)
        end

        def description_for(permission)
          PERMISSIONS[permission.to_sym]
        end
      end
    end
  end
end
