require "spec_helper"

RSpec.describe "DSL Validation" do
  describe DecisionAgent::Dsl::SchemaValidator do
    describe "root structure validation" do
      it "rejects non-hash input" do
        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!([1, 2, 3])
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /Root element must be a hash/)
      end

      it "rejects string input" do
        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!("not a hash")
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /Root element must be a hash/)
      end

      it "accepts valid hash input" do
        valid_rules = {
          "version" => "1.0",
          "rules" => []
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(valid_rules)
        }.not_to raise_error
      end
    end

    describe "version validation" do
      it "requires version field" do
        rules = {
          "rules" => []
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /Missing required field 'version'/)
      end

      it "accepts version as symbol key" do
        rules = {
          version: "1.0",
          rules: []
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.not_to raise_error
      end
    end

    describe "rules array validation" do
      it "requires rules field" do
        rules = {
          "version" => "1.0"
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /Missing required field 'rules'/)
      end

      it "rejects non-array rules" do
        rules = {
          "version" => "1.0",
          "rules" => "not an array"
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /must be an array/)
      end

      it "accepts empty rules array" do
        rules = {
          "version" => "1.0",
          "rules" => []
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.not_to raise_error
      end
    end

    describe "rule structure validation" do
      it "rejects non-hash rule" do
        rules = {
          "version" => "1.0",
          "rules" => ["not a hash"]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /rules\[0\].*must be a hash/)
      end

      it "requires rule id" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "if" => { "field" => "status", "op" => "eq", "value" => "active" },
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /Missing required field 'id'/)
      end

      it "requires rule if clause" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /Missing required field 'if'/)
      end

      it "requires rule then clause" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "status", "op" => "eq", "value" => "active" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /Missing required field 'then'/)
      end
    end

    describe "condition validation" do
      it "rejects condition without field, all, or any" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "invalid" => "condition" },
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /Condition must have one of: 'field', 'all', or 'any'/)
      end

      it "rejects non-hash condition" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => "not a hash",
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /Condition must be a hash/)
      end
    end

    describe "field condition validation" do
      it "requires field key" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "op" => "eq", "value" => "active" },
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError) do |error|
          expect(error.message).to match(/Condition must have one of: 'field', 'all', or 'any'/)
        end
      end

      it "requires op (operator) key" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "status", "value" => "active" },
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /missing 'op'/)
      end

      it "validates operator is supported" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "status", "op" => "invalid_op", "value" => "active" },
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError) do |error|
          expect(error.message).to include("Unsupported operator 'invalid_op'")
          expect(error.message).to include("eq, neq, gt, gte, lt, lte, in, present, blank")
        end
      end

      it "requires value for non-present/blank operators" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "status", "op" => "eq" },
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /missing 'value' key/)
      end

      it "allows missing value for present operator" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "assignee", "op" => "present" },
              "then" => { "decision" => "assigned" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.not_to raise_error
      end

      it "allows missing value for blank operator" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "description", "op" => "blank" },
              "then" => { "decision" => "needs_info" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.not_to raise_error
      end

      it "rejects empty field path" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "", "op" => "eq", "value" => "test" },
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /Field path cannot be empty/)
      end

      it "rejects invalid dot-notation" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "user..role", "op" => "eq", "value" => "admin" },
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /cannot have empty segments/)
      end

      it "accepts valid dot-notation" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "user.profile.role", "op" => "eq", "value" => "admin" },
              "then" => { "decision" => "allow" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.not_to raise_error
      end
    end

    describe "all/any condition validation" do
      it "requires array for all condition" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "all" => "not an array" },
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /'all' condition must contain an array/)
      end

      it "requires array for any condition" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "any" => "not an array" },
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /'any' condition must contain an array/)
      end

      it "validates nested conditions in all" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => {
                "all" => [
                  { "field" => "status", "op" => "invalid_op", "value" => "active" }
                ]
              },
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /Unsupported operator/)
      end

      it "validates nested conditions in any" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => {
                "any" => [
                  { "field" => "priority" }  # Missing op
                ]
              },
              "then" => { "decision" => "escalate" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /missing 'op'/)
      end
    end

    describe "then clause validation" do
      it "requires then clause to be a hash" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "status", "op" => "eq", "value" => "active" },
              "then" => "not a hash"
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /then.*Must be a hash/)
      end

      it "requires decision field in then clause" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "status", "op" => "eq", "value" => "active" },
              "then" => { "weight" => 0.8 }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /Missing required field 'decision'/)
      end

      it "validates weight is numeric" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "status", "op" => "eq", "value" => "active" },
              "then" => { "decision" => "approve", "weight" => "not a number" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /weight.*Must be a number/)
      end

      it "validates weight is between 0 and 1" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "status", "op" => "eq", "value" => "active" },
              "then" => { "decision" => "approve", "weight" => 1.5 }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /weight.*between 0.0 and 1.0/)
      end

      it "validates reason is a string" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "status", "op" => "eq", "value" => "active" },
              "then" => { "decision" => "approve", "reason" => 123 }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError, /reason.*Must be a string/)
      end

      it "accepts valid then clause with all fields" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "status", "op" => "eq", "value" => "active" },
              "then" => {
                "decision" => "approve",
                "weight" => 0.8,
                "reason" => "Status is active"
              }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.not_to raise_error
      end
    end

    describe "error message formatting" do
      it "provides numbered error list for multiple errors" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              # Missing if clause
              # Missing then clause
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError) do |error|
          expect(error.message).to include("1.")
          expect(error.message).to include("2.")
          expect(error.message).to match(/validation failed with 2 errors/)
        end
      end

      it "includes helpful context in error messages" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => { "field" => "status", "op" => "invalid_op", "value" => "test" },
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError) do |error|
          expect(error.message).to include("rules[0].if")
          expect(error.message).to include("Supported operators:")
        end
      end
    end

    describe "complex nested validation" do
      it "validates deeply nested all/any structures" do
        rules = {
          "version" => "1.0",
          "rules" => [
            {
              "id" => "rule_1",
              "if" => {
                "all" => [
                  {
                    "any" => [
                      { "field" => "a", "op" => "eq", "value" => 1 },
                      { "field" => "b", "op" => "invalid_op", "value" => 2 }
                    ]
                  }
                ]
              },
              "then" => { "decision" => "approve" }
            }
          ]
        }

        expect {
          DecisionAgent::Dsl::SchemaValidator.validate!(rules)
        }.to raise_error(DecisionAgent::InvalidRuleDslError) do |error|
          expect(error.message).to include("rules[0].if.all[0].any[1]")
          expect(error.message).to include("Unsupported operator")
        end
      end
    end
  end

  describe "RuleParser integration" do
    it "uses SchemaValidator for validation" do
      invalid_json = '{"version": "1.0", "rules": "not an array"}'

      expect {
        DecisionAgent::Dsl::RuleParser.parse(invalid_json)
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /must be an array/)
    end

    it "provides helpful error for malformed JSON" do
      malformed_json = '{"version": "1.0", "rules": [,,,]}'

      expect {
        DecisionAgent::Dsl::RuleParser.parse(malformed_json)
      }.to raise_error(DecisionAgent::InvalidRuleDslError) do |error|
        expect(error.message).to include("Invalid JSON syntax")
        expect(error.message).to include("Common issues")
      end
    end

    it "accepts hash input" do
      rules_hash = {
        version: "1.0",
        rules: [
          {
            id: "rule_1",
            if: { field: "status", op: "eq", value: "active" },
            then: { decision: "approve" }
          }
        ]
      }

      expect {
        DecisionAgent::Dsl::RuleParser.parse(rules_hash)
      }.not_to raise_error
    end

    it "rejects invalid input types" do
      expect {
        DecisionAgent::Dsl::RuleParser.parse(12345)
      }.to raise_error(DecisionAgent::InvalidRuleDslError, /Expected JSON string or Hash/)
    end
  end
end
