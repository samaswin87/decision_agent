module DecisionAgent
  module Dsl
    class ConditionEvaluator
      def self.evaluate(condition, context)
        return false unless condition.is_a?(Hash)

        if condition.key?("all")
          evaluate_all(condition["all"], context)
        elsif condition.key?("any")
          evaluate_any(condition["any"], context)
        elsif condition.key?("field")
          evaluate_field_condition(condition, context)
        else
          false
        end
      end

      private

      def self.evaluate_all(conditions, context)
        return false unless conditions.is_a?(Array)
        conditions.all? { |cond| evaluate(cond, context) }
      end

      def self.evaluate_any(conditions, context)
        return false unless conditions.is_a?(Array)
        conditions.any? { |cond| evaluate(cond, context) }
      end

      def self.evaluate_field_condition(condition, context)
        field = condition["field"]
        op = condition["op"]
        expected_value = condition["value"]

        actual_value = get_nested_value(context.to_h, field)

        case op
        when "eq"
          actual_value == expected_value
        when "neq"
          actual_value != expected_value
        when "gt"
          comparable?(actual_value, expected_value) && actual_value > expected_value
        when "gte"
          comparable?(actual_value, expected_value) && actual_value >= expected_value
        when "lt"
          comparable?(actual_value, expected_value) && actual_value < expected_value
        when "lte"
          comparable?(actual_value, expected_value) && actual_value <= expected_value
        when "in"
          Array(expected_value).include?(actual_value)
        when "present"
          !actual_value.nil? && (actual_value.respond_to?(:empty?) ? !actual_value.empty? : true)
        when "blank"
          actual_value.nil? || (actual_value.respond_to?(:empty?) ? actual_value.empty? : false)
        else
          false
        end
      end

      def self.get_nested_value(hash, key_path)
        keys = key_path.to_s.split(".")
        keys.reduce(hash) do |memo, key|
          return nil unless memo.is_a?(Hash)
          memo[key] || memo[key.to_sym]
        end
      end

      def self.comparable?(val1, val2)
        (val1.is_a?(Numeric) || val1.is_a?(String)) &&
          (val2.is_a?(Numeric) || val2.is_a?(String)) &&
          val1.class == val2.class
      end
    end
  end
end
