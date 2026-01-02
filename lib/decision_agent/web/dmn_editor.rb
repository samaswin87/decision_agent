# frozen_string_literal: true

require "json"
require_relative "../dmn/parser"
require_relative "../dmn/exporter"
require_relative "../dmn/importer"
require_relative "../dmn/validator"
require_relative "../dmn/model"
require_relative "../dmn/decision_tree"
require_relative "../dmn/decision_graph"
require_relative "../dmn/visualizer"

module DecisionAgent
  module Web
    # DMN Editor Backend
    # Provides API endpoints for visual DMN modeling
    class DmnEditor
      attr_reader :storage

      def initialize(storage: nil)
        @storage = storage || {}
        @storage_mutex = Mutex.new
      end

      # Create a new DMN model
      def create_model(name:, namespace: nil)
        model_id = generate_id
        namespace ||= "http://decisonagent.com/dmn/#{model_id}"

        model = Dmn::Model.new(
          id: model_id,
          name: name,
          namespace: namespace
        )

        store_model(model_id, model)

        {
          id: model_id,
          name: name,
          namespace: namespace,
          decisions: [],
          created_at: Time.now.utc.iso8601
        }
      end

      # Get a DMN model
      def get_model(model_id)
        model = retrieve_model(model_id)
        return nil unless model

        serialize_model(model)
      end

      # Update DMN model metadata
      def update_model(model_id, name: nil, namespace: nil)
        model = retrieve_model(model_id)
        return nil unless model

        model.instance_variable_set(:@name, name) if name
        model.instance_variable_set(:@namespace, namespace) if namespace

        store_model(model_id, model)
        serialize_model(model)
      end

      # Delete a DMN model
      def delete_model(model_id)
        @storage_mutex.synchronize do
          @storage.delete(model_id)
        end
        true
      end

      # Add a decision to a model
      def add_decision(model_id:, decision_id:, name:, type: "decision_table")
        model = retrieve_model(model_id)
        return nil unless model

        decision = Dmn::Decision.new(
          id: decision_id,
          name: name
        )

        # Initialize decision logic based on type
        case type
        when "decision_table"
          decision.instance_variable_set(:@decision_table, Dmn::DecisionTable.new(
            id: "#{decision_id}_table",
            hit_policy: "FIRST"
          ))
        when "decision_tree"
          decision.instance_variable_set(:@decision_tree, Dmn::DecisionTree.new(
            id: "#{decision_id}_tree",
            name: name
          ))
        when "literal"
          decision.instance_variable_set(:@literal_expression, "")
        end

        model.add_decision(decision)
        store_model(model_id, model)

        serialize_decision(decision)
      end

      # Update a decision
      def update_decision(model_id:, decision_id:, name: nil, logic: nil)
        model = retrieve_model(model_id)
        return nil unless model

        decision = model.find_decision(decision_id)
        return nil unless decision

        decision.instance_variable_set(:@name, name) if name

        if logic && decision.decision_table
          update_decision_table(decision.decision_table, logic)
        end

        store_model(model_id, model)
        serialize_decision(decision)
      end

      # Delete a decision
      def delete_decision(model_id:, decision_id:)
        model = retrieve_model(model_id)
        return false unless model

        model.decisions.reject! { |d| d.id == decision_id }
        store_model(model_id, model)
        true
      end

      # Add input to decision table
      def add_input(model_id:, decision_id:, input_id:, label:, type_ref: nil, expression: nil)
        model = retrieve_model(model_id)
        return nil unless model

        decision = model.find_decision(decision_id)
        return nil unless decision || !decision.decision_table

        input = Dmn::Input.new(
          id: input_id,
          label: label,
          type_ref: type_ref,
          expression: expression
        )

        decision.decision_table.inputs << input
        store_model(model_id, model)

        serialize_input(input)
      end

      # Add output to decision table
      def add_output(model_id:, decision_id:, output_id:, label:, type_ref: nil, name: nil)
        model = retrieve_model(model_id)
        return nil unless model

        decision = model.find_decision(decision_id)
        return nil unless decision || !decision.decision_table

        output = Dmn::Output.new(
          id: output_id,
          label: label,
          type_ref: type_ref,
          name: name
        )

        decision.decision_table.outputs << output
        store_model(model_id, model)

        serialize_output(output)
      end

      # Add rule to decision table
      def add_rule(model_id:, decision_id:, rule_id:, input_entries:, output_entries:, description: nil)
        model = retrieve_model(model_id)
        return nil unless model

        decision = model.find_decision(decision_id)
        return nil unless decision || !decision.decision_table

        rule = Dmn::Rule.new(id: rule_id)
        rule.instance_variable_set(:@input_entries, input_entries)
        rule.instance_variable_set(:@output_entries, output_entries)
        rule.instance_variable_set(:@description, description) if description

        decision.decision_table.rules << rule
        store_model(model_id, model)

        serialize_rule(rule)
      end

      # Update rule
      def update_rule(model_id:, decision_id:, rule_id:, input_entries: nil, output_entries: nil, description: nil)
        model = retrieve_model(model_id)
        return nil unless model

        decision = model.find_decision(decision_id)
        return nil unless decision || !decision.decision_table

        rule = decision.decision_table.rules.find { |r| r.id == rule_id }
        return nil unless rule

        rule.instance_variable_set(:@input_entries, input_entries) if input_entries
        rule.instance_variable_set(:@output_entries, output_entries) if output_entries
        rule.instance_variable_set(:@description, description) if description

        store_model(model_id, model)
        serialize_rule(rule)
      end

      # Delete rule
      def delete_rule(model_id:, decision_id:, rule_id:)
        model = retrieve_model(model_id)
        return false unless model

        decision = model.find_decision(decision_id)
        return false unless decision || !decision.decision_table

        decision.decision_table.rules.reject! { |r| r.id == rule_id }
        store_model(model_id, model)
        true
      end

      # Validate a DMN model
      def validate_model(model_id)
        model = retrieve_model(model_id)
        return { valid: false, errors: ["Model not found"] } unless model

        validator = Dmn::Validator.new
        validator.validate(model)

        {
          valid: validator.valid?,
          errors: validator.errors,
          warnings: validator.warnings
        }
      end

      # Export DMN model to XML
      def export_to_xml(model_id)
        model = retrieve_model(model_id)
        return nil unless model

        exporter = Dmn::Exporter.new
        exporter.export(model)
      end

      # Import DMN model from XML
      def import_from_xml(xml_content, name: nil)
        parser = Dmn::Parser.new
        model = parser.parse(xml_content)

        # Generate new ID for imported model
        model_id = generate_id
        model.instance_variable_set(:@id, model_id)
        model.instance_variable_set(:@name, name) if name

        store_model(model_id, model)

        serialize_model(model)
      end

      # Generate visualization for decision tree
      def visualize_tree(model_id:, decision_id:, format: "svg")
        model = retrieve_model(model_id)
        return nil unless model

        decision = model.find_decision(decision_id)
        return nil unless decision || !decision.decision_tree

        case format.to_s.downcase
        when "svg"
          Dmn::Visualizer.tree_to_svg(decision.decision_tree)
        when "dot"
          Dmn::Visualizer.tree_to_dot(decision.decision_tree)
        when "mermaid"
          Dmn::Visualizer.tree_to_mermaid(decision.decision_tree)
        else
          nil
        end
      end

      # Generate visualization for decision graph
      def visualize_graph(model_id:, format: "svg")
        model = retrieve_model(model_id)
        return nil unless model

        # Convert model to decision graph
        graph = Dmn::DecisionGraph.new(id: model.id, name: model.name)
        model.decisions.each do |decision|
          node = Dmn::DecisionNode.new(
            id: decision.id,
            name: decision.name,
            decision_logic: decision.decision_table || decision.decision_tree
          )

          # Add dependencies from information requirements
          decision.information_requirements.each do |req|
            node.add_dependency(req[:decision_id], req[:variable_name])
          end

          graph.add_decision(node)
        end

        case format.to_s.downcase
        when "svg"
          Dmn::Visualizer.graph_to_svg(graph)
        when "dot"
          Dmn::Visualizer.graph_to_dot(graph)
        when "mermaid"
          Dmn::Visualizer.graph_to_mermaid(graph)
        else
          nil
        end
      end

      # List all models
      def list_models
        @storage_mutex.synchronize do
          @storage.map do |id, model|
            {
              id: id,
              name: model.name,
              namespace: model.namespace,
              decision_count: model.decisions.size
            }
          end
        end
      end

      private

      def generate_id
        "dmn_#{Time.now.to_i}_#{rand(10000)}"
      end

      def store_model(model_id, model)
        @storage_mutex.synchronize do
          @storage[model_id] = model
        end
      end

      def retrieve_model(model_id)
        @storage_mutex.synchronize do
          @storage[model_id]
        end
      end

      def update_decision_table(table, logic)
        table.instance_variable_set(:@hit_policy, logic[:hit_policy]) if logic[:hit_policy]
        table.instance_variable_set(:@inputs, logic[:inputs]) if logic[:inputs]
        table.instance_variable_set(:@outputs, logic[:outputs]) if logic[:outputs]
        table.instance_variable_set(:@rules, logic[:rules]) if logic[:rules]
      end

      def serialize_model(model)
        {
          id: model.id,
          name: model.name,
          namespace: model.namespace,
          decisions: model.decisions.map { |d| serialize_decision(d) }
        }
      end

      def serialize_decision(decision)
        result = {
          id: decision.id,
          name: decision.name
        }

        if decision.decision_table
          result[:decision_table] = serialize_decision_table(decision.decision_table)
        elsif decision.decision_tree
          result[:decision_tree] = decision.decision_tree.to_h
        elsif decision.instance_variable_get(:@literal_expression)
          result[:literal_expression] = decision.instance_variable_get(:@literal_expression)
        end

        result[:information_requirements] = decision.information_requirements if decision.information_requirements.any?

        result
      end

      def serialize_decision_table(table)
        {
          id: table.id,
          hit_policy: table.hit_policy,
          inputs: table.inputs.map { |i| serialize_input(i) },
          outputs: table.outputs.map { |o| serialize_output(o) },
          rules: table.rules.map { |r| serialize_rule(r) }
        }
      end

      def serialize_input(input)
        {
          id: input.id,
          label: input.label,
          type_ref: input.type_ref,
          expression: input.expression
        }
      end

      def serialize_output(output)
        {
          id: output.id,
          label: output.label,
          type_ref: output.type_ref,
          name: output.name
        }
      end

      def serialize_rule(rule)
        {
          id: rule.id,
          input_entries: rule.input_entries,
          output_entries: rule.output_entries,
          description: rule.description
        }
      end
    end
  end
end
