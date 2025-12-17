require "json"

module DecisionAgent
  module Dsl
    class RuleParser
      def self.parse(json_string)
        data = parse_json(json_string)

        # Use comprehensive schema validator
        SchemaValidator.validate!(data)

        data
      rescue JSON::ParserError => e
        raise InvalidRuleDslError, "Invalid JSON syntax: #{e.message}\n\n" \
                                   "Please ensure your JSON is properly formatted. " \
                                   "Common issues:\n" \
                                   "  - Missing or extra commas\n" \
                                   "  - Unquoted keys or values\n" \
                                   "  - Unmatched brackets or braces"
      end

      private

      def self.parse_json(input)
        if input.is_a?(String)
          JSON.parse(input)
        elsif input.is_a?(Hash)
          # Already parsed, convert to string keys for consistency
          JSON.parse(JSON.generate(input))
        else
          raise InvalidRuleDslError, "Expected JSON string or Hash, got #{input.class}"
        end
      end
    end
  end
end
