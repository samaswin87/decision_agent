# frozen_string_literal: true

module DecisionAgent
  module Web
    class DmnEditor
      module XmlBuilder
        def generate_dmn_xml(model)
          require "nokogiri"

          builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
            xml.definitions(
              "xmlns" => "https://www.omg.org/spec/DMN/20191111/MODEL/",
              "xmlns:dmndi" => "https://www.omg.org/spec/DMN/20191111/DMNDI/",
              "xmlns:dc" => "http://www.omg.org/spec/DMN/20180521/DC/",
              "id" => "definitions_#{model.id}",
              "name" => model.name,
              "namespace" => model.namespace || "http://decision_agent.local"
            ) do
              model.decisions.each do |decision|
                xml.decision(id: decision.id, name: decision.name) do
                  if decision.decision_table
                    build_decision_table_xml(xml, decision.decision_table)
                  elsif decision.decision_tree
                    xml.comment "Decision Tree (not fully supported in DMN XML export yet)"
                  elsif decision.instance_variable_get(:@literal_expression)
                    xml.literalExpression do
                      xml.text decision.instance_variable_get(:@literal_expression)
                    end
                  end
                end
              end
            end
          end

          builder.to_xml
        end

        def build_decision_table_xml(xml, table)
          xml.decisionTable(
            id: table.id,
            hitPolicy: table.hit_policy || "FIRST",
            outputLabel: "output"
          ) do
            build_inputs_xml(xml, table)
            build_outputs_xml(xml, table)
            build_rules_xml(xml, table)
          end
        end

        private

        def build_inputs_xml(xml, table)
          table.inputs.each do |input|
            xml.input(id: input.id, label: input.label) do
              xml.inputExpression(typeRef: input.type_ref || "string") do
                text_node = Nokogiri::XML::Node.new("text", xml.doc)
                text_node.content = input.expression || input.label
                xml.parent.add_child(text_node)
              end
            end
          end
        end

        def build_outputs_xml(xml, table)
          table.outputs.each do |output|
            xml.output(
              id: output.id,
              label: output.label,
              name: output.name || output.label,
              typeRef: output.type_ref || "string"
            )
          end
        end

        def build_rules_xml(xml, table)
          table.rules.each { |rule| build_rule_xml(xml, rule) }
        end

        def build_rule_xml(xml, rule)
          xml.rule(id: rule.id) do
            rule.input_entries.each_with_index do |entry, idx|
              add_entry_element(xml, "inputEntry", "#{rule.id}_input_#{idx + 1}", entry)
            end
            rule.output_entries.each_with_index do |entry, idx|
              add_entry_element(xml, "outputEntry", "#{rule.id}_output_#{idx + 1}", entry)
            end
            add_rule_description(xml, rule)
          end
        end

        def add_entry_element(xml, tag, id, content)
          xml.send(tag, id: id) do
            text_node = Nokogiri::XML::Node.new("text", xml.doc)
            text_node.content = content.to_s
            xml.parent.add_child(text_node)
          end
        end

        def add_rule_description(xml, rule)
          return if rule.description.nil? || rule.description.empty?

          xml.description { xml.text rule.description }
        end
      end
    end
  end
end
