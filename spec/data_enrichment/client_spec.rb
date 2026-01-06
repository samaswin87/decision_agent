# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe DecisionAgent::DataEnrichment::Client do
  let(:config) { DecisionAgent::DataEnrichment::Config.new }
  let(:cache_adapter) { DecisionAgent::DataEnrichment::Cache::MemoryAdapter.new }
  let(:circuit_breaker) { DecisionAgent::DataEnrichment::CircuitBreaker.new }
  let(:client) { described_class.new(config: config, cache_adapter: cache_adapter, circuit_breaker: circuit_breaker) }

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  after do
    WebMock.allow_net_connect!
  end

  describe "#initialize" do
    it "initializes with config" do
      expect(client.config).to eq(config)
    end

    it "uses default cache adapter if not provided" do
      client_without_cache = described_class.new(config: config)
      expect(client_without_cache.cache_adapter).to be_a(DecisionAgent::DataEnrichment::Cache::MemoryAdapter)
    end

    it "uses default circuit breaker if not provided" do
      client_without_breaker = described_class.new(config: config)
      expect(client_without_breaker.circuit_breaker).to be_a(DecisionAgent::DataEnrichment::CircuitBreaker)
    end
  end

  describe "#fetch" do
    context "with GET request" do
      before do
        config.add_endpoint(:test_get, url: "https://api.example.com/data", method: :get)
      end

      it "fetches data from endpoint" do
        stub_request(:get, "https://api.example.com/data?key=value")
          .to_return(status: 200, body: '{"result": "success"}', headers: { "Content-Type" => "application/json" })

        result = client.fetch(:test_get, params: { key: "value" })

        expect(result).to eq({ result: "success" })
      end

      it "handles empty response" do
        stub_request(:get, "https://api.example.com/data")
          .to_return(status: 200, body: "", headers: {})

        result = client.fetch(:test_get, params: {})

        expect(result).to eq({})
      end

      it "raises error for unknown endpoint" do
        expect { client.fetch(:unknown) }.to raise_error(ArgumentError, /Unknown endpoint/)
      end
    end

    context "with POST request" do
      before do
        config.add_endpoint(:test_post, url: "https://api.example.com/data", method: :post)
      end

      it "sends POST request with JSON body" do
        stub_request(:post, "https://api.example.com/data")
          .with(
            body: { user_id: "123", amount: 100 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: '{"status": "processed"}', headers: { "Content-Type" => "application/json" })

        result = client.fetch(:test_post, params: { user_id: "123", amount: 100 })

        expect(result).to eq({ status: "processed" })
      end
    end

    context "with PUT request" do
      before do
        config.add_endpoint(:test_put, url: "https://api.example.com/data", method: :put)
      end

      it "sends PUT request with JSON body" do
        stub_request(:put, "https://api.example.com/data")
          .with(
            body: { id: "1", name: "updated" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: '{"id": "1", "name": "updated"}', headers: { "Content-Type" => "application/json" })

        result = client.fetch(:test_put, params: { id: "1", name: "updated" })

        expect(result).to eq({ id: "1", name: "updated" })
      end
    end

    context "with DELETE request" do
      before do
        config.add_endpoint(:test_delete, url: "https://api.example.com/data", method: :delete)
      end

      it "sends DELETE request" do
        stub_request(:delete, "https://api.example.com/data")
          .to_return(status: 200, body: '{"deleted": true}', headers: { "Content-Type" => "application/json" })

        result = client.fetch(:test_delete, params: {})

        expect(result).to eq({ deleted: true })
      end
    end

    context "with authentication" do
      context "API key authentication" do
        before do
          config.add_endpoint(:api_key_test,
                              url: "https://api.example.com/data",
                              auth: { type: :api_key, header: "X-API-Key", secret_key: "TEST_API_KEY" })
          ENV["TEST_API_KEY"] = "secret-key-123"
        end

        after do
          ENV.delete("TEST_API_KEY")
        end

        it "includes API key in header" do
          stub_request(:get, "https://api.example.com/data")
            .with(headers: { "X-API-Key" => "secret-key-123" })
            .to_return(status: 200, body: '{"authenticated": true}', headers: { "Content-Type" => "application/json" })

          result = client.fetch(:api_key_test, params: {})

          expect(result).to eq({ authenticated: true })
        end
      end

      context "Basic authentication" do
        before do
          config.add_endpoint(:basic_test,
                              url: "https://api.example.com/data",
                              auth: { type: :basic, username_key: "API_USER", password_key: "API_PASS" })
          ENV["API_USER"] = "user"
          ENV["API_PASS"] = "pass"
        end

        after do
          ENV.delete("API_USER")
          ENV.delete("API_PASS")
        end

        it "includes Basic auth header" do
          expected_auth = Base64.strict_encode64("user:pass")
          stub_request(:get, "https://api.example.com/data")
            .with(headers: { "Authorization" => "Basic #{expected_auth}" })
            .to_return(status: 200, body: '{"authenticated": true}', headers: { "Content-Type" => "application/json" })

          result = client.fetch(:basic_test, params: {})

          expect(result).to eq({ authenticated: true })
        end
      end

      context "Bearer token authentication" do
        before do
          config.add_endpoint(:bearer_test,
                              url: "https://api.example.com/data",
                              auth: { type: :bearer, token_key: "API_TOKEN" })
          ENV["API_TOKEN"] = "bearer-token-123"
        end

        after do
          ENV.delete("API_TOKEN")
        end

        it "includes Bearer token in header" do
          stub_request(:get, "https://api.example.com/data")
            .with(headers: { "Authorization" => "Bearer bearer-token-123" })
            .to_return(status: 200, body: '{"authenticated": true}', headers: { "Content-Type" => "application/json" })

          result = client.fetch(:bearer_test, params: {})

          expect(result).to eq({ authenticated: true })
        end
      end
    end

    context "with caching" do
      before do
        config.add_endpoint(:cached_endpoint,
                            url: "https://api.example.com/data",
                            cache: { ttl: 3600, adapter: :memory })
      end

      it "caches successful responses" do
        stub_request(:get, "https://api.example.com/data")
          .to_return(status: 200, body: '{"cached": true}', headers: { "Content-Type" => "application/json" })
          .times(1) # Only expect one request

        # First call - should make HTTP request
        result1 = client.fetch(:cached_endpoint, params: {})
        expect(result1).to eq({ cached: true })

        # Second call - should use cache
        result2 = client.fetch(:cached_endpoint, params: {})
        expect(result2).to eq({ cached: true })
      end

      it "can bypass cache" do
        stub_request(:get, "https://api.example.com/data")
          .to_return(status: 200, body: '{"fresh": true}', headers: { "Content-Type" => "application/json" })
          .times(2) # Expect two requests

        # First call with cache
        client.fetch(:cached_endpoint, params: {}, use_cache: true)

        # Second call without cache
        result = client.fetch(:cached_endpoint, params: {}, use_cache: false)
        expect(result).to eq({ fresh: true })
      end
    end

    context "with circuit breaker" do
      before do
        config.add_endpoint(:failing_endpoint, url: "https://api.example.com/data")
      end

      it "opens circuit after failures" do
        stub_request(:get, "https://api.example.com/data")
          .to_return(status: 500, body: "Internal Server Error")
          .times(3) # Fail 3 times to open circuit

        # Trigger failures
        3.times do
          client.fetch(:failing_endpoint, params: {})
        rescue StandardError
          # Expected
        end

        # Circuit should be open now
        expect { client.fetch(:failing_endpoint, params: {}) }.to raise_error(DecisionAgent::DataEnrichment::Client::RequestError, /Circuit breaker is open/)
      end

      it "falls back to cache when circuit is open" do
        stub_request(:get, "https://api.example.com/data")
          .to_return(status: 200, body: '{"cached": true}', headers: { "Content-Type" => "application/json" })
          .times(1)

        # First successful call to populate cache
        client.fetch(:failing_endpoint, params: {})

        # Open circuit by failing
        stub_request(:get, "https://api.example.com/data")
          .to_return(status: 500, body: "Internal Server Error")
          .times(3)

        3.times do
          client.fetch(:failing_endpoint, params: {})
        rescue StandardError
          # Expected
        end

        # Should return cached data
        result = client.fetch(:failing_endpoint, params: {})
        expect(result).to eq({ cached: true })
      end
    end

    context "error handling" do
      before do
        config.add_endpoint(:test_endpoint, url: "https://api.example.com/data")
      end

      it "raises RequestError for 4xx responses" do
        stub_request(:get, "https://api.example.com/data")
          .to_return(status: 400, body: '{"error": "Bad Request"}', headers: { "Content-Type" => "application/json" })

        expect { client.fetch(:test_endpoint, params: {}) }.to raise_error(
          DecisionAgent::DataEnrichment::Client::RequestError,
          /Client error/
        )
      end

      it "raises RequestError for 5xx responses" do
        stub_request(:get, "https://api.example.com/data")
          .to_return(status: 500, body: "Internal Server Error")

        expect { client.fetch(:test_endpoint, params: {}) }.to raise_error(
          DecisionAgent::DataEnrichment::Client::RequestError,
          /Server error/
        )
      end

      it "raises TimeoutError for timeout" do
        stub_request(:get, "https://api.example.com/data")
          .to_timeout

        expect { client.fetch(:test_endpoint, params: {}) }.to raise_error(
          DecisionAgent::DataEnrichment::Client::TimeoutError
        )
      end

      it "raises NetworkError for network issues" do
        stub_request(:get, "https://api.example.com/data")
          .to_raise(SocketError.new("Connection refused"))

        expect { client.fetch(:test_endpoint, params: {}) }.to raise_error(
          DecisionAgent::DataEnrichment::Client::NetworkError
        )
      end
    end

    context "with custom headers" do
      before do
        config.add_endpoint(:custom_headers,
                            url: "https://api.example.com/data",
                            headers: { "User-Agent" => "DecisionAgent/1.0", "X-Custom" => "value" })
      end

      it "includes custom headers in request" do
        stub_request(:get, "https://api.example.com/data")
          .with(headers: { "User-Agent" => "DecisionAgent/1.0", "X-Custom" => "value" })
          .to_return(status: 200, body: '{"success": true}', headers: { "Content-Type" => "application/json" })

        result = client.fetch(:custom_headers, params: {})

        expect(result).to eq({ success: true })
      end
    end

    context "with non-JSON response" do
      before do
        config.add_endpoint(:xml_endpoint, url: "https://api.example.com/data")
      end

      it "handles XML response" do
        stub_request(:get, "https://api.example.com/data")
          .to_return(status: 200, body: "<xml>data</xml>", headers: { "Content-Type" => "application/xml" })

        result = client.fetch(:xml_endpoint, params: {})

        expect(result).to eq({ body: "<xml>data</xml>", content_type: "application/xml" })
      end
    end
  end

  describe "#clear_cache" do
    before do
      config.add_endpoint(:test_endpoint, url: "https://api.example.com/data")
    end

    it "clears all cache" do
      stub_request(:get, "https://api.example.com/data")
        .to_return(status: 200, body: '{"data": "first"}', headers: { "Content-Type" => "application/json" })
        .times(2)

      # First call - populate cache
      client.fetch(:test_endpoint, params: {})

      # Clear cache
      client.clear_cache

      # Second call - should make new request
      result = client.fetch(:test_endpoint, params: {})
      expect(result).to eq({ data: "first" })
    end
  end
end
