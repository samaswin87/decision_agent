# frozen_string_literal: true

module DecisionAgent
  module DataEnrichment
    # Configuration for data enrichment endpoints
    class Config
      attr_accessor :endpoints, :default_timeout, :default_retry, :default_cache

      def initialize
        @endpoints = {}
        @default_timeout = 5 # seconds
        @default_retry = { max_attempts: 3, backoff: :exponential }
        @default_cache = { ttl: 3600, adapter: :memory }
      end

      # Add or update an endpoint configuration
      #
      # @param name [Symbol] Endpoint identifier
      # @param url [String] Base URL for the endpoint
      # @param method [Symbol] HTTP method (:get, :post, :put, :delete)
      # @param auth [Hash] Authentication configuration
      # @param cache [Hash] Cache configuration
      # @param retry_config [Hash] Retry configuration
      # @param timeout [Integer] Request timeout in seconds
      # @param headers [Hash] Default headers
      # @param rate_limit [Hash] Rate limiting configuration
      #
      # @example
      #   config.add_endpoint(:credit_bureau,
      #     url: "https://api.creditbureau.com/v1/score",
      #     method: :post,
      #     auth: { type: :api_key, header: "X-API-Key" },
      #     cache: { ttl: 3600, adapter: :redis },
      #     retry_config: { max_attempts: 3, backoff: :exponential }
      #   )
      def add_endpoint(name, url:, method: :get, auth: nil, cache: nil, retry_config: nil, timeout: nil, headers: {}, rate_limit: nil) # rubocop:disable Metrics/ParameterLists
        @endpoints[name.to_sym] = {
          url: url,
          method: method.to_sym,
          auth: auth,
          cache: cache || @default_cache.dup,
          retry: retry_config || @default_retry.dup,
          timeout: timeout || @default_timeout,
          headers: headers,
          rate_limit: rate_limit
        }
      end

      # Get endpoint configuration
      #
      # @param name [Symbol] Endpoint identifier
      # @return [Hash, nil] Endpoint configuration or nil if not found
      def endpoint(name)
        @endpoints[name.to_sym]
      end

      # Check if endpoint exists
      #
      # @param name [Symbol] Endpoint identifier
      # @return [Boolean]
      def endpoint?(name)
        @endpoints.key?(name.to_sym)
      end

      # Remove endpoint configuration
      #
      # @param name [Symbol] Endpoint identifier
      def remove_endpoint(name)
        @endpoints.delete(name.to_sym)
      end

      # Clear all endpoint configurations
      def clear
        @endpoints.clear
      end
    end
  end
end
