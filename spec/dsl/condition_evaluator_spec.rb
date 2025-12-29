require "spec_helper"

RSpec.describe DecisionAgent::Dsl::ConditionEvaluator do
  let(:context) { DecisionAgent::Context.new({ status: "active", age: 30, score: 85 }) }

  describe ".evaluate" do
    context "with invalid input" do
      it "returns false for non-hash condition" do
        result = described_class.evaluate("not a hash", context)
        expect(result).to be false
      end

      it "returns false for nil condition" do
        result = described_class.evaluate(nil, context)
        expect(result).to be false
      end

      it "returns false for condition without field, all, or any" do
        result = described_class.evaluate({ invalid: "key" }, context)
        expect(result).to be false
      end
    end

    context "with 'all' condition" do
      it "evaluates all conditions" do
        condition = {
          "all" => [
            { "field" => "status", "op" => "eq", "value" => "active" },
            { "field" => "age", "op" => "gt", "value" => 18 }
          ]
        }
        result = described_class.evaluate(condition, context)
        expect(result).to be true
      end

      it "returns false if any condition fails" do
        condition = {
          "all" => [
            { "field" => "status", "op" => "eq", "value" => "active" },
            { "field" => "age", "op" => "gt", "value" => 100 }
          ]
        }
        result = described_class.evaluate(condition, context)
        expect(result).to be false
      end
    end

    context "with 'any' condition" do
      it "evaluates any condition" do
        condition = {
          "any" => [
            { "field" => "status", "op" => "eq", "value" => "inactive" },
            { "field" => "age", "op" => "gt", "value" => 18 }
          ]
        }
        result = described_class.evaluate(condition, context)
        expect(result).to be true
      end

      it "returns false if all conditions fail" do
        condition = {
          "any" => [
            { "field" => "status", "op" => "eq", "value" => "inactive" },
            { "field" => "age", "op" => "gt", "value" => 100 }
          ]
        }
        result = described_class.evaluate(condition, context)
        expect(result).to be false
      end
    end

    context "with field condition" do
      it "evaluates field condition" do
        condition = { "field" => "status", "op" => "eq", "value" => "active" }
        result = described_class.evaluate(condition, context)
        expect(result).to be true
      end
    end
  end

  describe ".evaluate_all" do
    it "returns true for empty array" do
      result = described_class.evaluate_all([], context)
      expect(result).to be true
    end

    it "returns false for non-array input" do
      result = described_class.evaluate_all("not an array", context)
      expect(result).to be false
    end

    it "returns true when all conditions are true" do
      conditions = [
        { "field" => "status", "op" => "eq", "value" => "active" },
        { "field" => "age", "op" => "gt", "value" => 18 }
      ]
      result = described_class.evaluate_all(conditions, context)
      expect(result).to be true
    end

    it "returns false when any condition is false" do
      conditions = [
        { "field" => "status", "op" => "eq", "value" => "active" },
        { "field" => "age", "op" => "gt", "value" => 100 }
      ]
      result = described_class.evaluate_all(conditions, context)
      expect(result).to be false
    end
  end

  describe ".evaluate_any" do
    it "returns false for empty array" do
      result = described_class.evaluate_any([], context)
      expect(result).to be false
    end

    it "returns false for non-array input" do
      result = described_class.evaluate_any("not an array", context)
      expect(result).to be false
    end

    it "returns true when at least one condition is true" do
      conditions = [
        { "field" => "status", "op" => "eq", "value" => "inactive" },
        { "field" => "age", "op" => "gt", "value" => 18 }
      ]
      result = described_class.evaluate_any(conditions, context)
      expect(result).to be true
    end

    it "returns false when all conditions are false" do
      conditions = [
        { "field" => "status", "op" => "eq", "value" => "inactive" },
        { "field" => "age", "op" => "gt", "value" => 100 }
      ]
      result = described_class.evaluate_any(conditions, context)
      expect(result).to be false
    end
  end

  describe ".evaluate_field_condition" do
    describe "equality operators" do
      it "handles eq operator" do
        condition = { "field" => "status", "op" => "eq", "value" => "active" }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be true
      end

      it "handles neq operator" do
        condition = { "field" => "status", "op" => "neq", "value" => "inactive" }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be true
      end
    end

    describe "comparison operators" do
      it "handles gt operator" do
        condition = { "field" => "age", "op" => "gt", "value" => 18 }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be true
      end

      it "handles gte operator" do
        condition = { "field" => "age", "op" => "gte", "value" => 30 }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be true
      end

      it "handles lt operator" do
        condition = { "field" => "age", "op" => "lt", "value" => 40 }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be true
      end

      it "handles lte operator" do
        condition = { "field" => "age", "op" => "lte", "value" => 30 }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be true
      end

      it "returns false for incompatible types in comparison" do
        condition = { "field" => "status", "op" => "gt", "value" => 10 }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be false
      end
    end

    describe "membership operators" do
      it "handles in operator" do
        condition = { "field" => "status", "op" => "in", "value" => %w[active inactive] }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be true
      end

      it "handles in operator with non-array value" do
        condition = { "field" => "status", "op" => "in", "value" => "active" }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be true
      end
    end

    describe "presence operators" do
      it "handles present operator with non-empty value" do
        condition = { "field" => "status", "op" => "present" }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be true
      end

      it "handles present operator with nil" do
        ctx = DecisionAgent::Context.new({ status: nil })
        condition = { "field" => "status", "op" => "present" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be false
      end

      it "handles present operator with empty string" do
        ctx = DecisionAgent::Context.new({ status: "" })
        condition = { "field" => "status", "op" => "present" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be false
      end

      it "handles present operator with empty array" do
        ctx = DecisionAgent::Context.new({ items: [] })
        condition = { "field" => "items", "op" => "present" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be false
      end

      it "handles present operator with zero" do
        ctx = DecisionAgent::Context.new({ count: 0 })
        condition = { "field" => "count", "op" => "present" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles present operator with false boolean" do
        ctx = DecisionAgent::Context.new({ active: false })
        condition = { "field" => "active", "op" => "present" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles blank operator with nil" do
        ctx = DecisionAgent::Context.new({ status: nil })
        condition = { "field" => "status", "op" => "blank" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles blank operator with empty string" do
        ctx = DecisionAgent::Context.new({ status: "" })
        condition = { "field" => "status", "op" => "blank" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles blank operator with zero" do
        ctx = DecisionAgent::Context.new({ count: 0 })
        condition = { "field" => "count", "op" => "blank" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be false
      end

      it "handles blank operator with false boolean" do
        ctx = DecisionAgent::Context.new({ active: false })
        condition = { "field" => "active", "op" => "blank" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be false
      end
    end

    describe "string operators" do
      it "handles contains operator" do
        ctx = DecisionAgent::Context.new({ message: "Hello world" })
        condition = { "field" => "message", "op" => "contains", "value" => "world" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles starts_with operator" do
        ctx = DecisionAgent::Context.new({ code: "ERR_404" })
        condition = { "field" => "code", "op" => "starts_with", "value" => "ERR" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles ends_with operator" do
        ctx = DecisionAgent::Context.new({ filename: "document.pdf" })
        condition = { "field" => "filename", "op" => "ends_with", "value" => ".pdf" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles matches operator with string regex" do
        ctx = DecisionAgent::Context.new({ email: "user@example.com" })
        condition = { "field" => "email", "op" => "matches", "value" => "^[a-z]+@[a-z]+\\.[a-z]+$" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles matches operator with Regexp object" do
        ctx = DecisionAgent::Context.new({ email: "user@example.com" })
        condition = { "field" => "email", "op" => "matches", "value" => /^[a-z]+@[a-z]+\.[a-z]+$/ }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "returns false for matches with non-string value" do
        condition = { "field" => "age", "op" => "matches", "value" => "\\d+" }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be false
      end

      it "handles invalid regex gracefully" do
        ctx = DecisionAgent::Context.new({ text: "test" })
        condition = { "field" => "text", "op" => "matches", "value" => "[invalid(" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be false
      end

      it "returns false for string operators with non-string values" do
        condition = { "field" => "age", "op" => "contains", "value" => "30" }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be false
      end
    end

    describe "numeric operators" do
      it "handles between operator with array" do
        condition = { "field" => "age", "op" => "between", "value" => [18, 65] }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be true
      end

      it "handles between operator with hash" do
        condition = { "field" => "age", "op" => "between", "value" => { "min" => 18, "max" => 65 } }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be true
      end

      it "returns false for between with non-numeric value" do
        condition = { "field" => "status", "op" => "between", "value" => [1, 10] }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be false
      end

      it "handles modulo operator with array" do
        condition = { "field" => "age", "op" => "modulo", "value" => [2, 0] }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be true
      end

      it "handles modulo operator with hash" do
        condition = { "field" => "age", "op" => "modulo", "value" => { "divisor" => 2, "remainder" => 0 } }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be true
      end

      it "returns false for modulo with non-numeric value" do
        condition = { "field" => "status", "op" => "modulo", "value" => [2, 0] }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be false
      end
    end

    describe "date/time operators" do
      it "handles before_date operator" do
        ctx = DecisionAgent::Context.new({ expires_at: "2025-06-01" })
        condition = { "field" => "expires_at", "op" => "before_date", "value" => "2025-12-31" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles after_date operator" do
        ctx = DecisionAgent::Context.new({ created_at: "2025-06-01" })
        condition = { "field" => "created_at", "op" => "after_date", "value" => "2024-01-01" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles within_days operator" do
        future_date = (Time.now + (3 * 24 * 60 * 60)).strftime("%Y-%m-%d")
        ctx = DecisionAgent::Context.new({ event_date: future_date })
        condition = { "field" => "event_date", "op" => "within_days", "value" => 7 }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles day_of_week operator with string" do
        monday_date = Time.now
        monday_date += 24 * 60 * 60 until monday_date.wday == 1
        ctx = DecisionAgent::Context.new({ appointment: monday_date.strftime("%Y-%m-%d") })
        condition = { "field" => "appointment", "op" => "day_of_week", "value" => "monday" }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles day_of_week operator with numeric" do
        monday_date = Time.now
        monday_date += 24 * 60 * 60 until monday_date.wday == 1
        ctx = DecisionAgent::Context.new({ appointment: monday_date.strftime("%Y-%m-%d") })
        condition = { "field" => "appointment", "op" => "day_of_week", "value" => 1 }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end
    end

    describe "collection operators" do
      it "handles contains_all operator" do
        ctx = DecisionAgent::Context.new({ permissions: %w[read write execute] })
        condition = { "field" => "permissions", "op" => "contains_all", "value" => %w[read write] }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles contains_any operator" do
        ctx = DecisionAgent::Context.new({ tags: %w[normal urgent] })
        condition = { "field" => "tags", "op" => "contains_any", "value" => %w[urgent critical] }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles intersects operator" do
        ctx = DecisionAgent::Context.new({ user_roles: %w[user moderator] })
        condition = { "field" => "user_roles", "op" => "intersects", "value" => %w[admin moderator] }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles subset_of operator" do
        ctx = DecisionAgent::Context.new({ selected_items: %w[a c] })
        condition = { "field" => "selected_items", "op" => "subset_of", "value" => %w[a b c d] }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "returns false for collection operators with non-array values" do
        condition = { "field" => "status", "op" => "contains_all", "value" => %w[read write] }
        result = described_class.evaluate_field_condition(condition, context)
        expect(result).to be false
      end
    end

    describe "geospatial operators" do
      it "handles within_radius operator" do
        ctx = DecisionAgent::Context.new({ location: { lat: 40.7200, lon: -74.0000 } })
        condition = {
          "field" => "location",
          "op" => "within_radius",
          "value" => { "center" => { "lat" => 40.7128, "lon" => -74.0060 }, "radius" => 10 }
        }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "handles in_polygon operator" do
        polygon = [
          { "lat" => -1, "lon" => -1 },
          { "lat" => 1, "lon" => -1 },
          { "lat" => 1, "lon" => 1 },
          { "lat" => -1, "lon" => 1 }
        ]
        ctx = DecisionAgent::Context.new({ location: { lat: 0, lon: 0 } })
        condition = { "field" => "location", "op" => "in_polygon", "value" => polygon }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be true
      end

      it "returns false for in_polygon with less than 3 vertices" do
        polygon = [
          { "lat" => -1, "lon" => -1 },
          { "lat" => 1, "lon" => -1 }
        ]
        ctx = DecisionAgent::Context.new({ location: { lat: 0, lon: 0 } })
        condition = { "field" => "location", "op" => "in_polygon", "value" => polygon }
        result = described_class.evaluate_field_condition(condition, ctx)
        expect(result).to be false
      end
    end

    it "returns false for unknown operator" do
      condition = { "field" => "status", "op" => "unknown_op", "value" => "active" }
      result = described_class.evaluate_field_condition(condition, context)
      expect(result).to be false
    end
  end

  describe ".get_nested_value" do
    it "retrieves simple value" do
      hash = { status: "active" }
      result = described_class.get_nested_value(hash, "status")
      expect(result).to eq("active")
    end

    it "retrieves nested value with dot notation" do
      hash = { user: { role: "admin" } }
      result = described_class.get_nested_value(hash, "user.role")
      expect(result).to eq("admin")
    end

    it "retrieves deeply nested value" do
      hash = { user: { profile: { name: "John" } } }
      result = described_class.get_nested_value(hash, "user.profile.name")
      expect(result).to eq("John")
    end

    it "returns nil for missing key" do
      hash = { user: { role: "admin" } }
      result = described_class.get_nested_value(hash, "user.missing")
      expect(result).to be_nil
    end

    it "returns nil when intermediate value is nil" do
      hash = { user: nil }
      result = described_class.get_nested_value(hash, "user.role")
      expect(result).to be_nil
    end

    it "handles symbol keys" do
      hash = { user: { role: "admin" } }
      result = described_class.get_nested_value(hash, "user.role")
      expect(result).to eq("admin")
    end

    it "returns nil for non-hash intermediate value" do
      hash = { user: "not a hash" }
      result = described_class.get_nested_value(hash, "user.role")
      expect(result).to be_nil
    end
  end

  describe ".comparable?" do
    it "returns true for same numeric types" do
      result = described_class.comparable?(10, 20)
      expect(result).to be true
    end

    it "returns true for same string types" do
      result = described_class.comparable?("a", "b")
      expect(result).to be true
    end

    it "returns false for different numeric types" do
      result = described_class.comparable?(10, 20.0)
      expect(result).to be false
    end

    it "returns false for non-comparable types" do
      result = described_class.comparable?({}, [])
      expect(result).to be false
    end
  end

  describe ".parse_range" do
    it "parses array format" do
      result = described_class.parse_range([10, 20])
      expect(result).to eq({ min: 10, max: 20 })
    end

    it "parses hash format with string keys" do
      result = described_class.parse_range({ "min" => 10, "max" => 20 })
      expect(result).to eq({ min: 10, max: 20 })
    end

    it "parses hash format with symbol keys" do
      result = described_class.parse_range({ min: 10, max: 20 })
      expect(result).to eq({ min: 10, max: 20 })
    end

    it "returns nil for invalid array" do
      result = described_class.parse_range([10])
      expect(result).to be_nil
    end

    it "returns nil for invalid hash" do
      result = described_class.parse_range({ min: 10 })
      expect(result).to be_nil
    end
  end

  describe ".parse_modulo_params" do
    it "parses array format" do
      result = described_class.parse_modulo_params([2, 0])
      expect(result).to eq({ divisor: 2, remainder: 0 })
    end

    it "parses hash format with string keys" do
      result = described_class.parse_modulo_params({ "divisor" => 2, "remainder" => 0 })
      expect(result).to eq({ divisor: 2, remainder: 0 })
    end

    it "parses hash format with symbol keys" do
      result = described_class.parse_modulo_params({ divisor: 2, remainder: 0 })
      expect(result).to eq({ divisor: 2, remainder: 0 })
    end

    it "returns nil for invalid array" do
      result = described_class.parse_modulo_params([2])
      expect(result).to be_nil
    end

    it "returns nil for invalid hash" do
      result = described_class.parse_modulo_params({ divisor: 2 })
      expect(result).to be_nil
    end
  end

  describe ".parse_date" do
    it "parses Time object" do
      time = Time.now
      result = described_class.parse_date(time)
      expect(result).to eq(time)
    end

    it "parses Date object" do
      date = Date.today
      result = described_class.parse_date(date)
      expect(result).to eq(date)
    end

    it "parses DateTime object" do
      datetime = DateTime.now
      result = described_class.parse_date(datetime)
      expect(result).to eq(datetime)
    end

    it "parses string date" do
      result = described_class.parse_date("2025-01-01")
      expect(result).to be_a(Time)
    end

    it "returns nil for invalid string" do
      result = described_class.parse_date("invalid")
      expect(result).to be_nil
    end
  end

  describe ".compare_dates" do
    it "compares dates with < operator" do
      result = described_class.compare_dates("2025-01-01", "2025-12-31", :<)
      expect(result).to be true
    end

    it "compares dates with > operator" do
      result = described_class.compare_dates("2025-12-31", "2025-01-01", :>)
      expect(result).to be true
    end

    it "returns false for invalid dates" do
      result = described_class.compare_dates("invalid", "2025-01-01", :<)
      expect(result).to be false
    end
  end

  describe ".normalize_day_of_week" do
    it "normalizes numeric day" do
      result = described_class.normalize_day_of_week(1)
      expect(result).to eq(1)
    end

    it "normalizes string day" do
      result = described_class.normalize_day_of_week("monday")
      expect(result).to eq(1)
    end

    it "normalizes abbreviated day" do
      result = described_class.normalize_day_of_week("mon")
      expect(result).to eq(1)
    end

    it "returns nil for invalid day" do
      result = described_class.normalize_day_of_week("invalid")
      expect(result).to be_nil
    end
  end

  describe ".parse_coordinates" do
    it "parses hash with lat/lon" do
      result = described_class.parse_coordinates({ lat: 40.7128, lon: -74.0060 })
      expect(result).to eq({ lat: 40.7128, lon: -74.0060 })
    end

    it "parses hash with latitude/longitude" do
      result = described_class.parse_coordinates({ latitude: 40.7128, longitude: -74.0060 })
      expect(result).to eq({ lat: 40.7128, lon: -74.0060 })
    end

    it "parses array format" do
      result = described_class.parse_coordinates([40.7128, -74.0060])
      expect(result).to eq({ lat: 40.7128, lon: -74.0060 })
    end

    it "returns nil for invalid hash" do
      result = described_class.parse_coordinates({ lat: 40.7128 })
      expect(result).to be_nil
    end

    it "returns nil for invalid array" do
      result = described_class.parse_coordinates([40.7128])
      expect(result).to be_nil
    end
  end

  describe ".parse_radius_params" do
    it "parses radius parameters" do
      params = {
        "center" => { "lat" => 40.7128, "lon" => -74.0060 },
        "radius" => 10
      }
      result = described_class.parse_radius_params(params)
      expect(result[:center]).to eq({ lat: 40.7128, lon: -74.0060 })
      expect(result[:radius]).to eq(10.0)
    end

    it "returns nil for invalid params" do
      result = described_class.parse_radius_params({ center: { lat: 40.7128 } })
      expect(result).to be_nil
    end
  end

  describe ".parse_polygon" do
    it "parses polygon vertices" do
      vertices = [
        { lat: -1, lon: -1 },
        { lat: 1, lon: -1 },
        { lat: 1, lon: 1 }
      ]
      result = described_class.parse_polygon(vertices)
      expect(result.size).to eq(3)
    end

    it "returns nil for non-array" do
      result = described_class.parse_polygon("not an array")
      expect(result).to be_nil
    end
  end

  describe ".haversine_distance" do
    it "calculates distance between two points" do
      point1 = { lat: 40.7128, lon: -74.0060 }
      point2 = { lat: 40.7200, lon: -74.0000 }
      result = described_class.haversine_distance(point1, point2)
      expect(result).to be_a(Numeric)
      expect(result).to be >= 0
    end
  end

  describe ".point_in_polygon?" do
    it "detects point inside polygon" do
      point = { lat: 0, lon: 0 }
      polygon = [
        { lat: -1, lon: -1 },
        { lat: 1, lon: -1 },
        { lat: 1, lon: 1 },
        { lat: -1, lon: 1 }
      ]
      result = described_class.point_in_polygon?(point, polygon)
      expect(result).to be true
    end

    it "detects point outside polygon" do
      point = { lat: 5, lon: 5 }
      polygon = [
        { lat: -1, lon: -1 },
        { lat: 1, lon: -1 },
        { lat: 1, lon: 1 },
        { lat: -1, lon: 1 }
      ]
      result = described_class.point_in_polygon?(point, polygon)
      expect(result).to be false
    end
  end
end

