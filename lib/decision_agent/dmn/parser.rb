require "nokogiri"
require "securerandom"
require_relative "model"
require_relative "errors"

module DecisionAgent
  module Dmn
    # Parses DMN 1.3 XML files into Ruby model objects
    class Parser
      NAMESPACES = {
        "dmn" => "https://www.omg.org/spec/DMN/20191111/MODEL/",
        "dmn11" => "http://www.omg.org/spec/DMN/20151101/dmn.xsd",
        "dmn13" => "https://www.omg.org/spec/DMN/20191111/MODEL/"
      }.freeze

      def initialize(xml_content)
        @xml_content = xml_content
        @doc = nil
        @namespace = nil
      end

      def parse
        parse_xml
        extract_model
      end

      private

      def parse_xml
        @doc = Nokogiri::XML(@xml_content)

        if @doc.errors.any?
          raise InvalidDmnXmlError,
                "XML parsing failed: #{@doc.errors.map(&:to_s).join(', ')}"
        end

        # Detect namespace
        @namespace = detect_namespace
      end

      def detect_namespace
        if @doc.root.namespace&.href&.include?("20191111")
          NAMESPACES["dmn13"]
        elsif @doc.root.namespace&.href&.include?("20151101")
          NAMESPACES["dmn11"]
        else
          # Default to DMN 1.3
          NAMESPACES["dmn13"]
        end
      end

      def extract_model
        definitions = @doc.at_xpath("//dmn:definitions", NAMESPACES) ||
                      @doc.at_xpath("//*[local-name()='definitions']")

        raise InvalidDmnXmlError, "No definitions element found" unless definitions

        model = Model.new(
          id: definitions["id"] || "model",
          name: definitions["name"] || "DMN Model",
          namespace: definitions["namespace"] || @namespace
        )

        # Parse all decisions
        decisions = @doc.xpath("//dmn:decision", NAMESPACES)
        decisions = @doc.xpath("//*[local-name()='decision']") if decisions.empty?

        decisions.each do |decision_node|
          decision = parse_decision(decision_node)
          model.add_decision(decision)
        end

        model.freeze
        model
      end

      def parse_decision(node)
        decision = Decision.new(
          id: node["id"] || SecureRandom.uuid,
          name: node["name"] || "Unnamed Decision",
          description: extract_description(node)
        )

        # Parse decision table if present
        table_node = node.at_xpath(".//dmn:decisionTable", NAMESPACES) ||
                     node.at_xpath(".//*[local-name()='decisionTable']")

        if table_node
          decision.decision_table = parse_decision_table(table_node)
        end

        decision.freeze
        decision
      end

      def parse_decision_table(node)
        table = DecisionTable.new(
          id: node["id"] || SecureRandom.uuid,
          hit_policy: node["hitPolicy"] || "UNIQUE"
        )

        # Parse inputs
        inputs = node.xpath(".//dmn:input", NAMESPACES)
        inputs = node.xpath(".//*[local-name()='input']") if inputs.empty?

        inputs.each do |input_node|
          table.add_input(parse_input(input_node))
        end

        # Parse outputs
        outputs = node.xpath(".//dmn:output", NAMESPACES)
        outputs = node.xpath(".//*[local-name()='output']") if outputs.empty?

        outputs.each do |output_node|
          table.add_output(parse_output(output_node))
        end

        # Parse rules
        rules = node.xpath(".//dmn:rule", NAMESPACES)
        rules = node.xpath(".//*[local-name()='rule']") if rules.empty?

        rules.each do |rule_node|
          table.add_rule(parse_rule(rule_node))
        end

        table.freeze
        table
      end

      def parse_input(node)
        input_expr = node.at_xpath(".//dmn:inputExpression", NAMESPACES) ||
                     node.at_xpath(".//*[local-name()='inputExpression']")

        text_node = input_expr&.at_xpath(".//dmn:text", NAMESPACES) ||
                    input_expr&.at_xpath(".//*[local-name()='text']")

        Input.new(
          id: node["id"] || SecureRandom.uuid,
          label: node["label"] || text_node&.text || "Input",
          expression: text_node&.text,
          type_ref: input_expr&.[]("typeRef") || "string"
        ).freeze
      end

      def parse_output(node)
        Output.new(
          id: node["id"] || SecureRandom.uuid,
          label: node["label"] || node["name"] || "Output",
          name: node["name"] || node["label"] || "output",
          type_ref: node["typeRef"] || "string"
        ).freeze
      end

      def parse_rule(node)
        rule = Rule.new(
          id: node["id"] || SecureRandom.uuid,
          description: extract_description(node)
        )

        # Parse input entries
        input_entries = node.xpath(".//dmn:inputEntry", NAMESPACES)
        input_entries = node.xpath(".//*[local-name()='inputEntry']") if input_entries.empty?

        input_entries.each do |entry_node|
          text_node = entry_node.at_xpath(".//dmn:text", NAMESPACES) ||
                      entry_node.at_xpath(".//*[local-name()='text']")
          text = text_node&.text || "-"
          rule.add_input_entry(text)
        end

        # Parse output entries
        output_entries = node.xpath(".//dmn:outputEntry", NAMESPACES)
        output_entries = node.xpath(".//*[local-name()='outputEntry']") if output_entries.empty?

        output_entries.each do |entry_node|
          text_node = entry_node.at_xpath(".//dmn:text", NAMESPACES) ||
                      entry_node.at_xpath(".//*[local-name()='text']")
          text = text_node&.text
          rule.add_output_entry(text)
        end

        rule.freeze
        rule
      end

      def extract_description(node)
        desc_node = node.at_xpath(".//dmn:description", NAMESPACES) ||
                    node.at_xpath(".//*[local-name()='description']")
        desc_node&.text
      end
    end
  end
end
