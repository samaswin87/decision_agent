module DecisionAgent
  module Versioning
    # High-level service for managing rule versions
    # Provides a framework-agnostic API using pluggable storage adapters
    class VersionManager
      attr_reader :adapter

      # Initialize with a storage adapter
      # @param adapter [Adapter] The storage adapter to use
      def initialize(adapter: nil)
        @adapter = adapter || default_adapter
      end

      # Save a new version of a rule
      # @param rule_id [String] Unique identifier for the rule
      # @param rule_content [Hash] The rule definition
      # @param created_by [String] User who created this version
      # @param changelog [String] Description of changes
      # @return [Hash] The created version
      def save_version(rule_id:, rule_content:, created_by: "system", changelog: nil)
        validate_rule_content!(rule_content)

        metadata = {
          created_by: created_by,
          changelog: changelog || generate_default_changelog(rule_id)
        }

        @adapter.create_version(
          rule_id: rule_id,
          content: rule_content,
          metadata: metadata
        )
      end

      # Get all versions for a rule
      # @param rule_id [String] The rule identifier
      # @param limit [Integer, nil] Optional limit
      # @return [Array<Hash>] Array of versions
      def get_versions(rule_id:, limit: nil)
        @adapter.list_versions(rule_id: rule_id, limit: limit)
      end

      # Get a specific version
      # @param version_id [String, Integer] The version identifier
      # @return [Hash, nil] The version or nil
      def get_version(version_id:)
        @adapter.get_version(version_id: version_id)
      end

      # Get the currently active version for a rule
      # @param rule_id [String] The rule identifier
      # @return [Hash, nil] The active version or nil
      def get_active_version(rule_id:)
        @adapter.get_active_version(rule_id: rule_id)
      end

      # Rollback to a previous version (activate it)
      # @param version_id [String, Integer] The version to rollback to
      # @param performed_by [String] User performing the rollback
      # @return [Hash] The activated version
      def rollback(version_id:, performed_by: "system")
        version = @adapter.activate_version(version_id: version_id)

        # Create an audit trail of the rollback
        save_version(
          rule_id: version[:rule_id],
          rule_content: version[:content],
          created_by: performed_by,
          changelog: "Rolled back to version #{version[:version_number]}"
        )

        version
      end

      # Compare two versions
      # @param version_id_1 [String, Integer] First version
      # @param version_id_2 [String, Integer] Second version
      # @return [Hash] Comparison result
      def compare(version_id_1:, version_id_2:)
        @adapter.compare_versions(
          version_id_1: version_id_1,
          version_id_2: version_id_2
        )
      end

      # Get version history with metadata
      # @param rule_id [String] The rule identifier
      # @return [Hash] History with statistics
      def get_history(rule_id:)
        versions = get_versions(rule_id: rule_id)

        {
          rule_id: rule_id,
          total_versions: versions.length,
          active_version: get_active_version(rule_id: rule_id),
          versions: versions,
          created_at: versions.last&.dig(:created_at),
          updated_at: versions.first&.dig(:created_at)
        }
      end

      # Delete a specific version
      # @param version_id [String, Integer] The version to delete
      # @return [Boolean] True if deleted successfully
      def delete_version(version_id:)
        @adapter.delete_version(version_id: version_id)
      end

      private

      def default_adapter
        # Auto-detect the best adapter based on available frameworks
        if defined?(ActiveRecord) && defined?(::RuleVersion)
          require_relative "activerecord_adapter"
          ActiveRecordAdapter.new
        else
          require_relative "file_storage_adapter"
          FileStorageAdapter.new
        end
      end

      def validate_rule_content!(content)
        raise DecisionAgent::ValidationError, "Rule content cannot be nil" if content.nil?
        raise DecisionAgent::ValidationError, "Rule content must be a Hash" unless content.is_a?(Hash)
        raise DecisionAgent::ValidationError, "Rule content cannot be empty" if content.empty?
      end

      def generate_default_changelog(rule_id)
        versions = get_versions(rule_id: rule_id)
        version_num = versions.empty? ? 1 : versions.first[:version_number] + 1
        "Version #{version_num}"
      end
    end
  end
end
