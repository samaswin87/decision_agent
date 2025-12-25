require "spec_helper"

RSpec.describe "Advanced DSL Operators" do
  # STRING OPERATORS
  describe "string operators" do
    describe "contains operator" do
      it "matches when string contains substring" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "message", op: "contains", value: "error" },
              then: { decision: "alert", reason: "Error found in message" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ message: "An error occurred" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("alert")
      end

      it "does not match when substring is not present" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "message", op: "contains", value: "error" },
              then: { decision: "alert" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ message: "Success" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end

      it "is case-sensitive" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "message", op: "contains", value: "ERROR" },
              then: { decision: "alert" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ message: "An error occurred" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end

    describe "starts_with operator" do
      it "matches when string starts with prefix" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "code", op: "starts_with", value: "ERR" },
              then: { decision: "error_handler" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ code: "ERR_404" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("error_handler")
      end

      it "does not match when prefix is not present" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "code", op: "starts_with", value: "ERR" },
              then: { decision: "error_handler" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ code: "SUCCESS_200" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end

    describe "ends_with operator" do
      it "matches when string ends with suffix" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "filename", op: "ends_with", value: ".pdf" },
              then: { decision: "process_pdf" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ filename: "document.pdf" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("process_pdf")
      end

      it "does not match when suffix is not present" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "filename", op: "ends_with", value: ".pdf" },
              then: { decision: "process_pdf" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ filename: "document.txt" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end

    describe "matches operator" do
      it "matches string against regular expression" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "email", op: "matches", value: "^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$" },
              then: { decision: "valid_email" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ email: "user@example.com" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("valid_email")
      end

      it "does not match when regex fails" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "email", op: "matches", value: "^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$" },
              then: { decision: "valid_email" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ email: "invalid-email" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end

      it "handles invalid regex gracefully" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "text", op: "matches", value: "[invalid(" },
              then: { decision: "match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ text: "test" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end
  end

  # NUMERIC OPERATORS
  describe "numeric operators" do
    describe "between operator" do
      it "matches when value is between min and max (array format)" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "age", op: "between", value: [18, 65] },
              then: { decision: "eligible" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ age: 30 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("eligible")
      end

      it "matches when value is between min and max (hash format)" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "score", op: "between", value: { min: 0, max: 100 } },
              then: { decision: "valid_score" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ score: 75 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("valid_score")
      end

      it "includes boundary values" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "value", op: "between", value: [10, 20] },
              then: { decision: "in_range" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)

        context_min = DecisionAgent::Context.new({ value: 10 })
        evaluation_min = evaluator.evaluate(context_min)
        expect(evaluation_min).not_to be_nil

        context_max = DecisionAgent::Context.new({ value: 20 })
        evaluation_max = evaluator.evaluate(context_max)
        expect(evaluation_max).not_to be_nil
      end

      it "does not match when value is outside range" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "value", op: "between", value: [10, 20] },
              then: { decision: "in_range" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ value: 25 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end

    describe "modulo operator" do
      it "matches when modulo condition is satisfied (array format)" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "number", op: "modulo", value: [2, 0] },
              then: { decision: "even" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ number: 10 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("even")
      end

      it "matches when modulo condition is satisfied (hash format)" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "number", op: "modulo", value: { divisor: 3, remainder: 1 } },
              then: { decision: "match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ number: 7 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("match")
      end

      it "does not match when modulo condition fails" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "number", op: "modulo", value: [2, 0] },
              then: { decision: "even" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ number: 11 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end
  end

  # DATE/TIME OPERATORS
  describe "date/time operators" do
    describe "before_date operator" do
      it "matches when date is before specified date" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "expires_at", op: "before_date", value: "2025-12-31" },
              then: { decision: "not_expired" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ expires_at: "2025-06-01" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("not_expired")
      end

      it "does not match when date is after specified date" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "expires_at", op: "before_date", value: "2025-01-01" },
              then: { decision: "not_expired" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ expires_at: "2025-12-31" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end

    describe "after_date operator" do
      it "matches when date is after specified date" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "created_at", op: "after_date", value: "2024-01-01" },
              then: { decision: "recent" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ created_at: "2025-06-01" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("recent")
      end

      it "does not match when date is before specified date" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "created_at", op: "after_date", value: "2025-12-31" },
              then: { decision: "recent" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ created_at: "2025-01-01" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end

    describe "within_days operator" do
      it "matches when date is within N days from now" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "event_date", op: "within_days", value: 7 },
              then: { decision: "upcoming" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        event_date = (Time.now + (3 * 24 * 60 * 60)).strftime("%Y-%m-%d")
        context = DecisionAgent::Context.new({ event_date: event_date })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("upcoming")
      end

      it "does not match when date is outside N days" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "event_date", op: "within_days", value: 7 },
              then: { decision: "upcoming" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        event_date = (Time.now + (30 * 24 * 60 * 60)).strftime("%Y-%m-%d")
        context = DecisionAgent::Context.new({ event_date: event_date })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end

    describe "day_of_week operator" do
      it "matches when day of week is correct (string format)" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "appointment", op: "day_of_week", value: "monday" },
              then: { decision: "monday_appointment" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        # Find next Monday
        monday_date = Time.now
        monday_date += 24 * 60 * 60 until monday_date.wday == 1
        context = DecisionAgent::Context.new({ appointment: monday_date.strftime("%Y-%m-%d") })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("monday_appointment")
      end

      it "matches when day of week is correct (numeric format)" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "appointment", op: "day_of_week", value: 1 },
              then: { decision: "monday_appointment" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        monday_date = Time.now
        monday_date += 24 * 60 * 60 until monday_date.wday == 1
        context = DecisionAgent::Context.new({ appointment: monday_date.strftime("%Y-%m-%d") })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("monday_appointment")
      end
    end
  end

  # COLLECTION OPERATORS
  describe "collection operators" do
    describe "contains_all operator" do
      it "matches when array contains all specified elements" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "permissions", op: "contains_all", value: %w[read write] },
              then: { decision: "full_access" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ permissions: %w[read write execute] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("full_access")
      end

      it "does not match when array is missing some elements" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "permissions", op: "contains_all", value: %w[read write] },
              then: { decision: "full_access" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ permissions: ["read"] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end

    describe "contains_any operator" do
      it "matches when array contains any of the specified elements" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "tags", op: "contains_any", value: %w[urgent critical] },
              then: { decision: "prioritize" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ tags: %w[normal urgent] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("prioritize")
      end

      it "does not match when array contains none of the specified elements" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "tags", op: "contains_any", value: %w[urgent critical] },
              then: { decision: "prioritize" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ tags: %w[normal low] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end

    describe "intersects operator" do
      it "matches when arrays have common elements" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "user_roles", op: "intersects", value: %w[admin moderator] },
              then: { decision: "has_elevated_role" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ user_roles: %w[user moderator] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("has_elevated_role")
      end

      it "does not match when arrays have no common elements" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "user_roles", op: "intersects", value: %w[admin moderator] },
              then: { decision: "has_elevated_role" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ user_roles: %w[user guest] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end

    describe "subset_of operator" do
      it "matches when array is a subset of another" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "selected_items", op: "subset_of", value: %w[a b c d] },
              then: { decision: "valid_selection" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ selected_items: %w[a c] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("valid_selection")
      end

      it "does not match when array is not a subset" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "selected_items", op: "subset_of", value: %w[a b c] },
              then: { decision: "valid_selection" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ selected_items: %w[a d] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end
  end

  # GEOSPATIAL OPERATORS
  describe "geospatial operators" do
    describe "within_radius operator" do
      it "matches when point is within radius (hash format)" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: {
                field: "location",
                op: "within_radius",
                value: { center: { lat: 40.7128, lon: -74.0060 }, radius: 10 }
              },
              then: { decision: "nearby" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        # Point very close to center (within 1km)
        context = DecisionAgent::Context.new({ location: { lat: 40.7200, lon: -74.0000 } })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("nearby")
      end

      it "matches when point is within radius (array format)" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: {
                field: "location",
                op: "within_radius",
                value: { center: [40.7128, -74.0060], radius: 10 }
              },
              then: { decision: "nearby" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ location: [40.7200, -74.0000] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("nearby")
      end

      it "does not match when point is outside radius" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: {
                field: "location",
                op: "within_radius",
                value: { center: { lat: 40.7128, lon: -74.0060 }, radius: 1 }
              },
              then: { decision: "nearby" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        # Point far from center (more than 100km away)
        context = DecisionAgent::Context.new({ location: { lat: 41.0, lon: -75.0 } })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end

    describe "in_polygon operator" do
      it "matches when point is inside polygon" do
        # Square polygon around point (0,0)
        polygon = [
          { lat: -1, lon: -1 },
          { lat: 1, lon: -1 },
          { lat: 1, lon: 1 },
          { lat: -1, lon: 1 }
        ]

        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "location", op: "in_polygon", value: polygon },
              then: { decision: "inside_zone" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ location: { lat: 0, lon: 0 } })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("inside_zone")
      end

      it "does not match when point is outside polygon" do
        polygon = [
          { lat: -1, lon: -1 },
          { lat: 1, lon: -1 },
          { lat: 1, lon: 1 },
          { lat: -1, lon: 1 }
        ]

        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "location", op: "in_polygon", value: polygon },
              then: { decision: "inside_zone" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ location: { lat: 5, lon: 5 } })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end

      it "works with array format coordinates" do
        polygon = [
          [-1, -1],
          [1, -1],
          [1, 1],
          [-1, 1]
        ]

        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "location", op: "in_polygon", value: polygon },
              then: { decision: "inside_zone" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ location: [0, 0] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("inside_zone")
      end
    end
  end

  # COMBINATION TESTS
  describe "combining new operators with all/any" do
    it "works with 'all' condition" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: {
              all: [
                { field: "email", op: "ends_with", value: "@company.com" },
                { field: "age", op: "between", value: [18, 65] },
                { field: "roles", op: "contains_any", value: %w[admin manager] }
              ]
            },
            then: { decision: "approve" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({
                                             email: "user@company.com",
                                             age: 30,
                                             roles: %w[user admin]
                                           })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("approve")
    end

    it "works with 'any' condition" do
      rules = {
        version: "1.0",
        ruleset: "test",
        rules: [
          {
            id: "rule_1",
            if: {
              any: [
                { field: "status", op: "contains", value: "urgent" },
                { field: "priority", op: "modulo", value: [2, 1] },
                { field: "tags", op: "intersects", value: %w[critical emergency] }
              ]
            },
            then: { decision: "escalate" }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({
                                             status: "normal",
                                             priority: 7,
                                             tags: ["normal"]
                                           })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("escalate")
    end
  end
end
