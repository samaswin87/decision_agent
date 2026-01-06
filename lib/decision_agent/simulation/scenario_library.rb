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
        raise DecisionAgent::Simulation::ScenarioExecutionError, "Template not found: #{template_name}" unless template

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

        # Generate scenarios with extreme numeric values and empty strings
        base_context.each do |key, value|
          if value.is_a?(Numeric)
            # Zero value
            zero_scenario = base_context.dup
            zero_scenario[key] = 0
            scenarios << { context: zero_scenario, metadata: { type: "edge_case", field: key, value: "zero" } }

            # Negative value (if positive)
            if value.positive?
              neg_scenario = base_context.dup
              neg_scenario[key] = -value
              scenarios << { context: neg_scenario, metadata: { type: "edge_case", field: key, value: "negative" } }
            end

            # Very large value
            large_scenario = base_context.dup
            large_scenario[key] = value * 1000
            scenarios << { context: large_scenario, metadata: { type: "edge_case", field: key, value: "large" } }
          elsif value.is_a?(String)
            # Empty string
            empty_scenario = base_context.dup
            empty_scenario[key] = ""
            scenarios << { context: empty_scenario, metadata: { type: "edge_case", field: key, value: "empty_string" } }
          end
        end

        scenarios
      end

      def self.templates
        loan_approval_templates
          .merge(fraud_detection_templates)
          .merge(pricing_templates)
      end

      def self.loan_approval_templates
        {
          loan_approval_high_risk: build_loan_scenario(100_000, 550, 30_000, "unemployed", "high_risk"),
          loan_approval_low_risk: build_loan_scenario(50_000, 800, 100_000, "employed", "low_risk"),
          loan_approval_medium_risk: build_loan_scenario(75_000, 650, 60_000, "employed", "medium_risk")
        }
      end

      def self.build_loan_scenario(amount, credit_score, income, employment_status, risk_level)
        {
          context: {
            amount: amount,
            credit_score: credit_score,
            income: income,
            employment_status: employment_status
          },
          metadata: {
            type: "loan_approval",
            category: risk_level,
            description: "#{risk_level.capitalize.tr('_', ' ')} loan application scenario"
          }
        }
      end

      def self.fraud_detection_templates
        {
          fraud_detection_suspicious: build_fraud_scenario(10_000, 5, 50, "unusual", "suspicious"),
          fraud_detection_normal: build_fraud_scenario(100, 365, 3, "usual", "normal")
        }
      end

      def self.build_fraud_scenario(amount, account_age, transaction_count, location, category)
        {
          context: {
            transaction_amount: amount,
            account_age_days: account_age,
            transaction_count_24h: transaction_count,
            location: location
          },
          metadata: {
            type: "fraud_detection",
            category: category,
            description: "#{category.capitalize} transaction scenario"
          }
        }
      end

      def self.pricing_templates
        {
          pricing_high_value: build_pricing_scenario("premium", 5_000, 10_000, "high", "high_value"),
          pricing_standard: build_pricing_scenario("standard", 100, 500, "medium", "standard")
        }
      end

      def self.build_pricing_scenario(tier, order_value, loyalty_points, frequency, category)
        {
          context: {
            customer_tier: tier,
            order_value: order_value,
            loyalty_points: loyalty_points,
            purchase_frequency: frequency
          },
          metadata: {
            type: "pricing",
            category: category,
            description: "#{category.capitalize.tr('_', ' ')} customer pricing scenario"
          }
        }
      end

      def self.merge_overrides(scenario, overrides)
        scenario[:context] = scenario[:context].merge(overrides[:context]) if overrides[:context]

        scenario[:metadata] = (scenario[:metadata] || {}).merge(overrides[:metadata]) if overrides[:metadata]

        overrides.each do |key, value|
          next if %i[context metadata].include?(key)

          scenario[key] = value
        end
      end
    end
  end
end
