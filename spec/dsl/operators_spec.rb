require "spec_helper"

RSpec.describe "DSL Operator Mixins" do
  let(:context) { DecisionAgent::Context.new({ status: "active", age: 30, score: 85, name: "John Doe" }) }

  describe "BasicComparisonOperators" do
    it "handles eq operator" do
      condition = { "field" => "status", "op" => "eq", "value" => "active" }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "handles neq operator" do
      condition = { "field" => "status", "op" => "neq", "value" => "inactive" }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "handles gt operator" do
      condition = { "field" => "age", "op" => "gt", "value" => 25 }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "handles gte operator" do
      condition = { "field" => "age", "op" => "gte", "value" => 30 }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "handles lt operator" do
      condition = { "field" => "age", "op" => "lt", "value" => 35 }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "handles lte operator" do
      condition = { "field" => "age", "op" => "lte", "value" => 30 }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "handles in operator" do
      condition = { "field" => "status", "op" => "in", "value" => %w[active pending] }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "handles present operator" do
      condition = { "field" => "name", "op" => "present", "value" => true }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "handles blank operator" do
      condition = { "field" => "missing_field", "op" => "blank", "value" => true }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end
  end

  describe "StringOperators" do
    it "handles contains operator" do
      condition = { "field" => "name", "op" => "contains", "value" => "John" }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "handles starts_with operator" do
      condition = { "field" => "name", "op" => "starts_with", "value" => "John" }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "handles ends_with operator" do
      condition = { "field" => "name", "op" => "ends_with", "value" => "Doe" }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "handles matches operator with regex" do
      condition = { "field" => "name", "op" => "matches", "value" => "^John.*" }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end
  end

  describe "NumericOperators" do
    it "handles between operator with array" do
      condition = { "field" => "age", "op" => "between", "value" => [25, 35] }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "handles between operator with hash" do
      condition = { "field" => "age", "op" => "between", "value" => { "min" => 25, "max" => 35 } }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "handles modulo operator" do
      condition = { "field" => "age", "op" => "modulo", "value" => { "divisor" => 2, "remainder" => 0 } }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end
  end

  describe "MathematicalOperators" do
    it "handles sin operator" do
      condition = { "field" => "angle", "op" => "sin", "value" => 0.0 }
      context_with_angle = DecisionAgent::Context.new({ angle: 0.0 })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_angle)
      expect(result).to be true
    end

    it "handles cos operator" do
      condition = { "field" => "angle", "op" => "cos", "value" => 1.0 }
      context_with_angle = DecisionAgent::Context.new({ angle: 0.0 })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_angle)
      expect(result).to be true
    end

    it "handles sqrt operator" do
      condition = { "field" => "number", "op" => "sqrt", "value" => 3.0 }
      context_with_number = DecisionAgent::Context.new({ number: 9.0 })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_number)
      expect(result).to be true
    end

    it "handles power operator" do
      condition = { "field" => "base", "op" => "power", "value" => { "exponent" => 2, "result" => 4 } }
      context_with_base = DecisionAgent::Context.new({ base: 2 })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_base)
      expect(result).to be true
    end

    it "handles round operator" do
      condition = { "field" => "value", "op" => "round", "value" => 3 }
      context_with_value = DecisionAgent::Context.new({ value: 3.4 })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_value)
      expect(result).to be true
    end

    it "handles floor operator" do
      condition = { "field" => "value", "op" => "floor", "value" => 3 }
      context_with_value = DecisionAgent::Context.new({ value: 3.7 })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_value)
      expect(result).to be true
    end

    it "handles ceil operator" do
      condition = { "field" => "value", "op" => "ceil", "value" => 4 }
      context_with_value = DecisionAgent::Context.new({ value: 3.2 })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_value)
      expect(result).to be true
    end

    it "handles abs operator" do
      condition = { "field" => "value", "op" => "abs", "value" => 5 }
      context_with_value = DecisionAgent::Context.new({ value: -5 })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_value)
      expect(result).to be true
    end

    it "handles factorial operator" do
      condition = { "field" => "number", "op" => "factorial", "value" => 6 }
      context_with_number = DecisionAgent::Context.new({ number: 3 })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_number)
      expect(result).to be true
    end

    it "handles gcd operator" do
      condition = { "field" => "a", "op" => "gcd", "value" => { "other" => 12, "result" => 6 } }
      context_with_a = DecisionAgent::Context.new({ a: 18 })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_a)
      expect(result).to be true
    end

    it "handles lcm operator" do
      condition = { "field" => "a", "op" => "lcm", "value" => { "other" => 12, "result" => 36 } }
      context_with_a = DecisionAgent::Context.new({ a: 18 })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_a)
      expect(result).to be true
    end
  end

  describe "StatisticalAggregations" do
    it "handles min operator" do
      condition = { "field" => "scores", "op" => "min", "value" => 10 }
      context_with_scores = DecisionAgent::Context.new({ scores: [10, 20, 30] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_scores)
      expect(result).to be true
    end

    it "handles max operator" do
      condition = { "field" => "scores", "op" => "max", "value" => 30 }
      context_with_scores = DecisionAgent::Context.new({ scores: [10, 20, 30] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_scores)
      expect(result).to be true
    end

    it "handles sum operator" do
      condition = { "field" => "scores", "op" => "sum", "value" => 60 }
      context_with_scores = DecisionAgent::Context.new({ scores: [10, 20, 30] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_scores)
      expect(result).to be true
    end

    it "handles average operator" do
      condition = { "field" => "scores", "op" => "average", "value" => 20 }
      context_with_scores = DecisionAgent::Context.new({ scores: [10, 20, 30] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_scores)
      expect(result).to be true
    end

    it "handles median operator" do
      condition = { "field" => "scores", "op" => "median", "value" => 20 }
      context_with_scores = DecisionAgent::Context.new({ scores: [10, 20, 30] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_scores)
      expect(result).to be true
    end

    it "handles count operator" do
      condition = { "field" => "items", "op" => "count", "value" => 3 }
      context_with_items = DecisionAgent::Context.new({ items: [1, 2, 3] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_items)
      expect(result).to be true
    end

    it "handles percentile operator" do
      condition = { "field" => "scores", "op" => "percentile", "value" => { "percentile" => 90, "threshold" => 25 } }
      context_with_scores = DecisionAgent::Context.new({ scores: [10, 20, 30, 40, 50] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_scores)
      expect(result).to be true
    end
  end

  describe "DateTimeOperators" do
    it "handles before_date operator" do
      condition = { "field" => "start_date", "op" => "before_date", "value" => "2024-12-31" }
      context_with_date = DecisionAgent::Context.new({ start_date: "2024-01-01" })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_date)
      expect(result).to be true
    end

    it "handles after_date operator" do
      condition = { "field" => "end_date", "op" => "after_date", "value" => "2024-01-01" }
      context_with_date = DecisionAgent::Context.new({ end_date: "2024-12-31" })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_date)
      expect(result).to be true
    end

    it "handles within_days operator" do
      condition = { "field" => "event_date", "op" => "within_days", "value" => 7 }
      context_with_date = DecisionAgent::Context.new({ event_date: Time.now + (3 * 86_400) })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_date)
      expect(result).to be true
    end

    it "handles day_of_week operator" do
      # Monday is 1 in Ruby's Time.wday (Sunday is 0)
      monday = Time.new(2024, 1, 1) # This is a Monday
      condition = { "field" => "date", "op" => "day_of_week", "value" => "monday" }
      context_with_date = DecisionAgent::Context.new({ date: monday })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_date)
      expect(result).to be true
    end
  end

  describe "DurationOperators" do
    it "handles duration_seconds operator" do
      start_time = Time.now - 3600 # 1 hour ago
      condition = { "field" => "start_time", "op" => "duration_seconds", "value" => { "end" => "now", "max" => 4000 } }
      context_with_time = DecisionAgent::Context.new({ start_time: start_time })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_time)
      expect(result).to be true
    end

    it "handles duration_days operator" do
      start_date = Time.now - (3 * 86_400) # 3 days ago
      condition = { "field" => "start_date", "op" => "duration_days", "value" => { "end" => "now", "max" => 5 } }
      context_with_date = DecisionAgent::Context.new({ start_date: start_date })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_date)
      expect(result).to be true
    end
  end

  describe "DateArithmeticOperators" do
    it "handles add_days operator" do
      start_date = Time.new(2024, 1, 1)
      target_date = Time.new(2024, 1, 9) # 8 days after start_date (7 days added + 1 day buffer)
      condition = { "field" => "start_date", "op" => "add_days", "value" => { "days" => 7, "target" => "now", "compare" => "lt" } }
      context_with_date = DecisionAgent::Context.new({ start_date: start_date })
      # Mock Time.now to return target_date for this test
      allow(Time).to receive(:now).and_return(target_date)
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_date)
      expect(result).to be true
    end
  end

  describe "TimeComponentOperators" do
    it "handles hour_of_day operator" do
      test_time = Time.new(2024, 1, 1, 14, 30, 0) # 2:30 PM
      condition = { "field" => "timestamp", "op" => "hour_of_day", "value" => 14 }
      context_with_time = DecisionAgent::Context.new({ timestamp: test_time })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_time)
      expect(result).to be true
    end

    it "handles month operator" do
      test_date = Time.new(2024, 6, 15)
      condition = { "field" => "date", "op" => "month", "value" => 6 }
      context_with_date = DecisionAgent::Context.new({ date: test_date })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_date)
      expect(result).to be true
    end

    it "handles year operator" do
      test_date = Time.new(2024, 1, 1)
      condition = { "field" => "date", "op" => "year", "value" => 2024 }
      context_with_date = DecisionAgent::Context.new({ date: test_date })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_date)
      expect(result).to be true
    end
  end

  describe "RateOperators" do
    it "handles rate_per_second operator" do
      timestamps = [
        Time.now - 10,
        Time.now - 8,
        Time.now - 6,
        Time.now - 4,
        Time.now - 2
      ]
      condition = { "field" => "events", "op" => "rate_per_second", "value" => { "max" => 1.0 } }
      context_with_events = DecisionAgent::Context.new({ events: timestamps })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_events)
      expect(result).to be true
    end
  end

  describe "MovingWindowOperators" do
    it "handles moving_average operator" do
      condition = { "field" => "values", "op" => "moving_average", "value" => { "window" => 3, "threshold" => 20 } }
      context_with_values = DecisionAgent::Context.new({ values: [10, 20, 30, 40, 50] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_values)
      expect(result).to be true
    end

    it "handles moving_sum operator" do
      condition = { "field" => "values", "op" => "moving_sum", "value" => { "window" => 3, "threshold" => 100 } }
      context_with_values = DecisionAgent::Context.new({ values: [10, 20, 30, 40, 50] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_values)
      expect(result).to be true
    end
  end

  describe "FinancialOperators" do
    it "handles compound_interest operator" do
      # Formula: A = P(1 + r/n)^(nt)
      # For P=1000, r=0.05, n=12: 1000 * (1 + 0.05/12)^12 ≈ 1051.16
      condition = { "field" => "principal", "op" => "compound_interest", "value" => { "rate" => 0.05, "periods" => 12, "result" => 1051.16 } }
      context_with_principal = DecisionAgent::Context.new({ principal: 1000 })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_principal)
      expect(result).to be true
    end

    it "handles present_value operator" do
      condition = { "field" => "future_value", "op" => "present_value", "value" => { "rate" => 0.05, "periods" => 10, "result" => 613.91 } }
      context_with_fv = DecisionAgent::Context.new({ future_value: 1000 })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_fv)
      expect(result).to be true
    end
  end

  describe "StringAggregations" do
    it "handles join operator" do
      condition = { "field" => "tags", "op" => "join", "value" => { "separator" => ",", "result" => "a,b,c" } }
      context_with_tags = DecisionAgent::Context.new({ tags: %w[a b c] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_tags)
      expect(result).to be true
    end

    it "handles length operator" do
      condition = { "field" => "text", "op" => "length", "value" => { "max" => 100 } }
      context_with_text = DecisionAgent::Context.new({ text: "Hello World" })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_text)
      expect(result).to be true
    end
  end

  describe "CollectionOperators" do
    it "handles contains_all operator" do
      condition = { "field" => "tags", "op" => "contains_all", "value" => %w[a b] }
      context_with_tags = DecisionAgent::Context.new({ tags: %w[a b c] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_tags)
      expect(result).to be true
    end

    it "handles contains_any operator" do
      condition = { "field" => "tags", "op" => "contains_any", "value" => %w[b d] }
      context_with_tags = DecisionAgent::Context.new({ tags: %w[a b c] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_tags)
      expect(result).to be true
    end

    it "handles intersects operator" do
      condition = { "field" => "set1", "op" => "intersects", "value" => %w[b c] }
      context_with_set = DecisionAgent::Context.new({ set1: %w[a b c] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_set)
      expect(result).to be true
    end

    it "handles subset_of operator" do
      condition = { "field" => "subset", "op" => "subset_of", "value" => %w[a b c d] }
      context_with_subset = DecisionAgent::Context.new({ subset: %w[a b] })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_subset)
      expect(result).to be true
    end
  end

  describe "GeospatialOperators" do
    it "handles within_radius operator" do
      condition = { "field" => "location", "op" => "within_radius", "value" => { "center" => { "lat" => 37.7749, "lon" => -122.4194 }, "radius" => 10 } }
      context_with_location = DecisionAgent::Context.new({ location: { "lat" => 37.7750, "lon" => -122.4195 } })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_location)
      expect(result).to be true
    end

    it "handles in_polygon operator" do
      polygon = [
        { "lat" => 0, "lon" => 0 },
        { "lat" => 0, "lon" => 1 },
        { "lat" => 1, "lon" => 1 },
        { "lat" => 1, "lon" => 0 }
      ]
      condition = { "field" => "point", "op" => "in_polygon", "value" => polygon }
      context_with_point = DecisionAgent::Context.new({ point: { "lat" => 0.5, "lon" => 0.5 } })
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context_with_point)
      expect(result).to be true
    end
  end

  describe "Operator mixin integration" do
    it "correctly delegates to appropriate mixin" do
      # Test that operators are correctly routed to their mixins
      condition = { "field" => "age", "op" => "gt", "value" => 25 }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be true
    end

    it "returns false for unknown operator" do
      condition = { "field" => "age", "op" => "unknown_operator", "value" => 25 }
      result = DecisionAgent::Dsl::ConditionEvaluator.evaluate_field_condition(condition, context)
      expect(result).to be false
    end
  end
end
