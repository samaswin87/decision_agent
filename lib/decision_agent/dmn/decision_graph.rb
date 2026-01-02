# frozen_string_literal: true

require_relative "feel/evaluator"
require_relative "errors"
require_relative "decision_tree"

module DecisionAgent
  module Dmn
    # Represents a decision in a decision graph
    class DecisionNode
      attr_reader :id, :name, :decision_logic, :information_requirements
      attr_accessor :value, :evaluated

      def initialize(id:, name:, decision_logic: nil)
        @id = id
        @name = name
        @decision_logic = decision_logic # Can be DecisionTable, DecisionTree, or literal
        @information_requirements = [] # Dependencies on other decisions
        @value = nil
        @evaluated = false
      end

      def add_dependency(decision_id, variable_name = nil)
        @information_requirements << {
          decision_id: decision_id,
          variable_name: variable_name || decision_id
        }
      end

      def depends_on?(decision_id)
        @information_requirements.any? { |req| req[:decision_id] == decision_id }
      end

      def reset!
        @value = nil
        @evaluated = false
      end

      def to_h
        {
          id: @id,
          name: @name,
          information_requirements: @information_requirements,
          decision_logic_type: decision_logic_type
        }
      end

      private

      def decision_logic_type
        case @decision_logic
        when DecisionTree
          'decision_tree'
        when Hash
          'decision_table'
        else
          'literal'
        end
      end
    end

    # Represents and evaluates a decision graph (DMN model with multiple decisions)
    class DecisionGraph
      attr_reader :id, :name, :decisions

      def initialize(id:, name:)
        @id = id
        @name = name
        @decisions = {} # decision_id => DecisionNode
        @feel_evaluator = Feel::Evaluator.new
      end

      def add_decision(decision)
        @decisions[decision.id] = decision
      end

      def get_decision(decision_id)
        @decisions[decision_id]
      end

      # Evaluate a specific decision (and all its dependencies)
      def evaluate(decision_id, context)
        decision = @decisions[decision_id]
        raise DmnError, "Decision '#{decision_id}' not found" unless decision

        # Reset all decision evaluations
        reset_all!

        # Build evaluation context
        eval_context = context.is_a?(Hash) ? context : context.to_h

        # Evaluate the requested decision (will recursively evaluate dependencies)
        evaluate_decision(decision, eval_context)
      end

      # Evaluate all decisions in the graph
      def evaluate_all(context)
        reset_all!
        eval_context = context.is_a?(Hash) ? context : context.to_h

        results = {}
        @decisions.each do |decision_id, decision|
          results[decision_id] = evaluate_decision(decision, eval_context) unless decision.evaluated
        end

        results
      end

      # Get decisions in topological order (respecting dependencies)
      def topological_order
        order = []
        visited = Set.new
        temp_mark = Set.new

        visit = ->(decision_id) do
          return if visited.include?(decision_id)

          if temp_mark.include?(decision_id)
            raise DmnError, "Circular dependency detected involving decision '#{decision_id}'"
          end

          temp_mark.add(decision_id)

          decision = @decisions[decision_id]
          decision.information_requirements.each do |req|
            visit.call(req[:decision_id]) if @decisions[req[:decision_id]]
          end

          temp_mark.delete(decision_id)
          visited.add(decision_id)
          order << decision_id
        end

        @decisions.keys.each { |decision_id| visit.call(decision_id) }
        order
      end

      # Detect circular dependencies
      def has_circular_dependencies?
        topological_order
        false
      rescue DmnError => e
        e.message.include?("Circular dependency")
      end

      # Get all leaf decisions (no other decisions depend on them)
      def leaf_decisions
        dependent_decisions = Set.new
        @decisions.each_value do |decision|
          decision.information_requirements.each do |req|
            dependent_decisions.add(req[:decision_id])
          end
        end

        @decisions.keys.reject { |id| dependent_decisions.include?(id) }
      end

      # Get all root decisions (don't depend on other decisions)
      def root_decisions
        @decisions.select { |_id, decision| decision.information_requirements.empty? }.keys
      end

      # Get the dependency graph as a hash
      def dependency_graph
        graph = {}
        @decisions.each do |id, decision|
          graph[id] = decision.information_requirements.map { |req| req[:decision_id] }
        end
        graph
      end

      # Export graph structure
      def to_h
        {
          id: @id,
          name: @name,
          decisions: @decisions.transform_values(&:to_h),
          dependency_graph: dependency_graph
        }
      end

      private

      def reset_all!
        @decisions.each_value(&:reset!)
      end

      def evaluate_decision(decision, context)
        # If already evaluated, return cached value
        return decision.value if decision.evaluated

        # First, evaluate all dependencies
        decision.information_requirements.each do |req|
          dep_decision = @decisions[req[:decision_id]]
          next unless dep_decision

          # Recursively evaluate dependency
          dep_value = evaluate_decision(dep_decision, context)

          # Add dependency result to context with the specified variable name
          context[req[:variable_name]] = dep_value
        end

        # Now evaluate this decision with the enriched context
        decision.value = evaluate_decision_logic(decision, context)
        decision.evaluated = true
        decision.value
      end

      def evaluate_decision_logic(decision, context)
        case decision.decision_logic
        when DecisionTree
          # Evaluate decision tree
          decision.decision_logic.evaluate(context)
        when Hash
          # Evaluate decision table (simplified)
          evaluate_decision_table(decision.decision_logic, context)
        when String
          # Evaluate as FEEL expression (literal expression)
          @feel_evaluator.evaluate(decision.decision_logic, context)
        when Proc
          # Execute custom logic
          decision.decision_logic.call(context)
        else
          # Return as-is
          decision.decision_logic
        end
      rescue StandardError => e
        raise DmnError, "Failed to evaluate decision '#{decision.id}': #{e.message}"
      end

      def evaluate_decision_table(table, context)
        # Simplified decision table evaluation
        # In a full implementation, this would delegate to the DecisionTable evaluator
        rules = table[:rules] || []

        matching_rule = rules.find do |rule|
          rule[:conditions].all? do |input_id, condition|
            value = context[input_id]
            evaluate_condition(condition, value, context)
          end
        end

        matching_rule ? matching_rule[:output] : nil
      end

      def evaluate_condition(condition, value, context)
        return true if condition.nil? || condition == '-'

        @feel_evaluator.evaluate(
          "#{value} #{condition}",
          context
        )
      rescue
        false
      end
    end

    # Parser for DMN decision graphs from XML
    class DecisionGraphParser
      def self.parse(xml_doc)
        # Extract namespace and model info
        definitions = xml_doc.at_xpath('//dmn:definitions') || xml_doc.root
        model_id = definitions['id'] || 'decision_graph'
        model_name = definitions['name'] || model_id

        graph = DecisionGraph.new(id: model_id, name: model_name)

        # Parse all decisions
        decisions = xml_doc.xpath('//dmn:decision')
        decisions.each do |decision_xml|
          decision_node = parse_decision_node(decision_xml)
          graph.add_decision(decision_node)
        end

        # Parse information requirements (dependencies)
        decisions.each do |decision_xml|
          decision_id = decision_xml['id']
          decision_node = graph.get_decision(decision_id)

          # Find all information requirements
          info_reqs = decision_xml.xpath('.//dmn:informationRequirement')
          info_reqs.each do |req|
            required_decision = req.at_xpath('.//dmn:requiredDecision')
            if required_decision
              required_id = required_decision['href']&.sub('#', '')
              decision_node.add_dependency(required_id) if required_id
            end
          end
        end

        graph
      end

      def self.parse_decision_node(decision_xml)
        decision_id = decision_xml['id']
        decision_name = decision_xml['name'] || decision_id

        # Check for decision table
        decision_table = decision_xml.at_xpath('.//dmn:decisionTable')
        if decision_table
          # Parse decision table (simplified)
          decision_logic = parse_decision_table(decision_table)
        else
          # Check for literal expression (could be decision tree or simple expression)
          literal_expr = decision_xml.at_xpath('.//dmn:literalExpression')
          decision_logic = literal_expr ? literal_expr.text.strip : nil
        end

        DecisionNode.new(
          id: decision_id,
          name: decision_name,
          decision_logic: decision_logic
        )
      end

      def self.parse_decision_table(table_xml)
        # Simplified decision table parsing
        # Full implementation would use the existing DecisionTable parser
        {
          type: 'decision_table',
          hit_policy: table_xml['hitPolicy'] || 'UNIQUE',
          inputs: [],
          rules: []
        }
      end
    end
  end
end
