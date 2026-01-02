require_relative "parser"
require_relative "validator"
require_relative "adapter"
require_relative "../versioning/version_manager"

module DecisionAgent
  module Dmn
    # Imports DMN XML files into DecisionAgent
    class Importer
      def initialize(version_manager: nil)
        @version_manager = version_manager || Versioning::VersionManager.new
      end

      # Import DMN file
      # @param file_path [String] Path to DMN XML file
      # @param ruleset_name [String, nil] Optional custom ruleset name
      # @param created_by [String] User who imported
      # @return [Hash] Import result with model and version info
      def import(file_path, ruleset_name: nil, created_by: "system")
        xml_content = File.read(file_path)
        import_from_xml(xml_content, ruleset_name: ruleset_name, created_by: created_by)
      end

      # Import from XML string
      def import_from_xml(xml_content, ruleset_name: nil, created_by: "system")
        # Parse DMN XML
        parser = Parser.new(xml_content)
        model = parser.parse

        # Validate model
        validator = Validator.new(model)
        validator.validate!

        # Convert to JSON rules
        results = convert_model_to_rules(model)

        # Store in versioning system
        versions = store_in_versioning(results, ruleset_name, created_by)

        {
          model: model,
          rules: results,
          versions: versions,
          decisions_imported: results.size
        }
      end

      private

      def convert_model_to_rules(model)
        model.decisions.map do |decision|
          next unless decision.decision_table

          adapter = Adapter.new(decision.decision_table)
          {
            decision_id: decision.id,
            decision_name: decision.name,
            rules: adapter.to_json_rules
          }
        end.compact
      end

      def store_in_versioning(results, ruleset_name, created_by)
        results.map do |result|
          rule_id = ruleset_name || result[:decision_id]

          @version_manager.save_version(
            rule_id: rule_id,
            rule_content: result[:rules],
            created_by: created_by,
            changelog: "Imported DMN decision: #{result[:decision_name]}"
          )
        end
      end
    end
  end
end
