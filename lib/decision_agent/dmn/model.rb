require_relative "errors"

module DecisionAgent
  module Dmn
    # Root DMN model containing all decisions
    class Model
      attr_reader :id, :name, :namespace, :decisions

      def initialize(id:, name:, namespace: "http://decision_agent.local")
        @id = id.to_s
        @name = name.to_s
        @namespace = namespace.to_s
        @decisions = []
      end

      def add_decision(decision)
        raise TypeError, "Expected Decision, got #{decision.class}" unless decision.is_a?(Decision)

        @decisions << decision
      end

      def find_decision(decision_id)
        @decisions.find { |d| d.id == decision_id.to_s }
      end

      def freeze
        @id.freeze
        @name.freeze
        @namespace.freeze
        @decisions.each(&:freeze)
        @decisions.freeze
        super
      end
    end

    # Represents a single decision element
    class Decision
      attr_reader :id, :name, :decision_table, :description

      def initialize(id:, name:, description: nil)
        @id = id.to_s
        @name = name.to_s
        @description = description&.to_s
        @decision_table = nil
      end

      def decision_table=(table)
        raise TypeError, "Expected DecisionTable, got #{table.class}" unless table.is_a?(DecisionTable)

        @decision_table = table
      end

      def freeze
        @id.freeze
        @name.freeze
        @description.freeze
        @decision_table&.freeze
        super
      end
    end

    # Decision table with inputs, outputs, rules, and hit policy
    class DecisionTable
      attr_reader :id, :hit_policy, :inputs, :outputs, :rules

      VALID_HIT_POLICIES = %w[UNIQUE FIRST PRIORITY ANY COLLECT].freeze

      def initialize(id:, hit_policy: "UNIQUE")
        @id = id.to_s
        validate_hit_policy!(hit_policy)
        @hit_policy = hit_policy.to_s
        @inputs = []
        @outputs = []
        @rules = []
      end

      def add_input(input)
        raise TypeError, "Expected Input, got #{input.class}" unless input.is_a?(Input)

        @inputs << input
      end

      def add_output(output)
        raise TypeError, "Expected Output, got #{output.class}" unless output.is_a?(Output)

        @outputs << output
      end

      def add_rule(rule)
        raise TypeError, "Expected Rule, got #{rule.class}" unless rule.is_a?(Rule)

        @rules << rule
      end

      def freeze
        @id.freeze
        @hit_policy.freeze
        @inputs.each(&:freeze)
        @inputs.freeze
        @outputs.each(&:freeze)
        @outputs.freeze
        @rules.each(&:freeze)
        @rules.freeze
        super
      end

      private

      def validate_hit_policy!(policy)
        return if VALID_HIT_POLICIES.include?(policy.to_s)

        raise UnsupportedHitPolicyError,
              "Hit policy '#{policy}' not supported. " \
              "Supported: #{VALID_HIT_POLICIES.join(', ')}"
      end
    end

    # Input clause (column) in decision table
    class Input
      attr_reader :id, :label, :expression, :type_ref

      def initialize(id:, label:, expression: nil, type_ref: "string")
        @id = id.to_s
        @label = label.to_s
        @expression = expression&.to_s || label.to_s
        @type_ref = type_ref.to_s
      end

      def freeze
        @id.freeze
        @label.freeze
        @expression.freeze
        @type_ref.freeze
        super
      end
    end

    # Output clause (result column) in decision table
    class Output
      attr_reader :id, :label, :name, :type_ref

      def initialize(id:, label:, name: nil, type_ref: "string")
        @id = id.to_s
        @label = label.to_s
        @name = (name || label).to_s
        @type_ref = type_ref.to_s
      end

      def freeze
        @id.freeze
        @label.freeze
        @name.freeze
        @type_ref.freeze
        super
      end
    end

    # Decision table rule (row)
    class Rule
      attr_reader :id, :input_entries, :output_entries, :description

      def initialize(id:, description: nil)
        @id = id.to_s
        @description = description&.to_s
        @input_entries = []
        @output_entries = []
      end

      def add_input_entry(entry)
        @input_entries << entry.to_s
      end

      def add_output_entry(entry)
        @output_entries << entry
      end

      def freeze
        @id.freeze
        @description.freeze
        @input_entries.each(&:freeze)
        @input_entries.freeze
        @output_entries.map { |e| e.freeze if e.respond_to?(:freeze) }
        @output_entries.freeze
        super
      end
    end
  end
end
