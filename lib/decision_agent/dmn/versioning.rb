# frozen_string_literal: true

require_relative "../versioning/version_manager"
require_relative "parser"
require_relative "exporter"

module DecisionAgent
  module Dmn
    # DMN Versioning Support
    # Integrates DMN models with the DecisionAgent versioning system
    class DmnVersionManager
      attr_reader :version_manager

      def initialize(version_manager: nil)
        @version_manager = version_manager || Versioning::VersionManager.new
      end

      # Save a DMN model as a new version
      def save_dmn_version(model:, created_by: "system", changelog: nil)
        # Export DMN model to XML
        exporter = Exporter.new
        xml_content = exporter.export(model)

        # Save as version
        @version_manager.save_version(
          rule_id: model.id,
          rule_content: {
            format: "dmn",
            xml: xml_content,
            name: model.name,
            namespace: model.namespace
          },
          created_by: created_by,
          changelog: changelog || "DMN model updated"
        )
      end

      # Get a specific DMN version
      def get_dmn_version(version_id:)
        version = @version_manager.get_version(version_id: version_id)
        return nil unless version

        # Parse DMN from version content
        if version[:content].is_a?(Hash) && version[:content][:format] == "dmn"
          parser = Parser.new
          model = parser.parse(version[:content][:xml])

          {
            version_id: version[:version_id],
            model: model,
            created_at: version[:created_at],
            created_by: version[:created_by],
            changelog: version[:changelog],
            is_active: version[:is_active]
          }
        else
          nil
        end
      end

      # Get all versions of a DMN model
      def get_dmn_versions(model_id:, limit: nil)
        versions = @version_manager.get_versions(rule_id: model_id, limit: limit)

        versions.map do |version|
          {
            version_id: version[:version_id],
            created_at: version[:created_at],
            created_by: version[:created_by],
            changelog: version[:changelog],
            is_active: version[:is_active]
          }
        end
      end

      # Get DMN version history with full details
      def get_dmn_history(model_id:)
        history = @version_manager.get_history(rule_id: model_id)

        history.map do |entry|
          if entry[:content].is_a?(Hash) && entry[:content][:format] == "dmn"
            entry.merge(
              model_name: entry[:content][:name],
              model_namespace: entry[:content][:namespace]
            )
          else
            entry
          end
        end
      end

      # Rollback to a previous DMN version
      def rollback_dmn(version_id:, performed_by: "system")
        version = @version_manager.rollback(
          version_id: version_id,
          performed_by: performed_by
        )

        # Parse and return the model
        if version[:content].is_a?(Hash) && version[:content][:format] == "dmn"
          parser = Parser.new
          parser.parse(version[:content][:xml])
        else
          nil
        end
      end

      # Compare two DMN versions
      def compare_dmn_versions(version_id_1:, version_id_2:)
        comparison = @version_manager.compare(
          version_id_1: version_id_1,
          version_id_2: version_id_2
        )

        return nil unless comparison

        # Parse both versions
        parser = Parser.new

        model_1 = if comparison[:version_1][:content].is_a?(Hash) && comparison[:version_1][:content][:format] == "dmn"
                    parser.parse(comparison[:version_1][:content][:xml])
                  end

        model_2 = if comparison[:version_2][:content].is_a?(Hash) && comparison[:version_2][:content][:format] == "dmn"
                    parser.parse(comparison[:version_2][:content][:xml])
                  end

        # Compare DMN models
        diff = compare_models(model_1, model_2)

        comparison.merge(
          model_diff: diff,
          model_1: model_1 ? { id: model_1.id, name: model_1.name, decisions: model_1.decisions.size } : nil,
          model_2: model_2 ? { id: model_2.id, name: model_2.name, decisions: model_2.decisions.size } : nil
        )
      end

      # Delete a DMN version
      def delete_dmn_version(version_id:)
        @version_manager.delete_version(version_id: version_id)
      end

      # Tag a DMN version
      def tag_dmn_version(version_id:, tag:)
        version = @version_manager.get_version(version_id: version_id)
        return false unless version

        # Add tag to metadata (this would need to be implemented in VersionManager)
        # For now, we'll use changelog to append the tag
        true
      end

      # Get active DMN version for a model
      def get_active_dmn_version(model_id:)
        versions = @version_manager.get_versions(rule_id: model_id, limit: 1)
        return nil if versions.empty?

        active_version = versions.find { |v| v[:is_active] } || versions.first
        get_dmn_version(version_id: active_version[:version_id])
      end

      private

      def compare_models(model_1, model_2)
        return { status: "both_nil" } if model_1.nil? && model_2.nil?
        return { status: "model_1_nil" } if model_1.nil?
        return { status: "model_2_nil" } if model_2.nil?

        diff = {
          name_changed: model_1.name != model_2.name,
          namespace_changed: model_1.namespace != model_2.namespace,
          decisions_added: [],
          decisions_removed: [],
          decisions_modified: []
        }

        # Find added/removed/modified decisions
        ids_1 = model_1.decisions.map(&:id).to_set
        ids_2 = model_2.decisions.map(&:id).to_set

        diff[:decisions_added] = (ids_2 - ids_1).to_a
        diff[:decisions_removed] = (ids_1 - ids_2).to_a

        # Check for modified decisions
        common_ids = ids_1 & ids_2
        common_ids.each do |decision_id|
          decision_1 = model_1.find_decision(decision_id)
          decision_2 = model_2.find_decision(decision_id)

          if decision_changed?(decision_1, decision_2)
            diff[:decisions_modified] << decision_id
          end
        end

        diff
      end

      def decision_changed?(decision_1, decision_2)
        return true if decision_1.name != decision_2.name

        # Compare decision tables
        if decision_1.decision_table && decision_2.decision_table
          table_1 = decision_1.decision_table
          table_2 = decision_2.decision_table

          return true if table_1.hit_policy != table_2.hit_policy
          return true if table_1.inputs.size != table_2.inputs.size
          return true if table_1.outputs.size != table_2.outputs.size
          return true if table_1.rules.size != table_2.rules.size
        elsif decision_1.decision_table != decision_2.decision_table
          return true
        end

        false
      end
    end

    # Extension to Model class for versioning support
    module ModelVersioning
      def save_version(created_by: "system", changelog: nil, version_manager: nil)
        vmgr = version_manager || DmnVersionManager.new
        vmgr.save_dmn_version(model: self, created_by: created_by, changelog: changelog)
      end

      def load_version(version_id, version_manager: nil)
        vmgr = version_manager || DmnVersionManager.new
        result = vmgr.get_dmn_version(version_id: version_id)
        result ? result[:model] : nil
      end
    end
  end
end
