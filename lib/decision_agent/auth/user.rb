require "bcrypt"
require "securerandom"

module DecisionAgent
  module Auth
    class User
      attr_reader :id, :email, :roles, :created_at, :updated_at
      attr_accessor :active

      def initialize(email:, password: nil, password_hash: nil, roles: [], active: true, id: nil)
        @id = id || SecureRandom.uuid
        @email = email
        @roles = Array(roles)
        @active = active
        @created_at = Time.now.utc
        @updated_at = Time.now.utc

        if password_hash
          @password_hash = password_hash
        elsif password
          @password_hash = BCrypt::Password.create(password)
        else
          raise ArgumentError, "Either password or password_hash must be provided"
        end
      end

      def authenticate(password)
        return false unless @active

        BCrypt::Password.new(@password_hash) == password
      end

      def assign_role(role)
        role_symbol = role.to_sym
        @roles << role_symbol unless @roles.include?(role_symbol)
        @updated_at = Time.now.utc
      end

      def remove_role(role)
        role_symbol = role.to_sym
        @roles.delete(role_symbol)
        @updated_at = Time.now.utc
      end

      def has_role?(role)
        @roles.include?(role.to_sym)
      end

      def update_password(new_password)
        @password_hash = BCrypt::Password.create(new_password)
        @updated_at = Time.now.utc
      end

      def to_h
        {
          id: @id,
          email: @email,
          roles: @roles.map(&:to_s),
          active: @active,
          created_at: @created_at.iso8601,
          updated_at: @updated_at.iso8601
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end
    end
  end
end
