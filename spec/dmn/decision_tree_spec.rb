# frozen_string_literal: true

require 'spec_helper'
require 'decision_agent/dmn/decision_tree'

RSpec.describe DecisionAgent::Dmn::DecisionTree do
  describe 'basic tree structure' do
    let(:tree) do
      described_class.new(id: 'tree1', name: 'Loan Approval Tree')
    end

    it 'creates a tree with root node' do
      expect(tree.root).to be_a(DecisionAgent::Dmn::TreeNode)
      expect(tree.root.id).to eq('root')
    end

    it 'allows adding children to nodes' do
      child1 = DecisionAgent::Dmn::TreeNode.new(id: 'child1', label: 'Check Age')
      tree.root.add_child(child1)

      expect(tree.root.children).to include(child1)
      expect(child1.parent).to eq(tree.root)
    end
  end

  describe 'tree evaluation' do
    let(:tree) do
      # Build a simple decision tree for loan approval
      tree = described_class.new(id: 'loan_tree', name: 'Loan Approval')

      # Root node
      root = tree.root

      # First level - check age
      age_check = DecisionAgent::Dmn::TreeNode.new(
        id: 'age_check',
        label: 'Age >= 18?',
        condition: 'age >= 18'
      )
      root.add_child(age_check)

      # Second level under age check - check credit score
      good_credit = DecisionAgent::Dmn::TreeNode.new(
        id: 'good_credit',
        label: 'Credit Score >= 650?',
        condition: 'credit_score >= 650'
      )
      age_check.add_child(good_credit)

      # Leaf nodes - decisions
      approved = DecisionAgent::Dmn::TreeNode.new(
        id: 'approved',
        label: 'Approved',
        decision: 'Approved'
      )
      good_credit.add_child(approved)

      rejected_credit = DecisionAgent::Dmn::TreeNode.new(
        id: 'rejected_credit',
        label: 'Rejected - Poor Credit',
        decision: 'Rejected - Poor Credit'
      )
      good_credit.add_child(rejected_credit)

      # Rejected for age
      rejected_age = DecisionAgent::Dmn::TreeNode.new(
        id: 'rejected_age',
        label: 'Rejected - Too Young',
        decision: 'Rejected - Too Young'
      )
      root.add_child(rejected_age)

      tree
    end

    it 'evaluates tree with context matching approved path' do
      context = { age: 25, credit_score: 700 }
      result = tree.evaluate(context)
      expect(result).to eq('Approved')
    end

    it 'evaluates tree with poor credit' do
      context = { age: 25, credit_score: 600 }
      result = tree.evaluate(context)
      expect(result).to eq('Rejected - Poor Credit')
    end

    it 'evaluates tree with age too young' do
      context = { age: 16, credit_score: 700 }
      result = tree.evaluate(context)
      expect(result).to eq('Rejected - Too Young')
    end

    it 'returns nil when no path matches' do
      context = {}
      result = tree.evaluate(context)
      expect(result).to be_nil
    end
  end

  describe 'tree serialization' do
    let(:tree_hash) do
      {
        id: 'test_tree',
        name: 'Test Tree',
        root: {
          id: 'root',
          label: 'Root',
          condition: nil,
          decision: nil,
          children: [
            {
              id: 'node1',
              label: 'Node 1',
              condition: 'x > 5',
              decision: nil,
              children: [
                {
                  id: 'leaf1',
                  label: 'Leaf 1',
                  condition: nil,
                  decision: 'Result A',
                  children: []
                }
              ]
            }
          ]
        }
      }
    end

    it 'converts tree to hash' do
      tree = described_class.new(id: 'tree1', name: 'Tree 1')
      node1 = DecisionAgent::Dmn::TreeNode.new(id: 'node1', condition: 'x > 5')
      tree.root.add_child(node1)

      hash = tree.to_h
      expect(hash[:id]).to eq('tree1')
      expect(hash[:name]).to eq('Tree 1')
      expect(hash[:root][:children].length).to eq(1)
    end

    it 'builds tree from hash' do
      tree = described_class.from_hash(tree_hash)

      expect(tree.id).to eq('test_tree')
      expect(tree.name).to eq('Test Tree')
      expect(tree.root.children.length).to eq(1)
      expect(tree.root.children.first.id).to eq('node1')
    end
  end

  describe 'tree analysis' do
    let(:tree) do
      tree = described_class.new(id: 'analysis_tree', name: 'Analysis Tree')

      level1 = DecisionAgent::Dmn::TreeNode.new(id: 'level1')
      tree.root.add_child(level1)

      level2a = DecisionAgent::Dmn::TreeNode.new(id: 'level2a')
      level2b = DecisionAgent::Dmn::TreeNode.new(id: 'level2b')
      level1.add_child(level2a)
      level1.add_child(level2b)

      leaf1 = DecisionAgent::Dmn::TreeNode.new(id: 'leaf1', decision: 'Result 1')
      leaf2 = DecisionAgent::Dmn::TreeNode.new(id: 'leaf2', decision: 'Result 2')
      level2a.add_child(leaf1)
      level2b.add_child(leaf2)

      tree
    end

    it 'collects all leaf nodes' do
      leaves = tree.leaf_nodes
      expect(leaves.length).to eq(2)
      expect(leaves.map(&:id)).to include('leaf1', 'leaf2')
    end

    it 'calculates tree depth' do
      expect(tree.depth).to eq(3) # root -> level1 -> level2 -> leaf (depth 3)
    end

    it 'collects all paths from root to leaves' do
      paths = tree.paths
      expect(paths.length).to eq(2)
      expect(paths.first.length).to be >= 3
    end
  end

  describe DecisionAgent::Dmn::TreeNode do
    it 'identifies leaf nodes correctly' do
      node = DecisionAgent::Dmn::TreeNode.new(id: 'test', decision: 'Decision')
      expect(node.leaf?).to be true
    end

    it 'identifies non-leaf nodes correctly' do
      node = DecisionAgent::Dmn::TreeNode.new(id: 'test')
      child = DecisionAgent::Dmn::TreeNode.new(id: 'child')
      node.add_child(child)
      expect(node.leaf?).to be false
    end
  end
end
