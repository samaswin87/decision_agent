require "json"

module DecisionAgent
  module Dsl
    class RuleParser
      def self.parse(json_string)
        data = JSON.parse(json_string)

        validate_structure!(data)

        data
      rescue JSON::ParserError => e
        raise InvalidRuleDslError, "Invalid JSON: #{e.message}"
      end

      private

      def self.validate_structure!(data)
        unless data.is_a?(Hash)
          raise InvalidRuleDslError, "Root must be a hash"
        end

        unless data["version"]
          raise InvalidRuleDslError, "Missing 'version' field"
        end

        unless data["rules"].is_a?(Array)
          raise InvalidRuleDslError, "Missing or invalid 'rules' array"
        end

        data["rules"].each_with_index do |rule, idx|
          validate_rule!(rule, idx)
        end
      end

      def self.validate_rule!(rule, idx)
        unless rule.is_a?(Hash)
          raise InvalidRuleDslError, "Rule at index #{idx} must be a hash"
        end

        unless rule["id"]
          raise InvalidRuleDslError, "Rule at index #{idx} missing 'id'"
        end

        unless rule["if"]
          raise InvalidRuleDslError, "Rule '#{rule['id']}' missing 'if' clause"
        end

        unless rule["then"]
          raise InvalidRuleDslError, "Rule '#{rule['id']}' missing 'then' clause"
        end

        unless rule["then"]["decision"]
          raise InvalidRuleDslError, "Rule '#{rule['id']}' missing 'then.decision'"
        end
      end
    end
  end
end
