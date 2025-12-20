require_relative "adapter"

module DecisionAgent
  module Versioning
    # ActiveRecord-based version storage adapter for Rails applications
    # Requires ActiveRecord models to be set up in the Rails app
    class ActiveRecordAdapter < Adapter
      def initialize
        unless defined?(ActiveRecord)
          raise DecisionAgent::ConfigurationError,
                "ActiveRecord is not available. Please ensure Rails/ActiveRecord is loaded."
        end
      end

      def create_version(rule_id:, content:, metadata: {})
        # Use a transaction with pessimistic locking to prevent race conditions
        version = nil

        rule_version_class.transaction do
          # Lock the last version for this rule to prevent concurrent reads
          # This ensures only one thread can calculate the next version number at a time
          last_version = rule_version_class.where(rule_id: rule_id)
                                          .order(version_number: :desc)
                                          .lock
                                          .first
          next_version_number = last_version ? last_version.version_number + 1 : 1

          # Deactivate previous active versions
          rule_version_class.where(rule_id: rule_id, status: "active")
                           .update_all(status: "archived")

          # Create new version
          version = rule_version_class.create!(
            rule_id: rule_id,
            version_number: next_version_number,
            content: content.to_json,
            created_by: metadata[:created_by] || "system",
            changelog: metadata[:changelog] || "Version #{next_version_number}",
            status: metadata[:status] || "active"
          )
        end

        serialize_version(version)
      end

      def list_versions(rule_id:, limit: nil)
        query = rule_version_class.where(rule_id: rule_id)
                                  .order(version_number: :desc)
        query = query.limit(limit) if limit

        query.map { |v| serialize_version(v) }
      end

      def get_version(version_id:)
        version = rule_version_class.find_by(id: version_id)
        version ? serialize_version(version) : nil
      end

      def get_version_by_number(rule_id:, version_number:)
        version = rule_version_class.find_by(
          rule_id: rule_id,
          version_number: version_number
        )
        version ? serialize_version(version) : nil
      end

      def get_active_version(rule_id:)
        version = rule_version_class.find_by(rule_id: rule_id, status: "active")
        version ? serialize_version(version) : nil
      end

      def activate_version(version_id:)
        version = nil

        rule_version_class.transaction do
          # Find and lock the version to activate
          version = rule_version_class.lock.find(version_id)

          # Deactivate all other versions for this rule within the same transaction
          # The lock ensures only one thread can perform this operation at a time
          rule_version_class.where(rule_id: version.rule_id, status: "active")
                           .where.not(id: version_id)
                           .update_all(status: "archived")

          # Activate this version
          version.update!(status: "active")
        end

        serialize_version(version)
      end

      private

      def rule_version_class
        # Look for the RuleVersion model in the main app
        if defined?(::RuleVersion)
          ::RuleVersion
        else
          raise DecisionAgent::ConfigurationError,
                "RuleVersion model not found. Please run the generator to create it."
        end
      end

      def serialize_version(version)
        # Parse JSON content with proper error handling
        parsed_content = begin
          JSON.parse(version.content)
        rescue JSON::ParserError => e
          raise DecisionAgent::ValidationError,
                "Invalid JSON in version #{version.id} for rule #{version.rule_id}: #{e.message}"
        rescue TypeError, NoMethodError => e
          raise DecisionAgent::ValidationError,
                "Invalid content in version #{version.id} for rule #{version.rule_id}: content is nil or not a string"
        end

        {
          id: version.id,
          rule_id: version.rule_id,
          version_number: version.version_number,
          content: parsed_content,
          created_by: version.created_by,
          created_at: version.created_at,
          changelog: version.changelog,
          status: version.status
        }
      end
    end
  end
end
