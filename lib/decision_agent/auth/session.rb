require "securerandom"

module DecisionAgent
  module Auth
    class Session
      attr_reader :token, :user_id, :created_at, :expires_at

      def initialize(user_id:, expires_in: 3600)
        @token = SecureRandom.hex(32)
        @user_id = user_id
        @created_at = Time.now.utc
        @expires_at = @created_at + expires_in
      end

      def expired?
        Time.now.utc > @expires_at
      end

      def valid?
        !expired?
      end

      def to_h
        {
          token: @token,
          user_id: @user_id,
          created_at: @created_at.iso8601,
          expires_at: @expires_at.iso8601
        }
      end
    end
  end
end
