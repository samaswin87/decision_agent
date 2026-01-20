module DecisionAgent
  module Versioning
    # Abstract base class for version storage adapters
    # Allows framework-agnostic versioning with pluggable storage backends
    class Adapter
      # Create a new version for a rule
      # @param rule_id [String] Unique identifier for the rule
      # @param content [Hash] Rule definition as a hash
      # @param metadata [Hash] Additional metadata (created_by, changelog, etc.)
      # @return [Hash] The created version
      def create_version(rule_id:, content:, metadata: {})
        raise NotImplementedError, "#{self.class} must implement #create_version"
      end

      # List all versions for a specific rule
      # @param rule_id [String] The rule identifier
      # @param limit [Integer, nil] Optional limit for number of versions
      # @return [Array<Hash>] Array of version hashes
      def list_versions(rule_id:, limit: nil)
        raise NotImplementedError, "#{self.class} must implement #list_versions"
      end

      # List all versions across all rules
      # @param limit [Integer, nil] Optional limit for number of versions
      # @return [Array<Hash>] Array of version hashes
      def list_all_versions(limit: nil)
        raise NotImplementedError, "#{self.class} must implement #list_all_versions"
      end

      # Get a specific version by ID
      # @param version_id [String, Integer] The version identifier
      # @return [Hash, nil] The version hash or nil if not found
      def get_version(version_id:)
        raise NotImplementedError, "#{self.class} must implement #get_version"
      end

      # Get a specific version by rule_id and version_number
      # @param rule_id [String] The rule identifier
      # @param version_number [Integer] The version number
      # @return [Hash, nil] The version hash or nil if not found
      def get_version_by_number(rule_id:, version_number:)
        raise NotImplementedError, "#{self.class} must implement #get_version_by_number"
      end

      # Get the active version for a rule
      # @param rule_id [String] The rule identifier
      # @return [Hash, nil] The active version or nil
      def get_active_version(rule_id:)
        raise NotImplementedError, "#{self.class} must implement #get_active_version"
      end

      # Activate a specific version
      # @param version_id [String, Integer] The version to activate
      # @return [Hash] The activated version
      def activate_version(version_id:)
        raise NotImplementedError, "#{self.class} must implement #activate_version"
      end

      # Compare two versions
      # @param version_id_1 [String, Integer] First version ID
      # @param version_id_2 [String, Integer] Second version ID
      # @return [Hash] Comparison result with differences
      def compare_versions(version_id_1:, version_id_2:)
        v1 = get_version(version_id: version_id_1)
        v2 = get_version(version_id: version_id_2)

        return nil if v1.nil? || v2.nil?

        {
          version_1: v1,
          version_2: v2,
          differences: calculate_diff(v1[:content], v2[:content])
        }
      end

      # Delete a specific version
      # @param version_id [String, Integer] The version to delete
      # @return [Boolean] True if deleted successfully
      def delete_version(version_id:)
        raise NotImplementedError, "#{self.class} must implement #delete_version"
      end

      private

      # Calculate differences between two content hashes
      # @param content1 [Hash] First content
      # @param content2 [Hash] Second content
      # @return [Hash] Differences
      def calculate_diff(content1, content2)
        {
          added: content2.to_a - content1.to_a,
          removed: content1.to_a - content2.to_a,
          changed: detect_changes(content1, content2)
        }
      end

      def detect_changes(hash1, hash2)
        changes = {}
        hash1.each do |key, value1|
          value2 = hash2[key]
          changes[key] = { old: value1, new: value2 } if value1 != value2 && !value2.nil?
        end
        changes
      end
    end
  end
end
