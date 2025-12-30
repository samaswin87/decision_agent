module DecisionAgent
  module Auth
    class SessionManager
      def initialize
        @sessions = {}
        @mutex = Mutex.new
        @cleanup_interval = 300 # 5 minutes
        @last_cleanup = Time.now
      end

      def create_session(user_id, expires_in: 3600)
        session = Session.new(user_id: user_id, expires_in: expires_in)
        @mutex.synchronize do
          @sessions[session.token] = session
          cleanup_expired_sessions
        end
        session
      end

      def get_session(token)
        @mutex.synchronize do
          session = @sessions[token]
          return nil unless session
          return nil if session.expired?

          session
        end
      end

      def delete_session(token)
        @mutex.synchronize do
          @sessions.delete(token)
        end
      end

      def delete_user_sessions(user_id)
        @mutex.synchronize do
          @sessions.delete_if { |_token, session| session.user_id == user_id }
        end
      end

      def cleanup_expired_sessions
        now = Time.now
        return if (now - @last_cleanup) < @cleanup_interval

        @sessions.delete_if { |_token, session| session.expired? }
        @last_cleanup = now
      end

      def count
        @mutex.synchronize do
          @sessions.size
        end
      end
    end
  end
end
