# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe "Data Enrichment: fetch_from_api operator integration" do
  before do
    WebMock.disable_net_connect!(allow_localhost: true)
    # Configure data enrichment
    DecisionAgent.configure_data_enrichment do |c|
      c.add_endpoint(:credit_bureau,
                     url: "https://api.creditbureau.com/v1/score",
                     method: :post,
                     cache: { ttl: 3600, adapter: :memory })

      c.add_endpoint(:fraud_check,
                     url: "https://api.fraudservice.com/check",
                     method: :post,
                     cache: { ttl: 300, adapter: :memory })
    end
  end

  after do
    WebMock.allow_net_connect!
    DecisionAgent.data_enrichment_config.clear
    DecisionAgent.data_enrichment_client = nil
  end

  describe "basic fetch_from_api usage" do
    it "fetches data from API and uses it in rule condition" do
      # Mock API response
      stub_request(:post, "https://api.creditbureau.com/v1/score")
        .with(body: { ssn: "123-45-6789" }.to_json)
        .to_return(
          status: 200,
          body: { score: 750, risk_level: "low" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      rules = {
        version: "1.0",
        ruleset: "loan_approval",
        rules: [
          {
            id: "check_credit_score",
            if: {
              all: [
                {
                  field: "credit_score",
                  op: "fetch_from_api",
                  value: {
                    endpoint: "credit_bureau",
                    params: { ssn: "{{customer.ssn}}" },
                    mapping: { score: "credit_score" }
                  }
                },
                {
                  field: "credit_score",
                  op: "gte",
                  value: 700
                }
              ]
            },
            then: {
              decision: "approve",
              weight: 0.8,
              reason: "Credit score verified and meets threshold"
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ customer: { ssn: "123-45-6789" } })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("approve")
      expect(evaluation.weight).to eq(0.8)
    end

    it "returns false when API call fails" do
      # Mock API failure
      stub_request(:post, "https://api.creditbureau.com/v1/score")
        .to_return(status: 500, body: "Internal Server Error")

      rules = {
        version: "1.0",
        ruleset: "loan_approval",
        rules: [
          {
            id: "check_credit_score",
            if: {
              field: "credit_score",
              op: "fetch_from_api",
              value: {
                endpoint: "credit_bureau",
                params: { ssn: "{{customer.ssn}}" }
              }
            },
            then: {
              decision: "approve",
              weight: 0.8
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ customer: { ssn: "123-45-6789" } })

      evaluation = evaluator.evaluate(context)

      # Should return nil because fetch_from_api returns false on error
      expect(evaluation).to be_nil
    end

    it "handles missing endpoint gracefully" do
      rules = {
        version: "1.0",
        ruleset: "loan_approval",
        rules: [
          {
            id: "check_credit_score",
            if: {
              field: "credit_score",
              op: "fetch_from_api",
              value: {
                endpoint: "nonexistent_endpoint",
                params: {}
              }
            },
            then: {
              decision: "approve"
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({})

      # Should not raise error, but return nil
      evaluation = evaluator.evaluate(context)
      expect(evaluation).to be_nil
    end
  end

  describe "template parameter expansion" do
    it "expands template parameters from context" do
      stub_request(:post, "https://api.fraudservice.com/check")
        .with(
          body: "{\"user_id\":\"user123\",\"amount\":\"1000\",\"ip_address\":\"192.168.1.1\"}"
        )
        .to_return(
          status: 200,
          body: { risk_score: 0.3, flagged: false }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      rules = {
        version: "1.0",
        ruleset: "fraud_detection",
        rules: [
          {
            id: "fraud_check",
            if: {
              field: "fraud_score",
              op: "fetch_from_api",
              value: {
                endpoint: "fraud_check",
                params: {
                  user_id: "{{user.id}}",
                  amount: "{{transaction.amount}}",
                  ip_address: "{{transaction.ip}}"
                },
                mapping: { risk_score: "fraud_score" }
              }
            },
            then: {
              decision: "approve",
              weight: 0.9
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({
                                             user: { id: "user123" },
                                             transaction: { amount: 1000, ip: "192.168.1.1" }
                                           })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("approve")
    end

    it "handles missing template parameters" do
      stub_request(:post, "https://api.fraudservice.com/check")
        .with(
          body: /"user_id":"{{user.id}}"|"user_id":""/
        )
        .to_return(
          status: 200,
          body: { risk_score: 0.5 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      rules = {
        version: "1.0",
        ruleset: "fraud_detection",
        rules: [
          {
            id: "fraud_check",
            if: {
              field: "fraud_score",
              op: "fetch_from_api",
              value: {
                endpoint: "fraud_check",
                params: {
                  user_id: "{{user.id}}",
                  amount: "{{transaction.amount}}",
                  ip_address: "{{transaction.ip}}"
                }
              }
            },
            then: {
              decision: "approve"
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({})

      # Should still work, but with empty/missing values
      evaluation = evaluator.evaluate(context)
      expect(evaluation).not_to be_nil
    end
  end

  describe "response mapping" do
    it "maps API response fields to context fields" do
      stub_request(:post, "https://api.creditbureau.com/v1/score")
        .to_return(
          status: 200,
          body: {
            score: 750,
            risk_level: "low",
            last_updated: "2025-01-01T00:00:00Z"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      rules = {
        version: "1.0",
        ruleset: "loan_approval",
        rules: [
          {
            id: "check_credit",
            if: {
              field: "credit_score",
              op: "fetch_from_api",
              value: {
                endpoint: "credit_bureau",
                params: { ssn: "{{customer.ssn}}" },
                mapping: {
                  score: "credit_score",
                  risk_level: "risk_level",
                  last_updated: "credit_last_updated"
                }
              }
            },
            then: {
              decision: "approve",
              weight: 0.8
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ customer: { ssn: "123-45-6789" } })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("approve")
    end

    it "returns true when mapping is applied successfully" do
      stub_request(:post, "https://api.creditbureau.com/v1/score")
        .to_return(
          status: 200,
          body: { score: 750 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      rules = {
        version: "1.0",
        ruleset: "loan_approval",
        rules: [
          {
            id: "check_credit",
            if: {
              field: "credit_score",
              op: "fetch_from_api",
              value: {
                endpoint: "credit_bureau",
                params: { ssn: "{{customer.ssn}}" },
                mapping: { score: "credit_score" }
              }
            },
            then: {
              decision: "approve"
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ customer: { ssn: "123-45-6789" } })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
    end
  end

  describe "caching behavior" do
    it "uses cached response on second call" do
      stub_request(:post, "https://api.creditbureau.com/v1/score")
        .with(body: { ssn: "123-45-6789" }.to_json)
        .to_return(
          status: 200,
          body: { score: 750 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
        .times(1) # Only expect one HTTP request

      rules = {
        version: "1.0",
        ruleset: "loan_approval",
        rules: [
          {
            id: "check_credit_score",
            if: {
              field: "credit_score",
              op: "fetch_from_api",
              value: {
                endpoint: "credit_bureau",
                params: { ssn: "{{customer.ssn}}" },
                mapping: { score: "credit_score" }
              }
            },
            then: {
              decision: "approve"
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ customer: { ssn: "123-45-6789" } })

      # First call - should make HTTP request
      evaluation1 = evaluator.evaluate(context)
      expect(evaluation1).not_to be_nil

      # Second call - should use cache
      evaluation2 = evaluator.evaluate(context)
      expect(evaluation2).not_to be_nil
      expect(evaluation2.decision).to eq("approve")
    end
  end

  describe "combined with other operators" do
    it "works with all condition" do
      stub_request(:post, "https://api.creditbureau.com/v1/score")
        .to_return(
          status: 200,
          body: { score: 750 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      rules = {
        version: "1.0",
        ruleset: "loan_approval",
        rules: [
          {
            id: "check_credit_and_amount",
            if: {
              all: [
                {
                  field: "credit_score",
                  op: "fetch_from_api",
                  value: {
                    endpoint: "credit_bureau",
                    params: { ssn: "{{customer.ssn}}" },
                    mapping: { score: "credit_score" }
                  }
                },
                {
                  field: "credit_score",
                  op: "gte",
                  value: 700
                },
                {
                  field: "loan_amount",
                  op: "lte",
                  value: 100_000
                }
              ]
            },
            then: {
              decision: "approve",
              weight: 0.9
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({
                                             customer: { ssn: "123-45-6789" },
                                             loan_amount: 50_000
                                           })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("approve")
      expect(evaluation.weight).to eq(0.9)
    end

    it "works with any condition" do
      stub_request(:post, "https://api.creditbureau.com/v1/score")
        .to_return(
          status: 200,
          body: { score: 650 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      rules = {
        version: "1.0",
        ruleset: "loan_approval",
        rules: [
          {
            id: "check_credit_or_co_signer",
            if: {
              any: [
                {
                  field: "credit_score",
                  op: "fetch_from_api",
                  value: {
                    endpoint: "credit_bureau",
                    params: { ssn: "{{customer.ssn}}" },
                    mapping: { score: "credit_score" }
                  }
                },
                {
                  field: "has_co_signer",
                  op: "eq",
                  value: true
                }
              ]
            },
            then: {
              decision: "approve",
              weight: 0.7
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({
                                             customer: { ssn: "123-45-6789" },
                                             has_co_signer: false
                                           })

      evaluation = evaluator.evaluate(context)

      expect(evaluation).not_to be_nil
      expect(evaluation.decision).to eq("approve")
    end
  end

  describe "error handling" do
    it "handles timeout gracefully" do
      stub_request(:post, "https://api.creditbureau.com/v1/score")
        .to_timeout

      rules = {
        version: "1.0",
        ruleset: "loan_approval",
        rules: [
          {
            id: "check_credit_score",
            if: {
              field: "credit_score",
              op: "fetch_from_api",
              value: {
                endpoint: "credit_bureau",
                params: { ssn: "{{customer.ssn}}" }
              }
            },
            then: {
              decision: "approve"
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ customer: { ssn: "123-45-6789" } })

      # Should not raise error, but return nil
      evaluation = evaluator.evaluate(context)
      expect(evaluation).to be_nil
    end

    it "handles network errors gracefully" do
      stub_request(:post, "https://api.creditbureau.com/v1/score")
        .to_raise(SocketError.new("Connection refused"))

      rules = {
        version: "1.0",
        ruleset: "loan_approval",
        rules: [
          {
            id: "check_credit_score",
            if: {
              field: "credit_score",
              op: "fetch_from_api",
              value: {
                endpoint: "credit_bureau",
                params: { ssn: "{{customer.ssn}}" }
              }
            },
            then: {
              decision: "approve"
            }
          }
        ]
      }

      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
      context = DecisionAgent::Context.new({ customer: { ssn: "123-45-6789" } })

      # Should not raise error, but return nil
      evaluation = evaluator.evaluate(context)
      expect(evaluation).to be_nil
    end
  end
end
