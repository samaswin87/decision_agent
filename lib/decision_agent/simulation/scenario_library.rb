module DecisionAgent
  module Simulation
    # Library of pre-defined test scenario templates
    class ScenarioLibrary
      # Get scenario template by name
      # @param template_name [String, Symbol] Template name
      # @return [Hash, nil] Scenario template or nil if not found
      def self.get_template(template_name)
        templates[template_name.to_sym] || templates[template_name.to_s]
      end

      # List all available templates
      # @return [Array<String>] Array of template names
      def self.list_templates
        templates.keys.map(&:to_s)
      end

      # Create scenario from template
      # @param template_name [String, Symbol] Template name
      # @param overrides [Hash] Values to override in template
      # @return [Hash] Scenario definition
      def self.create_scenario(template_name, overrides: {})
        template = get_template(template_name)
        raise ScenarioExecutionError, "Template not found: #{template_name}" unless template

        scenario = template.dup
        merge_overrides(scenario, overrides)
        scenario
      end

      # Get edge case scenarios for a given context structure
      # @param base_context [Hash] Base context to generate edge cases from
      # @return [Array<Hash>] Array of edge case scenarios
      def self.generate_edge_cases(base_context)
        scenarios = []

        # Generate scenarios with nil values
        base_context.each_key do |key|
          edge_scenario = base_context.dup
          edge_scenario[key] = nil
          scenarios << { context: edge_scenario, metadata: { type: "edge_case", field: key, value: "nil" } }
        end

        # Generate scenarios with extreme numeric values
        base_context.each do |key, value|
          next unless value.is_a?(Numeric)

          # Zero value
          zero_scenario = base_context.dup
          zero_scenario[key] = 0
          scenarios << { context: zero_scenario, metadata: { type: "edge_case", field: key, value: "zero" } }

          # Negative value (if positive)
          if value > 0
            neg_scenario = base_context.dup
            neg_scenario[key] = -value
            scenarios << { context: neg_scenario, metadata: { type: "edge_case", field: key, value: "negative" } }
          end

          # Very large value
          large_scenario = base_context.dup
          large_scenario[key] = value * 1000
          scenarios << { context: large_scenario, metadata: { type: "edge_case", field: key, value: "large" } }
        end

        # Generate scenarios with empty strings
        base_context.each do |key, value|
          next unless value.is_a?(String)

          empty_scenario = base_context.dup
          empty_scenario[key] = ""
          scenarios << { context: empty_scenario, metadata: { type: "edge_case", field: key, value: "empty_string" } }
        end

        scenarios
      end

      private

      def self.templates
        {
          loan_approval_high_risk: {
            context: {
              amount: 100_000,
              credit_score: 550,
              income: 30_000,
              employment_status: "unemployed"
            },
            metadata: {
              type: "loan_approval",
              category: "high_risk",
              description: "High-risk loan application scenario"
            }
          },

          loan_approval_low_risk: {
            context: {
              amount: 50_000,
              credit_score: 800,
              income: 100_000,
              employment_status: "employed"
            },
            metadata: {
              type: "loan_approval",
              category: "low_risk",
              description: "Low-risk loan application scenario"
            }
          },

          loan_approval_medium_risk: {
            context: {
              amount: 75_000,
              credit_score: 650,
              income: 60_000,
              employment_status: "employed"
            },
            metadata: {
              type: "loan_approval",
              category: "medium_risk",
              description: "Medium-risk loan application scenario"
            }
          },

          fraud_detection_suspicious: {
            context: {
              transaction_amount: 10_000,
              account_age_days: 5,
              transaction_count_24h: 50,
              location: "unusual"
            },
            metadata: {
              type: "fraud_detection",
              category: "suspicious",
              description: "Suspicious transaction scenario"
            }
          },

          fraud_detection_normal: {
            context: {
              transaction_amount: 100,
              account_age_days: 365,
              transaction_count_24h: 3,
              location: "usual"
            },
            metadata: {
              type: "fraud_detection",
              category: "normal",
              description: "Normal transaction scenario"
            }
          },

          pricing_high_value: {
            context: {
              customer_tier: "premium",
              order_value: 5_000,
              loyalty_points: 10_000,
              purchase_frequency: "high"
            },
            metadata: {
              type: "pricing",
              category: "high_value",
              description: "High-value customer pricing scenario"
            }
          },

          pricing_standard: {
            context: {
              customer_tier: "standard",
              order_value: 100,
              loyalty_points: 500,
              purchase_frequency: "medium"
            },
            metadata: {
              type: "pricing",
              category: "standard",
              description: "Standard customer pricing scenario"
            }
          }
        }
      end

      def self.merge_overrides(scenario, overrides)
        if overrides[:context]
          scenario[:context] = scenario[:context].merge(overrides[:context])
        end

        if overrides[:metadata]
          scenario[:metadata] = (scenario[:metadata] || {}).merge(overrides[:metadata])
        end

        overrides.each do |key, value|
          next if %i[context metadata].include?(key)
          scenario[key] = value
        end
      end
    end
  end
end

