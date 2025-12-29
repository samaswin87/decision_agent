require_relative "adapter"
require "json"
require "fileutils"

module DecisionAgent
  module Versioning
    # Status validation shared by adapters
    module StatusValidator
      VALID_STATUSES = %w[draft active archived].freeze

      def validate_status!(status)
        return if VALID_STATUSES.include?(status)

        raise DecisionAgent::ValidationError,
              "Invalid status '#{status}'. Must be one of: #{VALID_STATUSES.join(', ')}"
      end
    end

    # File-based version storage adapter for non-Rails applications
    # Stores versions as JSON files in a directory structure
    class FileStorageAdapter < Adapter
      include StatusValidator

      attr_reader :storage_path

      # Initialize with a storage directory
      # @param storage_path [String] Path to store version files (default: ./versions)
      def initialize(storage_path: "./versions")
        @storage_path = storage_path
        # Per-rule mutex for better concurrency - allows different rules to be processed in parallel
        @rule_mutexes = Hash.new { |h, k| h[k] = Mutex.new }
        @rule_mutexes_lock = Mutex.new # Protects the hash itself
        # Index cache: version_id => rule_id mapping for O(1) lookups
        @version_index = {}
        @version_index_lock = Mutex.new
        FileUtils.mkdir_p(@storage_path)
        load_version_index
      end

      def create_version(rule_id:, content:, metadata: {})
        with_rule_lock(rule_id) do
          create_version_unsafe(rule_id: rule_id, content: content, metadata: metadata)
        end
      end

      private

      def create_version_unsafe(rule_id:, content:, metadata: {})
        # Get the next version number
        versions = list_versions_unsafe(rule_id: rule_id)
        next_version_number = versions.empty? ? 1 : versions.first[:version_number] + 1

        # Validate status if provided
        status = metadata[:status] || "active"
        validate_status!(status)

        # Deactivate previous active versions
        versions.each do |v|
          update_version_status_unsafe(v[:id], "archived", rule_id) if v[:status] == "active"
        end

        # Create version data
        version_id = generate_version_id(rule_id, next_version_number)
        version = {
          id: version_id,
          rule_id: rule_id,
          version_number: next_version_number,
          content: content,
          created_by: metadata[:created_by] || "system",
          created_at: Time.now.utc.iso8601,
          changelog: metadata[:changelog] || "Version #{next_version_number}",
          status: status
        }

        # Write to file
        write_version_file(version)

        version
      end

      public

      def list_versions(rule_id:, limit: nil)
        with_rule_lock(rule_id) do
          list_versions_unsafe(rule_id: rule_id, limit: limit)
        end
      end

      def get_version(version_id:)
        # Use index to find rule_id quickly - O(1) instead of O(n)
        begin
          rule_id = get_rule_id_from_index(version_id)
        rescue StandardError
          # If index lookup fails, version doesn't exist
          return nil
        end
        return nil unless rule_id

        # Now lock on the specific rule
        begin
          with_rule_lock(rule_id) do
            # Read only this rule's versions
            versions = list_versions_unsafe(rule_id: rule_id)
            versions.find { |v| v[:id] == version_id }
          end
        rescue StandardError
          # If any error occurs during lookup, treat as version not found
          return nil
        end
      end

      def get_version_by_number(rule_id:, version_number:)
        with_rule_lock(rule_id) do
          versions = list_versions_unsafe(rule_id: rule_id)
          versions.find { |v| v[:version_number] == version_number }
        end
      end

      def get_active_version(rule_id:)
        with_rule_lock(rule_id) do
          versions = list_versions_unsafe(rule_id: rule_id)
          versions.find { |v| v[:status] == "active" }
        end
      end

      def activate_version(version_id:)
        # Use index to find rule_id quickly - O(1) instead of O(n)
        rule_id = get_rule_id_from_index(version_id)
        raise DecisionAgent::NotFoundError, "Version not found: #{version_id}" unless rule_id

        # Now lock on the specific rule
        with_rule_lock(rule_id) do
          # Read only this rule's versions
          versions = list_versions_unsafe(rule_id: rule_id)
          version = versions.find { |v| v[:id] == version_id }
          raise DecisionAgent::NotFoundError, "Version not found: #{version_id}" unless version

          # Deactivate all other versions for this rule
          versions.each do |v|
            update_version_status_unsafe(v[:id], "archived", rule_id) if v[:id] != version_id && v[:status] == "active"
          end

          # Activate this version
          version[:status] = "active"
          write_version_file(version)

          version
        end
      end

      def delete_version(version_id:)
        # Use index to find rule_id quickly - O(1) instead of O(n)
        begin
          rule_id = get_rule_id_from_index(version_id)
        rescue StandardError
          # If index lookup fails, version doesn't exist
          raise DecisionAgent::NotFoundError, "Version not found: #{version_id}"
        end
        
        raise DecisionAgent::NotFoundError, "Version not found: #{version_id}" unless rule_id

        # Now lock on the specific rule
        begin
          with_rule_lock(rule_id) do
            # Read only this rule's versions
            versions = list_versions_unsafe(rule_id: rule_id)
            version = versions.find { |v| v[:id] == version_id || v[:id].to_s == version_id.to_s }
          
            # If version not in list, check if file exists - might have been manually deleted
            unless version
              rule_dir = File.join(@storage_path, sanitize_filename(rule_id))
              # Try to find the file by checking all version files
              file_found = false
              begin
                Dir.glob(File.join(rule_dir, "*.json")).each do |filepath|
                  begin
                    file_data = JSON.parse(File.read(filepath))
                    if file_data["id"] == version_id || file_data[:id] == version_id || 
                       file_data["id"].to_s == version_id.to_s || file_data[:id].to_s == version_id.to_s
                      # File exists but not in versions list - remove from index and return false
                      file_found = true
                      remove_from_index(version_id)
                      return false
                    end
                  rescue Errno::ENOENT, JSON::ParserError
                    # File was deleted or corrupted, continue searching
                    next
                  end
                end
              rescue Errno::ENOENT
                # Directory doesn't exist, version not found
              end
              # Version not found in list and file doesn't exist - clean up index and return false
              remove_from_index(version_id)
              return false
            end

            # Prevent deletion of active versions
            if version[:status] == "active"
              raise DecisionAgent::ValidationError, "Cannot delete active version. Please activate another version first."
            end

            # Delete the file
            rule_dir = File.join(@storage_path, sanitize_filename(rule_id))
            filename = "#{version[:version_number]}.json"
            filepath = File.join(rule_dir, filename)

            if File.exist?(filepath)
              File.delete(filepath)
              # Remove from index
              remove_from_index(version_id)
              true
            else
              # File already deleted - clean up index and return false
              remove_from_index(version_id)
              false
            end
          end
        rescue DecisionAgent::ValidationError, DecisionAgent::NotFoundError
          # Re-raise expected errors
          raise
        rescue StandardError => e
          # If any unexpected error occurs during the lock operation, treat as version not found
          # This prevents 500 errors from propagating when version doesn't exist or is in an invalid state
          # This is safe because if the version existed and was valid, we would have found it above
          remove_from_index(version_id) rescue nil
          raise DecisionAgent::NotFoundError, "Version not found: #{version_id}"
        end
      end

      private

      def list_versions_unsafe(rule_id:, limit: nil)
        versions = []
        rule_dir = File.join(@storage_path, sanitize_filename(rule_id))

        return versions unless Dir.exist?(rule_dir)

        Dir.glob(File.join(rule_dir, "*.json")).each do |file|
          begin
            versions << JSON.parse(File.read(file), symbolize_names: true)
          rescue JSON::ParserError, Errno::ENOENT
            # Skip corrupted or deleted files
            next
          end
        end

        versions.sort_by! { |v| -v[:version_number] }
        limit ? versions.take(limit) : versions
      end

      def all_versions_unsafe
        versions = []
        return versions unless Dir.exist?(@storage_path)

        Dir.glob(File.join(@storage_path, "*", "*.json")).each do |file|
          versions << JSON.parse(File.read(file), symbolize_names: true)
        end

        versions
      end

      def update_version_status_unsafe(version_id, status, rule_id = nil)
        # Validate status first
        validate_status!(status)

        # Use provided rule_id or look it up from index
        rule_id ||= get_rule_id_from_index(version_id)
        return unless rule_id

        # Read only this rule's versions
        versions = list_versions_unsafe(rule_id: rule_id)
        version = versions.find { |v| v[:id] == version_id }
        return unless version

        version[:status] = status
        write_version_file(version)
      end

      def write_version_file(version)
        rule_dir = File.join(@storage_path, sanitize_filename(version[:rule_id]))
        FileUtils.mkdir_p(rule_dir)

        filename = "#{version[:version_number]}.json"
        filepath = File.join(rule_dir, filename)

        # Use atomic write to prevent race conditions during concurrent access
        # Write to temp file first, then atomically rename
        temp_file = "#{filepath}.tmp.#{Process.pid}.#{Thread.current.object_id}"
        begin
          File.write(temp_file, JSON.pretty_generate(version))
          File.rename(temp_file, filepath)
          # Update index after successful write
          add_to_index(version[:id], version[:rule_id])
        ensure
          # Clean up temp file if rename failed
          FileUtils.rm_f(temp_file)
        end
      end

      def generate_version_id(rule_id, version_number)
        "#{rule_id}_v#{version_number}"
      end

      def sanitize_filename(name)
        name.to_s.gsub(/[^a-zA-Z0-9_-]/, "_")
      end

      # Get or create a mutex for a specific rule_id
      # This allows different rules to be processed in parallel
      def with_rule_lock(rule_id, &block)
        mutex = @rule_mutexes_lock.synchronize { @rule_mutexes[rule_id] }
        mutex.synchronize(&block)
      end

      # Index management methods for O(1) version_id -> rule_id lookups
      # This prevents the need to scan all 50,000 files when looking up a single version

      def load_version_index
        @version_index_lock.synchronize do
          return unless Dir.exist?(@storage_path)

          Dir.glob(File.join(@storage_path, "*", "*.json")).each do |file|
            version = JSON.parse(File.read(file), symbolize_names: true)
            @version_index[version[:id]] = version[:rule_id]
          rescue JSON::ParserError
            # Skip corrupted files
            next
          end
        end
      end

      def get_rule_id_from_index(version_id)
        @version_index_lock.synchronize do
          @version_index[version_id]
        end
      end

      def add_to_index(version_id, rule_id)
        @version_index_lock.synchronize do
          @version_index[version_id] = rule_id
        end
      end

      def remove_from_index(version_id)
        @version_index_lock.synchronize do
          @version_index.delete(version_id)
        end
      end
    end
  end
end
