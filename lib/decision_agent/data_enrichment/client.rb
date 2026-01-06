# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "base64"
require_relative "cache_adapter"
require_relative "cache/memory_adapter"
require_relative "circuit_breaker"
require_relative "errors"

module DecisionAgent
  module DataEnrichment
    # HTTP client for data enrichment requests
    class Client
      # Error classes
      class RequestError < StandardError
        attr_reader :status_code, :response_body

        def initialize(message, status_code: nil, response_body: nil)
          super(message)
          @status_code = status_code
          @response_body = response_body
        end
      end

      class TimeoutError < RequestError
      end

      class NetworkError < RequestError
      end

      attr_reader :config, :cache_adapter, :circuit_breaker

      def initialize(config:, cache_adapter: nil, circuit_breaker: nil)
        @config = config
        @cache_adapter = cache_adapter || Cache::MemoryAdapter.new
        @circuit_breakers = {}
        @circuit_breaker_default = circuit_breaker || CircuitBreaker.new
        @circuit_breaker = @circuit_breaker_default
      end

      # Fetch data from configured endpoint
      #
      # @param endpoint_name [Symbol] Endpoint identifier
      # @param params [Hash] Request parameters
      # @param use_cache [Boolean] Whether to use cache (default: true)
      # @return [Hash] Response data
      # @raise [RequestError] If request fails
      def fetch(endpoint_name, params: {}, use_cache: true)
        endpoint_config = @config.endpoint(endpoint_name)
        raise ArgumentError, "Unknown endpoint: #{endpoint_name}" unless endpoint_config

        # Generate cache key
        cache_key = @cache_adapter.cache_key(endpoint_name, params)

        # Check cache first
        if use_cache
          cached = @cache_adapter.get(cache_key)
          return cached if cached
        end

        # Execute request with circuit breaker
        circuit_breaker = get_circuit_breaker(endpoint_name)
        begin
          response_data = circuit_breaker.call do
            execute_request(endpoint_name, endpoint_config, params)
          end
        rescue CircuitBreaker::CircuitOpenError => e
          # Try to return cached data on circuit open
          cached = @cache_adapter.get(cache_key) if use_cache
          return cached if cached

          raise RequestError, "Circuit breaker is open for #{endpoint_name}: #{e.message}"
        end

        # Cache response
        @cache_adapter.set(cache_key, response_data, endpoint_config[:cache][:ttl]) if use_cache && endpoint_config[:cache][:ttl].positive?

        response_data
      end

      # Clear cache for endpoint
      #
      # @param endpoint_name [Symbol, nil] Endpoint identifier, or nil to clear all
      def clear_cache(endpoint_name = nil)
        if endpoint_name
          # Clear cache entries for this endpoint (requires cache adapter support)
          # For now, just clear all if endpoint-specific clearing isn't supported
        end
        @cache_adapter.clear
      end

      private

      def execute_request(endpoint_name, endpoint_config, params)
        uri = URI(endpoint_config[:url])
        method = endpoint_config[:method]
        timeout = endpoint_config[:timeout]

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.read_timeout = timeout
        http.open_timeout = timeout

        request = build_request(uri, method, endpoint_config, params)

        response = http.request(request)

        handle_response(response, endpoint_name)
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise TimeoutError, "Request timeout for #{endpoint_name}: #{e.message}"
      rescue StandardError => e
        raise NetworkError, "Network error for #{endpoint_name}: #{e.message}"
      end

      def build_request(uri, method, endpoint_config, params)
        headers = endpoint_config[:headers].dup || {}
        apply_auth(headers, endpoint_config[:auth])

        case method
        when :get
          # Add params to query string for GET requests
          if params.any?
            query_string = URI.encode_www_form(params)
            uri_with_query = URI("#{uri}?#{query_string}")
            request = Net::HTTP::Get.new(uri_with_query)
          else
            request = Net::HTTP::Get.new(uri)
          end
        when :post
          request = Net::HTTP::Post.new(uri)
          request.body = params.to_json
          headers["Content-Type"] ||= "application/json"
        when :put
          request = Net::HTTP::Put.new(uri)
          request.body = params.to_json
          headers["Content-Type"] ||= "application/json"
        when :delete
          request = Net::HTTP::Delete.new(uri)
        else
          raise ArgumentError, "Unsupported HTTP method: #{method}"
        end

        headers.each { |k, v| request[k] = v }
        request
      end

      def apply_auth(headers, auth_config)
        return unless auth_config

        case auth_config[:type]
        when :api_key
          header_name = auth_config[:header] || "X-API-Key"
          api_key = get_secret(auth_config[:secret_key] || "API_KEY")
          headers[header_name] = api_key
        when :basic
          username = get_secret(auth_config[:username_key] || "USERNAME")
          password = get_secret(auth_config[:password_key] || "PASSWORD")
          credentials = Base64.strict_encode64("#{username}:#{password}")
          headers["Authorization"] = "Basic #{credentials}"
        when :bearer
          token = get_secret(auth_config[:token_key] || "TOKEN")
          headers["Authorization"] = "Bearer #{token}"
        end
      end

      def get_secret(key)
        # Try environment variable first
        return ENV[key] if ENV.key?(key)
        return ENV[key.upcase] if ENV.key?(key.upcase)

        # Could extend to support vault integration here
        raise ArgumentError, "Secret not found: #{key}. Set environment variable #{key.upcase}"
      end

      def handle_response(response, endpoint_name)
        case response.code.to_i
        when 200..299
          parse_response(response)
        when 400..499
          raise RequestError.new(
            "Client error for #{endpoint_name}: HTTP #{response.code}",
            status_code: response.code.to_i,
            response_body: response.body
          )
        when 500..599
          raise RequestError.new(
            "Server error for #{endpoint_name}: HTTP #{response.code}",
            status_code: response.code.to_i,
            response_body: response.body
          )
        else
          raise RequestError.new(
            "Unexpected response for #{endpoint_name}: HTTP #{response.code}",
            status_code: response.code.to_i,
            response_body: response.body
          )
        end
      end

      def parse_response(response)
        content_type = response["Content-Type"] || ""
        body = response.body

        return {} if body.nil? || body.empty?

        if content_type.include?("application/json")
          JSON.parse(body, symbolize_names: true)
        else
          { body: body, content_type: content_type }
        end
      end

      def get_circuit_breaker(endpoint_name)
        @circuit_breakers[endpoint_name] ||= @circuit_breaker_default.dup
      end
    end
  end
end
