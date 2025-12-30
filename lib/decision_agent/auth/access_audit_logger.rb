require "json"
require_relative "../audit/adapter"

module DecisionAgent
  module Auth
    class AccessAuditLogger
      attr_reader :adapter

      def initialize(adapter: nil)
        @adapter = adapter || Audit::InMemoryAccessAdapter.new
      end

      def log_authentication(event_type, user_id:, email: nil, success: true, reason: nil)
        log_entry = {
          event_type: event_type.to_s,
          user_id: user_id,
          email: email,
          success: success,
          reason: reason,
          timestamp: Time.now.utc.iso8601,
          ip_address: nil # Can be set by middleware
        }

        @adapter.record_access(log_entry)
      end

      def log_permission_check(user_id:, permission:, resource_type: nil, resource_id: nil, granted: true)
        log_entry = {
          event_type: "permission_check",
          user_id: user_id,
          permission: permission.to_s,
          resource_type: resource_type,
          resource_id: resource_id,
          granted: granted,
          timestamp: Time.now.utc.iso8601
        }

        @adapter.record_access(log_entry)
      end

      def log_access(user_id:, action:, resource_type: nil, resource_id: nil, success: true)
        log_entry = {
          event_type: "access",
          user_id: user_id,
          action: action.to_s,
          resource_type: resource_type,
          resource_id: resource_id,
          success: success,
          timestamp: Time.now.utc.iso8601
        }

        @adapter.record_access(log_entry)
      end

      def query(filters = {})
        @adapter.query_access_logs(filters)
      end
    end
  end

  module Audit
    class AccessAdapter < Adapter
      def record_access(log_entry)
        raise NotImplementedError, "Subclasses must implement #record_access"
      end

      def query_access_logs(filters = {})
        raise NotImplementedError, "Subclasses must implement #query_access_logs"
      end
    end

    class InMemoryAccessAdapter < AccessAdapter
      def initialize
        super
        @logs = []
        @mutex = Mutex.new
      end

      def record_access(log_entry)
        @mutex.synchronize do
          @logs << log_entry.dup
        end
      end

      def query_access_logs(filters = {})
        @mutex.synchronize do
          results = @logs.dup

          results.select! { |log| log[:user_id] == filters[:user_id] } if filters[:user_id]

          results.select! { |log| log[:event_type] == filters[:event_type].to_s } if filters[:event_type]

          if filters[:start_time]
            start_time = filters[:start_time].is_a?(String) ? Time.parse(filters[:start_time]) : filters[:start_time]
            results.select! { |log| Time.parse(log[:timestamp]) >= start_time }
          end

          if filters[:end_time]
            end_time = filters[:end_time].is_a?(String) ? Time.parse(filters[:end_time]) : filters[:end_time]
            results.select! { |log| Time.parse(log[:timestamp]) <= end_time }
          end

          results = results.last(filters[:limit]) if filters[:limit]

          results.reverse # Most recent first
        end
      end

      def all_logs
        @mutex.synchronize do
          @logs.dup
        end
      end

      def clear
        @mutex.synchronize do
          @logs.clear
        end
      end
    end
  end
end
