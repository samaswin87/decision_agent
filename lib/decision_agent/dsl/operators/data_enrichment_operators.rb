module DecisionAgent
  module Dsl
    module Operators
      # Handles data enrichment operators: fetch_from_api
      module DataEnrichmentOperators
        def self.handle(op, actual_value, expected_value, context_hash)
          case op
          when "fetch_from_api"
            # Fetches data from external API and enriches context
            # expected_value: { endpoint: :endpoint_name, params: {...}, mapping: {...} }
            return false unless expected_value.is_a?(Hash)
            return false unless expected_value[:endpoint] || expected_value["endpoint"]

            begin
              endpoint_name = (expected_value[:endpoint] || expected_value["endpoint"]).to_sym
              params = ConditionEvaluator.expand_template_params(
                expected_value[:params] || expected_value["params"] || {},
                context_hash
              )
              mapping = expected_value[:mapping] || expected_value["mapping"] || {}

              # Get data enrichment client
              client = DecisionAgent.data_enrichment_client

              # Fetch data from API
              response_data = client.fetch(endpoint_name, params: params, use_cache: true)

              # Apply mapping if provided and merge into context_hash
              if mapping.any?
                mapped_data = ConditionEvaluator.apply_mapping(response_data, mapping)
                # Merge mapped data into context_hash for subsequent conditions
                mapped_data.each do |key, value|
                  context_hash[key] = value
                end
                # Return true if fetch succeeded and mapping applied
                mapped_data.any?
              else
                # Return true if fetch succeeded
                !response_data.nil?
              end
            rescue StandardError => e
              # Log error but return false (fail-safe)
              warn "Data enrichment error: #{e.message}" if ENV["DEBUG"]
              false
            end

          else
            nil # Not handled by this module
          end
        end
      end
    end
  end
end
