# frozen_string_literal: true

module DecisionAgent
  module DataEnrichment
    # Base class for cache adapters
    class CacheAdapter
      # Get cached value
      #
      # @param key [String] Cache key
      # @return [Hash, nil] Cached data or nil if not found/expired
      def get(key)
        raise NotImplementedError, "#{self.class} must implement #get"
      end

      # Set cached value
      #
      # @param key [String] Cache key
      # @param value [Hash] Data to cache
      # @param ttl [Integer] Time to live in seconds
      def set(key, value, ttl)
        raise NotImplementedError, "#{self.class} must implement #set"
      end

      # Delete cached value
      #
      # @param key [String] Cache key
      def delete(key)
        raise NotImplementedError, "#{self.class} must implement #delete"
      end

      # Clear all cached values
      def clear
        raise NotImplementedError, "#{self.class} must implement #clear"
      end

      # Generate cache key from request parameters
      #
      # @param endpoint_name [Symbol] Endpoint identifier
      # @param params [Hash] Request parameters
      # @return [String] Cache key
      def cache_key(endpoint_name, params)
        # Sort params for consistent key generation
        sorted_params = params.sort.to_h
        param_string = sorted_params.map { |k, v| "#{k}=#{v}" }.join("&")
        "#{endpoint_name}:#{Digest::SHA256.hexdigest(param_string)}"
      end
    end
  end
end
