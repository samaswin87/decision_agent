require_relative "adapter"
require "json"
require "fileutils"

module DecisionAgent
  module Versioning
    # File-based version storage adapter for non-Rails applications
    # Stores versions as JSON files in a directory structure
    class FileStorageAdapter < Adapter
      attr_reader :storage_path

      # Initialize with a storage directory
      # @param storage_path [String] Path to store version files (default: ./versions)
      def initialize(storage_path: "./versions")
        @storage_path = storage_path
        @mutex = Mutex.new
        FileUtils.mkdir_p(@storage_path)
      end

      def create_version(rule_id:, content:, metadata: {})
        @mutex.synchronize do
          create_version_unsafe(rule_id: rule_id, content: content, metadata: metadata)
        end
      end

      private

      def create_version_unsafe(rule_id:, content:, metadata: {})
        # Get the next version number
        versions = list_versions(rule_id: rule_id)
        next_version_number = versions.empty? ? 1 : versions.first[:version_number] + 1

        # Deactivate previous active versions
        versions.each do |v|
          if v[:status] == "active"
            update_version_status(v[:id], "archived")
          end
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
          status: metadata[:status] || "active"
        }

        # Write to file
        write_version_file(version)

        version
      end

      public

      def list_versions(rule_id:, limit: nil)
        versions = []
        rule_dir = File.join(@storage_path, sanitize_filename(rule_id))

        return versions unless Dir.exist?(rule_dir)

        Dir.glob(File.join(rule_dir, "*.json")).each do |file|
          versions << JSON.parse(File.read(file), symbolize_names: true)
        end

        versions.sort_by! { |v| -v[:version_number] }
        limit ? versions.take(limit) : versions
      end

      def get_version(version_id:)
        all_versions.find { |v| v[:id] == version_id }
      end

      def get_version_by_number(rule_id:, version_number:)
        versions = list_versions(rule_id: rule_id)
        versions.find { |v| v[:version_number] == version_number }
      end

      def get_active_version(rule_id:)
        versions = list_versions(rule_id: rule_id)
        versions.find { |v| v[:status] == "active" }
      end

      def activate_version(version_id:)
        @mutex.synchronize do
          version = get_version(version_id: version_id)
          raise DecisionAgent::NotFoundError, "Version not found: #{version_id}" unless version

          # Deactivate all other versions for this rule
          list_versions(rule_id: version[:rule_id]).each do |v|
            if v[:id] != version_id && v[:status] == "active"
              update_version_status(v[:id], "archived")
            end
          end

          # Activate this version
          version[:status] = "active"
          write_version_file(version)

          version
        end
      end

      private

      def all_versions
        versions = []
        return versions unless Dir.exist?(@storage_path)

        Dir.glob(File.join(@storage_path, "*", "*.json")).each do |file|
          versions << JSON.parse(File.read(file), symbolize_names: true)
        end

        versions
      end

      def update_version_status(version_id, status)
        version = get_version(version_id: version_id)
        return unless version

        version[:status] = status
        write_version_file(version)
      end

      def write_version_file(version)
        rule_dir = File.join(@storage_path, sanitize_filename(version[:rule_id]))
        FileUtils.mkdir_p(rule_dir)

        filename = "#{version[:version_number]}.json"
        filepath = File.join(rule_dir, filename)

        File.write(filepath, JSON.pretty_generate(version))
      end

      def generate_version_id(rule_id, version_number)
        "#{rule_id}_v#{version_number}"
      end

      def sanitize_filename(name)
        name.to_s.gsub(/[^a-zA-Z0-9_-]/, "_")
      end
    end
  end
end
