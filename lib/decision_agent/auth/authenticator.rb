module DecisionAgent
  module Auth
    class Authenticator
      attr_reader :user_store, :session_manager, :password_reset_manager

      def initialize(user_store: nil, session_manager: nil, password_reset_manager: nil)
        @user_store = user_store || InMemoryUserStore.new
        @session_manager = session_manager || SessionManager.new
        @password_reset_manager = password_reset_manager || PasswordResetManager.new
      end

      def login(email, password)
        user = @user_store.find_by_email(email)
        return nil unless user
        return nil unless user.active
        return nil unless user.authenticate(password)

        @session_manager.create_session(user.id)
      end

      def logout(token)
        @session_manager.delete_session(token)
      end

      def authenticate(token)
        session = @session_manager.get_session(token)
        return nil unless session

        user = @user_store.find_by_id(session.user_id)
        return nil unless user
        return nil unless user.active

        { user: user, session: session }
      end

      def create_user(email:, password:, roles: [])
        user = User.new(email: email, password: password, roles: roles)
        @user_store.save(user)
        user
      end

      def find_user(user_id)
        @user_store.find_by_id(user_id)
      end

      def find_user_by_email(email)
        @user_store.find_by_email(email)
      end

      def request_password_reset(email)
        user = @user_store.find_by_email(email)
        return nil unless user
        return nil unless user.active

        # Delete any existing reset tokens for this user
        @password_reset_manager.delete_user_tokens(user.id)

        # Create a new reset token (expires in 1 hour)
        @password_reset_manager.create_token(user.id, expires_in: 3600)
      end

      def reset_password(token_string, new_password)
        token = @password_reset_manager.get_token(token_string)
        return nil unless token

        user = @user_store.find_by_id(token.user_id)
        return nil unless user
        return nil unless user.active

        # Update the password
        user.update_password(new_password)
        @user_store.save(user)

        # Delete the used token and all other tokens for this user
        @password_reset_manager.delete_user_tokens(user.id)

        # Invalidate all existing sessions for security
        @session_manager.delete_user_sessions(user.id)

        user
      end
    end

    # In-memory user store (can be replaced with ActiveRecord adapter later)
    class InMemoryUserStore
      def initialize
        @users = {}
        @users_by_email = {}
        @mutex = Mutex.new
      end

      def save(user)
        @mutex.synchronize do
          @users[user.id] = user
          @users_by_email[user.email.downcase] = user
        end
        user
      end

      def find_by_id(id)
        @mutex.synchronize do
          @users[id]
        end
      end

      def find_by_email(email)
        @mutex.synchronize do
          @users_by_email[email.downcase]
        end
      end

      def all
        @mutex.synchronize do
          @users.values.dup
        end
      end

      def delete(id)
        @mutex.synchronize do
          user = @users.delete(id)
          @users_by_email.delete(user.email.downcase) if user
          user
        end
      end
    end
  end
end
