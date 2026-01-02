# frozen_string_literal: true

require_relative "errors"
require_relative "decision_tree"

module DecisionAgent
  module Dmn
    # Represents a decision graph with multiple interconnected decisions
    class DecisionGraph
      attr_reader :id, :name, :decisions, :dependencies

      def initialize(id:, name:)
        @id = id
        @name = name
        @decisions = {} # decision_id => decision object
        @dependencies = {} # decision_id => [required_decision_ids]
      end

      # Add a decision to the graph
      def add_decision(decision)
        @decisions[decision.id] = decision
      end

      # Add a dependency between decisions
      def add_dependency(decision_id, required_decision_id)
        @dependencies[decision_id] ||= []
        @dependencies[decision_id] << required_decision_id unless @dependencies[decision_id].include?(required_decision_id)
      end

      # Get execution order based on dependencies (topological sort)
      def execution_order
        sorted = []
        visited = Set.new
        temp_mark = Set.new

        @decisions.keys.each do |decision_id|
          visit(decision_id, visited, temp_mark, sorted) unless visited.include?(decision_id)
        end

        sorted
      end

      # Evaluate all decisions in the graph
      def evaluate(context)
        results = {}
        order = execution_order

        order.each do |decision_id|
          decision = @decisions[decision_id]

          # Build evaluation context with results from dependent decisions
          eval_context = context.to_h.dup
          if @dependencies[decision_id]
            @dependencies[decision_id].each do |dep_id|
              eval_context[dep_id] = results[dep_id]
            end
          end

          # Evaluate the decision
          results[decision_id] = evaluate_decision(decision, eval_context)
        end

        results
      end

      # Evaluate a specific decision and its dependencies
      def evaluate_decision_with_deps(decision_id, context)
        results = {}

        # Get all dependencies (transitive)
        deps = get_all_dependencies(decision_id)

        # Evaluate in dependency order
        deps.each do |dep_id|
          decision = @decisions[dep_id]
          eval_context = context.to_h.dup

          # Add results from already evaluated dependencies
          if @dependencies[dep_id]
            @dependencies[dep_id].each do |required_id|
              eval_context[required_id] = results[required_id] if results[required_id]
            end
          end

          results[dep_id] = evaluate_decision(decision, eval_context)
        end

        # Evaluate the target decision
        decision = @decisions[decision_id]
        eval_context = context.to_h.dup
        if @dependencies[decision_id]
          @dependencies[decision_id].each do |dep_id|
            eval_context[dep_id] = results[dep_id]
          end
        end

        evaluate_decision(decision, eval_context)
      end

      # Validate the graph (check for cycles, missing dependencies)
      def validate!
        # Check for missing decisions
        @dependencies.each do |decision_id, deps|
          deps.each do |dep_id|
            unless @decisions.key?(dep_id)
              raise InvalidDmnModelError, "Decision '#{decision_id}' depends on missing decision '#{dep_id}'"
            end
          end
        end

        # Check for cycles
        begin
          execution_order
        rescue => e
          raise InvalidDmnModelError, "Decision graph contains cycles: #{e.message}"
        end

        true
      end

      # Get visual representation of the graph
      def to_dot
        dot = ["digraph #{@id} {"]
        dot << "  label=\"#{@name}\";"
        dot << "  rankdir=TB;"
        dot << ""

        # Add decision nodes
        @decisions.each do |id, decision|
          label = decision.name || id
          dot << "  \"#{id}\" [label=\"#{label}\", shape=box];"
        end

        dot << ""

        # Add dependency edges
        @dependencies.each do |decision_id, deps|
          deps.each do |dep_id|
            dot << "  \"#{dep_id}\" -> \"#{decision_id}\";"
          end
        end

        dot << "}"
        dot.join("\n")
      end

      # Export graph structure
      def to_h
        {
          id: @id,
          name: @name,
          decisions: @decisions.transform_values { |d| d.respond_to?(:to_h) ? d.to_h : d },
          dependencies: @dependencies
        }
      end

      private

      def visit(decision_id, visited, temp_mark, sorted)
        if temp_mark.include?(decision_id)
          raise InvalidDmnModelError, "Circular dependency detected at decision '#{decision_id}'"
        end

        return if visited.include?(decision_id)

        temp_mark.add(decision_id)

        # Visit dependencies first
        if @dependencies[decision_id]
          @dependencies[decision_id].each do |dep_id|
            visit(dep_id, visited, temp_mark, sorted)
          end
        end

        temp_mark.delete(decision_id)
        visited.add(decision_id)
        sorted.unshift(decision_id)
      end

      def get_all_dependencies(decision_id, collected = Set.new)
        return collected if collected.include?(decision_id)

        if @dependencies[decision_id]
          @dependencies[decision_id].each do |dep_id|
            get_all_dependencies(dep_id, collected)
            collected.add(dep_id)
          end
        end

        collected
      end

      def evaluate_decision(decision, context)
        # This is a simplified evaluation
        # In a full implementation, this would handle different decision types
        # (decision tables, literal expressions, decision trees, etc.)

        if decision.respond_to?(:decision_table) && decision.decision_table
          # Use adapter to evaluate decision table
          adapter = Adapter.new(decision.decision_table)
          rules = adapter.to_json_rules
          # Would use JsonRuleEvaluator here in full implementation
          # For now, return a placeholder
          { decision: "evaluated", source: decision.id }
        elsif decision.respond_to?(:evaluate)
          decision.evaluate(context)
        else
          { decision: "unknown", source: decision.id }
        end
      end
    end

    # Builder for constructing decision graphs from DMN models
    class DecisionGraphBuilder
      def self.build_from_model(model)
        graph = DecisionGraph.new(id: model.id, name: model.name)

        # Add all decisions to the graph
        model.decisions.each do |decision|
          graph.add_decision(decision)
        end

        # Build dependencies from information requirements
        model.decisions.each do |decision|
          if decision.information_requirements
            decision.information_requirements.each do |req|
              # Information requirement points to a required decision
              graph.add_dependency(decision.id, req)
            end
          end
        end

        # Validate the graph
        graph.validate!

        graph
      end
    end
  end
end
