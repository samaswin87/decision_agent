module DecisionAgent
  module Auth
    class Role
      ROLES = {
        admin: {
          name: "Admin",
          permissions: %i[read write delete approve deploy manage_users audit]
        },
        editor: {
          name: "Editor",
          permissions: %i[read write]
        },
        viewer: {
          name: "Viewer",
          permissions: [:read]
        },
        auditor: {
          name: "Auditor",
          permissions: %i[read audit]
        },
        approver: {
          name: "Approver",
          permissions: %i[read approve]
        }
      }.freeze

      class << self
        def all
          ROLES.keys
        end

        def exists?(role)
          ROLES.key?(role.to_sym)
        end

        def permissions_for(role)
          role_data = ROLES[role.to_sym]
          return [] unless role_data

          role_data[:permissions]
        end

        def name_for(role)
          role_data = ROLES[role.to_sym]
          return nil unless role_data

          role_data[:name]
        end

        def has_permission?(role, permission)
          permissions_for(role).include?(permission.to_sym)
        end
      end
    end
  end
end
