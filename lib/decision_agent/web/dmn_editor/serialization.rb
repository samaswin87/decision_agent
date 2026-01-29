# frozen_string_literal: true

module DecisionAgent
  module Web
    class DmnEditor
      module Serialization
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
end
