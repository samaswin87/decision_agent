module DecisionAgent
  module Dsl
    module Helpers
      # Template expansion and mapping helpers for ConditionEvaluator
      module TemplateHelpers
        def self.expand_template_params(params, context_hash, get_nested_value:)
          return {} unless params.is_a?(Hash)

          params.transform_values do |value|
            expand_template_value(value, context_hash, get_nested_value: get_nested_value)
          end
        end

        def self.expand_template_value(value, context_hash, get_nested_value:)
          return value unless value.is_a?(String)
          return value unless value.match?(/\{\{.*\}\}/)

          # Extract path from {{path}} syntax
          value.gsub(/\{\{([^}]+)\}\}/) do |_match|
            path = Regexp.last_match(1).strip
            get_nested_value.call(context_hash, path) || value
          end
        end

        def self.apply_mapping(response_data, mapping, get_nested_value:)
          return {} unless response_data.is_a?(Hash)
          return {} unless mapping.is_a?(Hash)

          mapping.each_with_object({}) do |(source_key, target_key), result|
            source_value = get_nested_value.call(response_data, source_key.to_s)
            result[target_key.to_s] = source_value unless source_value.nil?
          end
        end
      end
    end
  end
end
