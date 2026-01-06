module DecisionAgent
  module Explainability
    # Represents a single condition evaluation with its result and values
    class ConditionTrace
      attr_reader :field, :operator, :expected_value, :actual_value, :result, :description

      def initialize(field:, operator:, expected_value:, actual_value:, result:, description: nil)
        @field = field.to_s.freeze
        @operator = operator.to_s.freeze
        @expected_value = expected_value
        @actual_value = actual_value
        @result = result
        @description = description ? description.to_s.freeze : generate_description
        freeze
      end

      def passed?
        @result == true
      end

      def failed?
        @result == false
      end

      def to_s
        @description
      end

      def to_h
        {
          field: @field,
          operator: @operator,
          expected_value: @expected_value,
          actual_value: @actual_value,
          result: @result,
          description: @description
        }
      end

      private

      def generate_description
        case @operator
        when "eq"
          "#{@field} = #{format_value(@actual_value)}"
        when "neq"
          "#{@field} != #{format_value(@expected_value)}"
        when "gt"
          "#{@field} > #{format_value(@expected_value)}"
        when "gte"
          "#{@field} >= #{format_value(@expected_value)}"
        when "lt"
          "#{@field} < #{format_value(@expected_value)}"
        when "lte"
          "#{@field} <= #{format_value(@expected_value)}"
        when "in"
          "#{@field} in #{format_value(@expected_value)}"
        when "contains"
          "#{@field} contains #{format_value(@expected_value)}"
        when "present"
          "#{@field} is present"
        when "blank"
          "#{@field} is blank"
        else
          "#{@field} #{@operator} #{format_value(@expected_value)}"
        end
      end

      def format_value(value)
        case value
        when String
          value.inspect
        when Array, Hash
          value.inspect
        when Time, Date, DateTime
          value.to_s
        else
          value.to_s
        end
      end
    end
  end
end

