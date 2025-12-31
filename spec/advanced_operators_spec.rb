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

    # MATHEMATICAL FUNCTIONS
    describe "trigonometric functions" do
      describe "sin operator" do
        it "matches when sin(field_value) equals expected_value" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "angle", op: "sin", value: 0.0 },
                then: { decision: "zero_angle" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ angle: 0 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("zero_angle")
        end

        it "matches when sin(pi/2) equals 1" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "angle", op: "sin", value: 1.0 },
                then: { decision: "right_angle" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ angle: Math::PI / 2 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("right_angle")
        end

        it "does not match when sin value is different" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "angle", op: "sin", value: 1.0 },
                then: { decision: "right_angle" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ angle: Math::PI })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end

      describe "cos operator" do
        it "matches when cos(field_value) equals expected_value" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "angle", op: "cos", value: 1.0 },
                then: { decision: "zero_angle" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ angle: 0 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("zero_angle")
        end

        it "does not match when cos value is different" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "angle", op: "cos", value: 1.0 },
                then: { decision: "zero_angle" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ angle: Math::PI / 2 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end

      describe "tan operator" do
        it "matches when tan(field_value) equals expected_value" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "angle", op: "tan", value: 0.0 },
                then: { decision: "zero_tangent" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ angle: 0 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("zero_tangent")
        end

        it "does not match when tan value is different" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "angle", op: "tan", value: 0.0 },
                then: { decision: "zero_tangent" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ angle: Math::PI / 4 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end
    end

    describe "exponential and logarithmic functions" do
      describe "sqrt operator" do
        it "matches when sqrt(field_value) equals expected_value" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "number", op: "sqrt", value: 3.0 },
                then: { decision: "square_root" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ number: 9 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("square_root")
        end

        it "does not match when sqrt value is different" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "number", op: "sqrt", value: 3.0 },
                then: { decision: "square_root" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ number: 16 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end

        it "does not match for negative numbers" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "number", op: "sqrt", value: 0.0 },
                then: { decision: "square_root" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ number: -4 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end

      describe "power operator" do
        it "matches when power(field_value, exponent) equals result (array format)" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "base", op: "power", value: [2, 4] },
                then: { decision: "power_match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ base: 2 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("power_match")
        end

        it "matches when power(field_value, exponent) equals result (hash format)" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "base", op: "power", value: { exponent: 3, result: 8 } },
                then: { decision: "power_match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ base: 2 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("power_match")
        end

        it "does not match when power result is different" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "base", op: "power", value: [2, 4] },
                then: { decision: "power_match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ base: 3 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end

      describe "exp operator" do
        it "matches when exp(field_value) equals expected_value" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "exponent", op: "exp", value: Math::E },
                then: { decision: "e_power" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ exponent: 1 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("e_power")
        end

        it "does not match when exp value is different" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "exponent", op: "exp", value: Math::E },
                then: { decision: "e_power" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ exponent: 2 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end

      describe "log operator" do
        it "matches when log(field_value) equals expected_value" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "number", op: "log", value: 0.0 },
                then: { decision: "log_one" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ number: 1 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("log_one")
        end

        it "does not match when log value is different" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "number", op: "log", value: 0.0 },
                then: { decision: "log_one" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ number: 2 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end

        it "does not match for non-positive numbers" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "number", op: "log", value: 0.0 },
                then: { decision: "log_one" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ number: -1 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end
    end

    describe "rounding and absolute value functions" do
      describe "round operator" do
        it "matches when round(field_value) equals expected_value" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "round", value: 3 },
                then: { decision: "rounded" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: 3.4 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("rounded")
        end

        it "matches when rounding up" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "round", value: 4 },
                then: { decision: "rounded" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: 3.6 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("rounded")
        end

        it "does not match when rounded value is different" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "round", value: 3 },
                then: { decision: "rounded" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: 2.3 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end

      describe "floor operator" do
        it "matches when floor(field_value) equals expected_value" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "floor", value: 3 },
                then: { decision: "floored" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: 3.9 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("floored")
        end

        it "does not match when floor value is different" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "floor", value: 3 },
                then: { decision: "floored" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: 2.5 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end

      describe "ceil operator" do
        it "matches when ceil(field_value) equals expected_value" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "ceil", value: 4 },
                then: { decision: "ceiled" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: 3.1 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("ceiled")
        end

        it "does not match when ceil value is different" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "ceil", value: 4 },
                then: { decision: "ceiled" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: 2.1 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end

      describe "abs operator" do
        it "matches when abs(field_value) equals expected_value for positive" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "abs", value: 5 },
                then: { decision: "absolute" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: 5 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("absolute")
        end

        it "matches when abs(field_value) equals expected_value for negative" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "abs", value: 5 },
                then: { decision: "absolute" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: -5 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("absolute")
        end

        it "does not match when abs value is different" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "abs", value: 5 },
                then: { decision: "absolute" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: -3 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end
    end

    describe "aggregation functions" do
      describe "min operator" do
        it "matches when min(field_value) equals expected_value" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "numbers", op: "min", value: 1 },
                then: { decision: "min_found" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ numbers: [3, 1, 5, 2] })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("min_found")
        end

        it "does not match when min value is different" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "numbers", op: "min", value: 1 },
                then: { decision: "min_found" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ numbers: [3, 5, 2] })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end

        it "does not match for empty arrays" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "numbers", op: "min", value: 1 },
                then: { decision: "min_found" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ numbers: [] })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end

      describe "max operator" do
        it "matches when max(field_value) equals expected_value" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "numbers", op: "max", value: 5 },
                then: { decision: "max_found" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ numbers: [3, 1, 5, 2] })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("max_found")
        end

        it "does not match when max value is different" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "numbers", op: "max", value: 5 },
                then: { decision: "max_found" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ numbers: [3, 1, 2] })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end

        it "does not match for empty arrays" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "numbers", op: "max", value: 5 },
                then: { decision: "max_found" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ numbers: [] })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end
    end

    # EDGE CASES FOR MATHEMATICAL OPERATORS
    describe "edge cases for mathematical operators" do
      describe "non-numeric values" do
        it "handles string values gracefully for sin" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "sin", value: 0.0 },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: "not_a_number" })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end

        it "handles string values gracefully for sqrt" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "sqrt", value: 3.0 },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: "invalid" })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end

        it "handles string values gracefully for round" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "round", value: 3 },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: "not_numeric" })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end

        it "handles non-array values gracefully for min" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "min", value: 1 },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: "not_an_array" })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end

      describe "missing or nil values" do
        it "handles missing field gracefully for sin" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "missing", op: "sin", value: 0.0 },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({})

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end

        it "handles nil value gracefully for sqrt" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "sqrt", value: 3.0 },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: nil })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end

        it "handles nil value gracefully for min" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "value", op: "min", value: 1 },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ value: nil })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end

      describe "floating point precision" do
        it "handles floating point precision for sin" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "angle", op: "sin", value: 0.0 },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          # sin(0) should be exactly 0.0
          context = DecisionAgent::Context.new({ angle: 0.0 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("match")
        end

        it "handles floating point precision for cos" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "angle", op: "cos", value: 1.0 },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ angle: 0.0 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("match")
        end
      end

      describe "very large numbers" do
        it "handles very large numbers for exp" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "exponent", op: "exp", value: Math.exp(10) },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ exponent: 10 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("match")
        end

        it "handles very large numbers for power" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "base", op: "power", value: [3, 27] },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ base: 3 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("match")
        end
      end

      describe "integration with all/any conditions" do
        it "works with all condition combining multiple mathematical operators" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: {
                  all: [
                    { field: "angle", op: "sin", value: 0.0 },
                    { field: "number", op: "sqrt", value: 3.0 },
                    { field: "value", op: "abs", value: 5 }
                  ]
                },
                then: { decision: "all_match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({
            angle: 0,
            number: 9,
            value: -5
          })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("all_match")
        end

        it "works with any condition combining multiple mathematical operators" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: {
                  any: [
                    { field: "angle", op: "sin", value: 1.0 },
                    { field: "number", op: "sqrt", value: 4.0 },
                    { field: "value", op: "abs", value: 10 }
                  ]
                },
                then: { decision: "any_match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({
            angle: 0,  # sin(0) = 0, not 1
            number: 9,  # sqrt(9) = 3, not 4
            value: -10  # abs(-10) = 10, matches!
          })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("any_match")
        end
      end

      describe "nested field access" do
        it "works with nested fields for sin" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "math.angle", op: "sin", value: 0.0 },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ math: { angle: 0 } })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("match")
        end

        it "works with nested fields for min" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "data.numbers", op: "min", value: 1 },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ data: { numbers: [3, 1, 5, 2] } })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("match")
        end
      end

      describe "power operator edge cases" do
        it "handles power with zero exponent" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "base", op: "power", value: [0, 1] },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ base: 5 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("match")
        end

        it "handles power with negative exponent" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "base", op: "power", value: [-1, 0.5] },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ base: 2 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("match")
        end

        it "handles invalid power parameters gracefully" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "base", op: "power", value: "invalid" },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ base: 2 })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).to be_nil
        end
      end

      describe "min/max with mixed types" do
        it "handles min with mixed numeric types" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "numbers", op: "min", value: 1 },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ numbers: [3.5, 1, 5.0, 2] })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("match")
        end

        it "handles max with mixed numeric types" do
          rules = {
            version: "1.0",
            ruleset: "test",
            rules: [
              {
                id: "rule_1",
                if: { field: "numbers", op: "max", value: 5 },
                then: { decision: "match" }
              }
            ]
          }

          evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
          context = DecisionAgent::Context.new({ numbers: [1, 3.5, 5, 2.0] })

          evaluation = evaluator.evaluate(context)

          expect(evaluation).not_to be_nil
          expect(evaluation.decision).to eq("match")
        end
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

  # STATISTICAL AGGREGATIONS
  describe "statistical aggregation operators" do
    describe "sum operator" do
      it "matches when sum equals expected value" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "amounts", op: "sum", value: 100 },
              then: { decision: "total_match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ amounts: [30, 40, 30] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("total_match")
      end

      it "matches with comparison operators" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "prices", op: "sum", value: { "gte": 100 } },
              then: { decision: "free_shipping" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ prices: [25, 30, 50] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("free_shipping")
      end

      it "returns false for empty array" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "amounts", op: "sum", value: 0 },
              then: { decision: "match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ amounts: [] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end

      it "filters out non-numeric values" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "values", op: "sum", value: 15 },
              then: { decision: "match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ values: [5, "invalid", 10, nil] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("match")
      end
    end

    describe "average operator" do
      it "matches when average equals expected value" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "scores", op: "average", value: 50 },
              then: { decision: "average_score" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ scores: [40, 50, 60] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("average_score")
      end

      it "matches with comparison operators" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "latencies", op: "average", value: { "lt": 200 } },
              then: { decision: "acceptable" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ latencies: [150, 180, 190] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("acceptable")
      end
    end

    describe "mean operator" do
      it "works as alias for average" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "values", op: "mean", value: 25 },
              then: { decision: "match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ values: [20, 25, 30] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("match")
      end
    end

    describe "median operator" do
      it "matches when median equals expected value" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "scores", op: "median", value: 50 },
              then: { decision: "median_match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ scores: [40, 50, 60] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("median_match")
      end

      it "handles even number of elements" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "values", op: "median", value: 25 },
              then: { decision: "match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ values: [20, 30] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("match")
      end
    end

    describe "stddev operator" do
      it "matches when standard deviation meets threshold" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "values", op: "stddev", value: { "lt": 5 } },
              then: { decision: "low_variance" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ values: [10, 11, 12, 13, 14] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("low_variance")
      end

      it "returns false for arrays with less than 2 elements" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "values", op: "stddev", value: 0 },
              then: { decision: "match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ values: [10] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).to be_nil
      end
    end

    describe "variance operator" do
      it "matches when variance meets threshold" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "scores", op: "variance", value: { "lt": 100 } },
              then: { decision: "low_variance" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ scores: [50, 52, 48, 51, 49] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("low_variance")
      end
    end

    describe "percentile operator" do
      it "matches when percentile meets threshold" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "latencies", op: "percentile", value: { "percentile": 95, "threshold": 200 } },
              then: { decision: "p95_ok" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ latencies: [100, 120, 150, 180, 190, 200, 210] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("p95_ok")
      end

      it "works with comparison operators" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "times", op: "percentile", value: { "percentile": 99, "gt": 500 } },
              then: { decision: "high_p99" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ times: [100, 200, 300, 400, 500, 600, 700] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("high_p99")
      end
    end

    describe "count operator" do
      it "matches when count equals expected value" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "items", op: "count", value: 3 },
              then: { decision: "three_items" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ items: ["a", "b", "c"] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("three_items")
      end

      it "matches with comparison operators" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "errors", op: "count", value: { "gte": 5 } },
              then: { decision: "alert" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ errors: ["err1", "err2", "err3", "err4", "err5"] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("alert")
      end
    end
  end

  # DURATION CALCULATIONS
  describe "duration calculation operators" do
    describe "duration_seconds operator" do
      it "matches when duration is within threshold" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "start_time", op: "duration_seconds", value: { "end": "now", "max": 3600 } },
              then: { decision: "within_hour" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ start_time: (Time.now - 1800).iso8601 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("within_hour")
      end

      it "works with field path for end time" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "session.start", op: "duration_seconds", value: { "end": "session.end", "max": 7200 } },
              then: { decision: "short_session" }
            }
          ]
        }

        start_time = Time.now - 3600
        end_time = Time.now - 300

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({
                                               session: {
                                                 start: start_time.iso8601,
                                                 end: end_time.iso8601
                                               }
                                             })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("short_session")
      end
    end

    describe "duration_minutes operator" do
      it "calculates duration in minutes" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "created_at", op: "duration_minutes", value: { "end": "now", "gte": 30 } },
              then: { decision: "old_enough" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ created_at: (Time.now - 3600).iso8601 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("old_enough")
      end
    end

    describe "duration_hours and duration_days operators" do
      it "calculates duration in hours" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "start", op: "duration_hours", value: { "end": "now", "gte": 1 } },
              then: { decision: "match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ start: (Time.now - 7200).iso8601 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("match")
      end

      it "calculates duration in days" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "trial_start", op: "duration_days", value: { "end": "now", "gte": 7 } },
              then: { decision: "trial_expired" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ trial_start: (Time.now - 8 * 86_400).iso8601 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("trial_expired")
      end
    end
  end

  # DATE ARITHMETIC
  describe "date arithmetic operators" do
    describe "add_days operator" do
      it "adds days and compares with target" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "created_at", op: "add_days", value: { "days": 7, "compare": "lte", "target": "now" } },
              then: { decision: "week_old" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ created_at: (Time.now - 8 * 86_400).iso8601 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("week_old")
      end
    end

    describe "subtract_days, add_hours, subtract_hours, add_minutes, subtract_minutes operators" do
      it "subtracts days correctly" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "deadline", op: "subtract_days", value: { "days": 1, "compare": "gt", "target": "now" } },
              then: { decision: "not_urgent" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ deadline: (Time.now + 2 * 86_400).iso8601 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("not_urgent")
      end

      it "adds hours correctly" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "start", op: "add_hours", value: { "hours": 2, "compare": "lt", "target": "now" } },
              then: { decision: "past_2h" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ start: (Time.now - 7200).iso8601 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("past_2h")
      end
    end
  end

  # TIME COMPONENT EXTRACTION
  describe "time component extraction operators" do
    describe "hour_of_day operator" do
      it "extracts hour and compares" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "timestamp", op: "hour_of_day", value: { "gte": 9, "lte": 17 } },
              then: { decision: "business_hours" }
            }
          ]
        }

        time = Time.new(2025, 1, 1, 14, 0, 0)
        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ timestamp: time.iso8601 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("business_hours")
      end
    end

    describe "day_of_month, month, year, week_of_year operators" do
      it "extracts day of month" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "date", op: "day_of_month", value: 15 },
              then: { decision: "mid_month" }
            }
          ]
        }

        time = Time.new(2025, 1, 15, 12, 0, 0)
        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ date: time.iso8601 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("mid_month")
      end

      it "extracts month" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "event_date", op: "month", value: 12 },
              then: { decision: "december" }
            }
          ]
        }

        time = Time.new(2025, 12, 25, 12, 0, 0)
        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ event_date: time.iso8601 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("december")
      end
    end
  end

  # RATE CALCULATIONS
  describe "rate calculation operators" do
    describe "rate_per_second operator" do
      it "calculates rate per second from timestamps" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "request_timestamps", op: "rate_per_second", value: { "max": 10 } },
              then: { decision: "within_limit" }
            }
          ]
        }

        now = Time.now
        timestamps = [
          (now - 5).iso8601,
          (now - 4).iso8601,
          (now - 3).iso8601,
          (now - 2).iso8601,
          (now - 1).iso8601
        ]

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ request_timestamps: timestamps })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("within_limit")
      end
    end

    describe "rate_per_minute and rate_per_hour operators" do
      it "calculates rate per minute" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "events", op: "rate_per_minute", value: { "max": 60 } },
              then: { decision: "ok" }
            }
          ]
        }

        now = Time.now
        timestamps = [
          (now - 60).iso8601,
          (now - 30).iso8601,
          now.iso8601
        ]

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ events: timestamps })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("ok")
      end
    end
  end

  # MOVING WINDOW CALCULATIONS
  describe "moving window operators" do
    describe "moving_average operator" do
      it "calculates moving average over window" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "metrics", op: "moving_average", value: { "window": 5, "lte": 100 } },
              then: { decision: "low_avg" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ metrics: [80, 85, 90, 95, 100] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("low_avg")
      end
    end

    describe "moving_sum, moving_max, moving_min operators" do
      it "calculates moving sum" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "values", op: "moving_sum", value: { window: 3, gte: 25 } },
              then: { decision: "match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ values: [10, 10, 10, 5] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("match")
      end
    end
  end

  # FINANCIAL CALCULATIONS
  describe "financial calculation operators" do
    describe "compound_interest operator" do
      it "calculates compound interest correctly" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "principal", op: "compound_interest", value: { "rate": 0.05, "periods": 12, "result": 1051.16 } },
              then: { decision: "match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ principal: 1000 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("match")
      end
    end

    describe "present_value and future_value operators" do
      it "calculates present value" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "future_value", op: "present_value", value: { "rate": 0.05, "periods": 10, "result": 613.91 } },
              then: { decision: "match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ future_value: 1000 })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("match")
      end
    end
  end

  # STRING AGGREGATIONS
  describe "string aggregation operators" do
    describe "join operator" do
      it "joins array with separator and matches result" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "tags", op: "join", value: { "separator": ",", "result": "a,b,c" } },
              then: { decision: "match" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ tags: ["a", "b", "c"] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("match")
      end

      it "matches with contains check" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "tags", op: "join", value: { "separator": ",", "contains": "important" } },
              then: { decision: "has_important" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ tags: ["urgent", "important", "critical"] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("has_important")
      end
    end

    describe "length operator" do
      it "matches when string length meets threshold" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "description", op: "length", value: { "min": 10, "max": 500 } },
              then: { decision: "valid_length" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ description: "This is a valid description" })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("valid_length")
      end

      it "works with arrays" do
        rules = {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule_1",
              if: { field: "items", op: "length", value: { "gte": 3 } },
              then: { decision: "enough_items" }
            }
          ]
        }

        evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
        context = DecisionAgent::Context.new({ items: ["a", "b", "c", "d"] })

        evaluation = evaluator.evaluate(context)

        expect(evaluation).not_to be_nil
        expect(evaluation.decision).to eq("enough_items")
      end
    end
  end
end
