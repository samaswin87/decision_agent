module DecisionAgent
  module Auth
    class PasswordResetManager
      def initialize
        @tokens = {}
        @mutex = Mutex.new
        @cleanup_interval = 300 # 5 minutes
        @last_cleanup = Time.now
      end

      def create_token(user_id, expires_in: 3600)
        token = PasswordResetToken.new(user_id: user_id, expires_in: expires_in)
        @mutex.synchronize do
          @tokens[token.token] = token
          cleanup_expired_tokens
        end
        token
      end

      def get_token(token_string)
        @mutex.synchronize do
          token = @tokens[token_string]
          return nil unless token
          return nil if token.expired?

          token
        end
      end

      def delete_token(token_string)
        @mutex.synchronize do
          @tokens.delete(token_string)
        end
      end

      def delete_user_tokens(user_id)
        @mutex.synchronize do
          @tokens.delete_if { |_token_string, token| token.user_id == user_id }
        end
      end

      def cleanup_expired_tokens
        now = Time.now
        return if (now - @last_cleanup) < @cleanup_interval

        @tokens.delete_if { |_token_string, token| token.expired? }
        @last_cleanup = now
      end

      def count
        @mutex.synchronize do
          @tokens.size
        end
      end
    end
  end
end
