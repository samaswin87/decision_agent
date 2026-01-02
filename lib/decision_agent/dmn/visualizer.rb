# frozen_string_literal: true

require_relative "decision_tree"
require_relative "decision_graph"

module DecisionAgent
  module Dmn
    # Generates visual representations of decision trees and graphs
    class Visualizer
      # Generate SVG representation of a decision tree
      def self.tree_to_svg(decision_tree)
        svg_generator = TreeSvgGenerator.new(decision_tree)
        svg_generator.generate
      end

      # Generate DOT (Graphviz) representation of a decision tree
      def self.tree_to_dot(decision_tree)
        dot_generator = TreeDotGenerator.new(decision_tree)
        dot_generator.generate
      end

      # Generate SVG representation of a decision graph
      def self.graph_to_svg(decision_graph)
        svg_generator = GraphSvgGenerator.new(decision_graph)
        svg_generator.generate
      end

      # Generate DOT (Graphviz) representation of a decision graph
      def self.graph_to_dot(decision_graph)
        dot_generator = GraphDotGenerator.new(decision_graph)
        dot_generator.generate
      end

      # Generate Mermaid diagram syntax for a decision tree
      def self.tree_to_mermaid(decision_tree)
        mermaid_generator = TreeMermaidGenerator.new(decision_tree)
        mermaid_generator.generate
      end

      # Generate Mermaid diagram syntax for a decision graph
      def self.graph_to_mermaid(decision_graph)
        mermaid_generator = GraphMermaidGenerator.new(decision_graph)
        mermaid_generator.generate
      end
    end

    # Generates SVG for decision trees
    class TreeSvgGenerator
      NODE_WIDTH = 150
      NODE_HEIGHT = 60
      HORIZONTAL_SPACING = 40
      VERTICAL_SPACING = 100

      def initialize(decision_tree)
        @tree = decision_tree
        @positions = {}
      end

      def generate
        calculate_positions(@tree.root, 0, 0)

        width = (@positions.values.map { |p| p[:x] }.max || 0) + NODE_WIDTH + 40
        height = (@positions.values.map { |p| p[:y] }.max || 0) + NODE_HEIGHT + 40

        svg = [
          %(<svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}">),
          '<defs>',
          '  <marker id="arrowhead" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">',
          '    <polygon points="0 0, 10 3, 0 6" fill="#666" />',
          '  </marker>',
          '</defs>',
          '<g>'
        ]

        # Draw edges first (so they appear behind nodes)
        svg.concat(generate_edges)

        # Draw nodes
        svg.concat(generate_nodes)

        svg << '</g>'
        svg << '</svg>'
        svg.join("\n")
      end

      private

      def calculate_positions(node, depth, offset)
        @positions[node.id] = {
          x: offset + NODE_WIDTH / 2,
          y: depth * (NODE_HEIGHT + VERTICAL_SPACING) + 20
        }

        if node.children.any?
          child_width = calculate_subtree_width(node)
          child_offset = offset

          node.children.each do |child|
            calculate_positions(child, depth + 1, child_offset)
            child_offset += calculate_subtree_width(child) + HORIZONTAL_SPACING
          end
        end
      end

      def calculate_subtree_width(node)
        return NODE_WIDTH if node.leaf?

        total_width = 0
        node.children.each do |child|
          total_width += calculate_subtree_width(child) + HORIZONTAL_SPACING
        end
        total_width - HORIZONTAL_SPACING
      end

      def generate_nodes
        nodes = []
        @positions.each do |node_id, pos|
          node = find_node(@tree.root, node_id)
          next unless node

          x = pos[:x] - NODE_WIDTH / 2
          y = pos[:y]

          # Node background
          color = node.leaf? ? '#e8f5e9' : '#e3f2fd'
          nodes << %(<rect x="#{x}" y="#{y}" width="#{NODE_WIDTH}" height="#{NODE_HEIGHT}" )
          nodes << %(fill="#{color}" stroke="#666" stroke-width="2" rx="5"/>)

          # Node label
          label = node.label || node.id
          label = truncate(label, 20)
          nodes << %(<text x="#{pos[:x]}" y="#{y + 25}" text-anchor="middle" )
          nodes << %(font-family="Arial, sans-serif" font-size="12" font-weight="bold">#{escape_xml(label)}</text>)

          # Node condition or decision
          if node.condition
            condition_text = truncate(node.condition, 18)
            nodes << %(<text x="#{pos[:x]}" y="#{y + 45}" text-anchor="middle" )
            nodes << %(font-family="Arial, sans-serif" font-size="10" fill="#666">#{escape_xml(condition_text)}</text>)
          elsif node.decision
            decision_text = truncate(node.decision.to_s, 18)
            nodes << %(<text x="#{pos[:x]}" y="#{y + 45}" text-anchor="middle" )
            nodes << %(font-family="Arial, sans-serif" font-size="10" fill="#2e7d32">#{escape_xml(decision_text)}</text>)
          end
        end
        nodes
      end

      def generate_edges
        edges = []
        generate_edges_recursive(@tree.root, edges)
        edges
      end

      def generate_edges_recursive(node, edges)
        return if node.leaf?

        from_pos = @positions[node.id]
        node.children.each do |child|
          to_pos = @positions[child.id]

          # Draw line from center bottom of parent to center top of child
          x1 = from_pos[:x]
          y1 = from_pos[:y] + NODE_HEIGHT
          x2 = to_pos[:x]
          y2 = to_pos[:y]

          edges << %(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" )
          edges << %(stroke="#666" stroke-width="2" marker-end="url(#arrowhead)"/>)

          generate_edges_recursive(child, edges)
        end
      end

      def find_node(current, node_id)
        return current if current.id == node_id

        current.children.each do |child|
          found = find_node(child, node_id)
          return found if found
        end

        nil
      end

      def truncate(text, max_length)
        text.to_s.length > max_length ? "#{text.to_s[0...max_length]}..." : text.to_s
      end

      def escape_xml(text)
        text.to_s
          .gsub('&', '&amp;')
          .gsub('<', '&lt;')
          .gsub('>', '&gt;')
          .gsub('"', '&quot;')
          .gsub("'", '&apos;')
      end
    end

    # Generates DOT format for decision trees (for Graphviz)
    class TreeDotGenerator
      def initialize(decision_tree)
        @tree = decision_tree
      end

      def generate
        dot = ["digraph decision_tree {"]
        dot << "  graph [rankdir=TB, splines=ortho];"
        dot << "  node [shape=box, style=rounded];"

        generate_nodes(@tree.root, dot)
        generate_edges(@tree.root, dot)

        dot << "}"
        dot.join("\n")
      end

      private

      def generate_nodes(node, dot)
        label = escape_dot(node.label || node.id)

        if node.leaf?
          decision = escape_dot(node.decision.to_s)
          dot << %(  "#{node.id}" [label="#{label}\\n→ #{decision}", fillcolor=lightgreen, style="rounded,filled"];)
        else
          condition = node.condition ? escape_dot(node.condition) : ""
          dot << %(  "#{node.id}" [label="#{label}\\n#{condition}", fillcolor=lightblue, style="rounded,filled"];)
        end

        node.children.each { |child| generate_nodes(child, dot) }
      end

      def generate_edges(node, dot)
        node.children.each do |child|
          dot << %(  "#{node.id}" -> "#{child.id}";)
          generate_edges(child, dot)
        end
      end

      def escape_dot(text)
        text.to_s.gsub('"', '\\"').gsub("\n", '\\n')
      end
    end

    # Generates SVG for decision graphs
    class GraphSvgGenerator
      NODE_WIDTH = 180
      NODE_HEIGHT = 70
      HORIZONTAL_SPACING = 100
      VERTICAL_SPACING = 120

      def initialize(decision_graph)
        @graph = decision_graph
        @positions = {}
      end

      def generate
        calculate_graph_layout

        width = (@positions.values.map { |p| p[:x] }.max || 0) + NODE_WIDTH + 40
        height = (@positions.values.map { |p| p[:y] }.max || 0) + NODE_HEIGHT + 40

        svg = [
          %(<svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}">),
          '<defs>',
          '  <marker id="arrowhead" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">',
          '    <polygon points="0 0, 10 3, 0 6" fill="#666" />',
          '  </marker>',
          '</defs>',
          '<g>'
        ]

        # Draw edges
        svg.concat(generate_edges)

        # Draw nodes
        svg.concat(generate_nodes)

        svg << '</g>'
        svg << '</svg>'
        svg.join("\n")
      end

      private

      def calculate_graph_layout
        # Use topological sort to arrange nodes in layers
        begin
          order = @graph.topological_order
        rescue
          # If circular, just use the order as-is
          order = @graph.decisions.keys
        end

        # Group nodes by layer (based on dependency depth)
        layers = assign_layers(order)

        # Position nodes
        layers.each_with_index do |layer_nodes, layer_index|
          layer_nodes.each_with_index do |node_id, node_index|
            @positions[node_id] = {
              x: node_index * (NODE_WIDTH + HORIZONTAL_SPACING) + 40,
              y: layer_index * (NODE_HEIGHT + VERTICAL_SPACING) + 40
            }
          end
        end
      end

      def assign_layers(order)
        layers = {}

        order.each do |decision_id|
          decision = @graph.get_decision(decision_id)

          # Find max layer of dependencies
          max_dep_layer = -1
          decision.information_requirements.each do |req|
            dep_layer = layers[req[:decision_id]]
            max_dep_layer = [max_dep_layer, dep_layer].max if dep_layer
          end

          layers[decision_id] = max_dep_layer + 1
        end

        # Group by layer
        grouped = {}
        layers.each do |decision_id, layer|
          grouped[layer] ||= []
          grouped[layer] << decision_id
        end

        grouped.sort.map { |_layer, nodes| nodes }
      end

      def generate_nodes
        nodes = []

        @graph.decisions.each do |decision_id, decision|
          pos = @positions[decision_id]
          next unless pos

          x = pos[:x]
          y = pos[:y]

          # Node background
          nodes << %(<rect x="#{x}" y="#{y}" width="#{NODE_WIDTH}" height="#{NODE_HEIGHT}" )
          nodes << %(fill="#fff3e0" stroke="#e65100" stroke-width="2" rx="5"/>)

          # Decision name
          name = truncate(decision.name, 22)
          nodes << %(<text x="#{x + NODE_WIDTH/2}" y="#{y + 25}" text-anchor="middle" )
          nodes << %(font-family="Arial, sans-serif" font-size="12" font-weight="bold">#{escape_xml(name)}</text>)

          # Decision ID
          nodes << %(<text x="#{x + NODE_WIDTH/2}" y="#{y + 45}" text-anchor="middle" )
          nodes << %(font-family="Arial, sans-serif" font-size="10" fill="#666">ID: #{escape_xml(decision_id)}</text>)
        end

        nodes
      end

      def generate_edges
        edges = []

        @graph.decisions.each do |decision_id, decision|
          from_pos = @positions[decision_id]
          next unless from_pos

          decision.information_requirements.each do |req|
            to_pos = @positions[req[:decision_id]]
            next unless to_pos

            # Draw arrow from dependency to this decision
            x1 = to_pos[:x] + NODE_WIDTH / 2
            y1 = to_pos[:y] + NODE_HEIGHT
            x2 = from_pos[:x] + NODE_WIDTH / 2
            y2 = from_pos[:y]

            edges << %(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" )
            edges << %(stroke="#666" stroke-width="2" marker-end="url(#arrowhead)"/>)

            # Add label for variable name if specified
            if req[:variable_name] && req[:variable_name] != req[:decision_id]
              mid_x = (x1 + x2) / 2
              mid_y = (y1 + y2) / 2
              edges << %(<text x="#{mid_x}" y="#{mid_y}" text-anchor="middle" )
              edges << %(font-family="Arial, sans-serif" font-size="10" fill="#e65100">#{escape_xml(req[:variable_name])}</text>)
            end
          end
        end

        edges
      end

      def truncate(text, max_length)
        text.to_s.length > max_length ? "#{text.to_s[0...max_length]}..." : text.to_s
      end

      def escape_xml(text)
        text.to_s
          .gsub('&', '&amp;')
          .gsub('<', '&lt;')
          .gsub('>', '&gt;')
          .gsub('"', '&quot;')
          .gsub("'", '&apos;')
      end
    end

    # Generates DOT format for decision graphs
    class GraphDotGenerator
      def initialize(decision_graph)
        @graph = decision_graph
      end

      def generate
        dot = ["digraph decision_graph {"]
        dot << "  graph [rankdir=TB];"
        dot << "  node [shape=box, style=rounded];"

        @graph.decisions.each do |decision_id, decision|
          label = escape_dot("#{decision.name}\\n(#{decision_id})")
          dot << %(  "#{decision_id}" [label="#{label}", fillcolor=lightyellow, style="rounded,filled"];)
        end

        @graph.decisions.each do |decision_id, decision|
          decision.information_requirements.each do |req|
            label = req[:variable_name] != req[:decision_id] ? escape_dot(req[:variable_name]) : ""
            label_attr = label.empty? ? "" : %( [label="#{label}"])
            dot << %(  "#{req[:decision_id]}" -> "#{decision_id}"#{label_attr};)
          end
        end

        dot << "}"
        dot.join("\n")
      end

      private

      def escape_dot(text)
        text.to_s.gsub('"', '\\"').gsub("\n", '\\n')
      end
    end

    # Generates Mermaid diagram syntax for decision trees
    class TreeMermaidGenerator
      def initialize(decision_tree)
        @tree = decision_tree
      end

      def generate
        mermaid = ["graph TD"]
        generate_nodes(@tree.root, mermaid)
        generate_edges(@tree.root, mermaid)
        mermaid.join("\n")
      end

      private

      def generate_nodes(node, mermaid)
        label = escape_mermaid(node.label || node.id)

        if node.leaf?
          decision = escape_mermaid(node.decision.to_s)
          mermaid << %(  #{node.id}["#{label}<br/>→ #{decision}"])
        else
          condition = node.condition ? escape_mermaid(node.condition) : ""
          mermaid << %(  #{node.id}["#{label}<br/>#{condition}"])
        end

        node.children.each { |child| generate_nodes(child, mermaid) }
      end

      def generate_edges(node, mermaid)
        node.children.each do |child|
          mermaid << %(  #{node.id} --> #{child.id})
          generate_edges(child, mermaid)
        end
      end

      def escape_mermaid(text)
        text.to_s.gsub('"', '&quot;')
      end
    end

    # Generates Mermaid diagram syntax for decision graphs
    class GraphMermaidGenerator
      def initialize(decision_graph)
        @graph = decision_graph
      end

      def generate
        mermaid = ["graph TD"]

        @graph.decisions.each do |decision_id, decision|
          label = escape_mermaid("#{decision.name}")
          mermaid << %(  #{decision_id}["#{label}"])
        end

        @graph.decisions.each do |decision_id, decision|
          decision.information_requirements.each do |req|
            label = req[:variable_name] != req[:decision_id] ? "|#{escape_mermaid(req[:variable_name])}|" : ""
            mermaid << %(  #{req[:decision_id]} -->#{label} #{decision_id})
          end
        end

        mermaid.join("\n")
      end

      private

      def escape_mermaid(text)
        text.to_s.gsub('"', '&quot;')
      end
    end
  end
end
