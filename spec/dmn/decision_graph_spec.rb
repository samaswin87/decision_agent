# frozen_string_literal: true

require 'spec_helper'
require 'decision_agent/dmn/decision_graph'

RSpec.describe DecisionAgent::Dmn::DecisionGraph do
  describe 'graph construction' do
    let(:graph) do
      described_class.new(id: 'graph1', name: 'Test Graph')
    end

    it 'creates an empty graph' do
      expect(graph.decisions).to be_empty
    end

    it 'adds decisions to the graph' do
      decision = DecisionAgent::Dmn::DecisionNode.new(
        id: 'decision1',
        name: 'First Decision'
      )
      graph.add_decision(decision)

      expect(graph.decisions['decision1']).to eq(decision)
    end

    it 'retrieves decisions by id' do
      decision = DecisionAgent::Dmn::DecisionNode.new(id: 'decision1', name: 'Test')
      graph.add_decision(decision)

      retrieved = graph.get_decision('decision1')
      expect(retrieved).to eq(decision)
    end
  end

  describe 'decision dependencies' do
    let(:graph) do
      graph = described_class.new(id: 'dep_graph', name: 'Dependency Graph')

      # Create decisions
      decision1 = DecisionAgent::Dmn::DecisionNode.new(
        id: 'base_rate',
        name: 'Base Rate',
        decision_logic: 0.05
      )

      decision2 = DecisionAgent::Dmn::DecisionNode.new(
        id: 'risk_adjustment',
        name: 'Risk Adjustment',
        decision_logic: 0.02
      )

      decision3 = DecisionAgent::Dmn::DecisionNode.new(
        id: 'final_rate',
        name: 'Final Rate',
        decision_logic: ->(context) { context['base_rate'] + context['risk_adjustment'] }
      )

      # Add dependencies
      decision3.add_dependency('base_rate')
      decision3.add_dependency('risk_adjustment')

      graph.add_decision(decision1)
      graph.add_decision(decision2)
      graph.add_decision(decision3)

      graph
    end

    it 'tracks decision dependencies' do
      decision = graph.get_decision('final_rate')
      expect(decision.information_requirements.length).to eq(2)
      expect(decision.depends_on?('base_rate')).to be true
      expect(decision.depends_on?('risk_adjustment')).to be true
    end

    it 'evaluates decision with dependencies' do
      result = graph.evaluate('final_rate', {})
      expect(result).to eq(0.07) # 0.05 + 0.02
    end
  end

  describe 'topological ordering' do
    let(:graph) do
      graph = described_class.new(id: 'topo_graph', name: 'Topological Graph')

      # Create a dependency chain: A -> B -> C
      decision_a = DecisionAgent::Dmn::DecisionNode.new(id: 'a', name: 'A', decision_logic: 1)
      decision_b = DecisionAgent::Dmn::DecisionNode.new(id: 'b', name: 'B', decision_logic: ->(ctx) { ctx['a'] + 1 })
      decision_c = DecisionAgent::Dmn::DecisionNode.new(id: 'c', name: 'C', decision_logic: ->(ctx) { ctx['b'] + 1 })

      decision_b.add_dependency('a')
      decision_c.add_dependency('b')

      graph.add_decision(decision_a)
      graph.add_decision(decision_b)
      graph.add_decision(decision_c)

      graph
    end

    it 'returns decisions in topological order' do
      order = graph.topological_order
      expect(order.index('a')).to be < order.index('b')
      expect(order.index('b')).to be < order.index('c')
    end

    it 'identifies root decisions' do
      roots = graph.root_decisions
      expect(roots).to eq(['a'])
    end

    it 'identifies leaf decisions' do
      leaves = graph.leaf_decisions
      expect(leaves).to eq(['c'])
    end
  end

  describe 'circular dependency detection' do
    it 'detects circular dependencies' do
      graph = described_class.new(id: 'circular', name: 'Circular Graph')

      decision_a = DecisionAgent::Dmn::DecisionNode.new(id: 'a', name: 'A')
      decision_b = DecisionAgent::Dmn::DecisionNode.new(id: 'b', name: 'B')

      decision_a.add_dependency('b')
      decision_b.add_dependency('a')

      graph.add_decision(decision_a)
      graph.add_decision(decision_b)

      expect(graph.has_circular_dependencies?).to be true
    end

    it 'raises error when evaluating circular dependencies' do
      graph = described_class.new(id: 'circular', name: 'Circular Graph')

      decision_a = DecisionAgent::Dmn::DecisionNode.new(id: 'a', name: 'A')
      decision_b = DecisionAgent::Dmn::DecisionNode.new(id: 'b', name: 'B')

      decision_a.add_dependency('b')
      decision_b.add_dependency('a')

      graph.add_decision(decision_a)
      graph.add_decision(decision_b)

      expect { graph.topological_order }.to raise_error(DecisionAgent::Dmn::DmnError, /Circular dependency/)
    end
  end

  describe 'complex graph evaluation' do
    let(:graph) do
      # Build a loan approval graph
      # Decisions: income_check -> credit_check -> final_decision
      graph = described_class.new(id: 'loan_graph', name: 'Loan Approval Graph')

      income_check = DecisionAgent::Dmn::DecisionNode.new(
        id: 'income_check',
        name: 'Income Check',
        decision_logic: ->(ctx) { ctx['income'] >= 50000 ? 'sufficient' : 'insufficient' }
      )

      credit_check = DecisionAgent::Dmn::DecisionNode.new(
        id: 'credit_check',
        name: 'Credit Check',
        decision_logic: ->(ctx) { ctx['credit_score'] >= 650 ? 'good' : 'poor' }
      )

      final_decision = DecisionAgent::Dmn::DecisionNode.new(
        id: 'final_decision',
        name: 'Final Decision',
        decision_logic: ->(ctx) do
          if ctx['income_check'] == 'sufficient' && ctx['credit_check'] == 'good'
            'Approved'
          else
            'Rejected'
          end
        end
      )

      final_decision.add_dependency('income_check', 'income_check')
      final_decision.add_dependency('credit_check', 'credit_check')

      graph.add_decision(income_check)
      graph.add_decision(credit_check)
      graph.add_decision(final_decision)

      graph
    end

    it 'evaluates graph with all dependencies for approved case' do
      context = { income: 60000, credit_score: 700 }
      result = graph.evaluate('final_decision', context)
      expect(result).to eq('Approved')
    end

    it 'evaluates graph with all dependencies for rejected case' do
      context = { income: 40000, credit_score: 600 }
      result = graph.evaluate('final_decision', context)
      expect(result).to eq('Rejected')
    end

    it 'evaluates all decisions in graph' do
      context = { income: 60000, credit_score: 700 }
      results = graph.evaluate_all(context)

      expect(results['income_check']).to eq('sufficient')
      expect(results['credit_check']).to eq('good')
      expect(results['final_decision']).to eq('Approved')
    end
  end

  describe 'graph analysis' do
    let(:graph) do
      graph = described_class.new(id: 'analysis', name: 'Analysis Graph')

      d1 = DecisionAgent::Dmn::DecisionNode.new(id: 'd1', name: 'D1', decision_logic: 1)
      d2 = DecisionAgent::Dmn::DecisionNode.new(id: 'd2', name: 'D2', decision_logic: 2)
      d3 = DecisionAgent::Dmn::DecisionNode.new(id: 'd3', name: 'D3', decision_logic: 3)

      d3.add_dependency('d1')
      d3.add_dependency('d2')

      graph.add_decision(d1)
      graph.add_decision(d2)
      graph.add_decision(d3)

      graph
    end

    it 'exports dependency graph structure' do
      dep_graph = graph.dependency_graph
      expect(dep_graph['d1']).to eq([])
      expect(dep_graph['d2']).to eq([])
      expect(dep_graph['d3']).to contain_exactly('d1', 'd2')
    end

    it 'exports graph to hash representation' do
      hash = graph.to_h
      expect(hash[:id]).to eq('analysis')
      expect(hash[:name]).to eq('Analysis Graph')
      expect(hash[:decisions].keys).to contain_exactly('d1', 'd2', 'd3')
      expect(hash[:dependency_graph]).to be_a(Hash)
    end
  end

  describe DecisionAgent::Dmn::DecisionNode do
    it 'creates decision node with basic attributes' do
      node = described_class.new(id: 'test', name: 'Test Decision')
      expect(node.id).to eq('test')
      expect(node.name).to eq('Test Decision')
      expect(node.information_requirements).to be_empty
    end

    it 'adds dependencies' do
      node = described_class.new(id: 'test', name: 'Test')
      node.add_dependency('dep1', 'variable1')

      expect(node.information_requirements.length).to eq(1)
      expect(node.information_requirements.first[:decision_id]).to eq('dep1')
      expect(node.information_requirements.first[:variable_name]).to eq('variable1')
    end

    it 'checks if node depends on another decision' do
      node = described_class.new(id: 'test', name: 'Test')
      node.add_dependency('dep1')

      expect(node.depends_on?('dep1')).to be true
      expect(node.depends_on?('dep2')).to be false
    end

    it 'resets evaluation state' do
      node = described_class.new(id: 'test', name: 'Test')
      node.value = 'some value'
      node.evaluated = true

      node.reset!

      expect(node.value).to be_nil
      expect(node.evaluated).to be false
    end
  end
end
