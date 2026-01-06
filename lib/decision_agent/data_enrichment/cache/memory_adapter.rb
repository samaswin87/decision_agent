# frozen_string_literal: true

require_relative "../cache_adapter"
require "monitor"

module DecisionAgent
  module DataEnrichment
    module Cache
      # In-memory cache adapter (default, no dependencies)
      class MemoryAdapter < CacheAdapter
        include MonitorMixin

        def initialize
          super
          @cache = {}
        end

        # Get cached value
        #
        # @param key [String] Cache key
        # @return [Hash, nil] Cached data or nil if not found/expired
        def get(key)
          synchronize do
            entry = @cache[key]
            return nil unless entry

            # Check if expired
            if entry[:expires_at] < Time.now
              @cache.delete(key)
              return nil
            end

            entry[:value]
          end
        end

        # Set cached value
        #
        # @param key [String] Cache key
        # @param value [Hash] Data to cache
        # @param ttl [Integer] Time to live in seconds
        def set(key, value, ttl)
          synchronize do
            @cache[key] = {
              value: value,
              expires_at: Time.now + ttl
            }
          end
        end

        # Delete cached value
        #
        # @param key [String] Cache key
        def delete(key)
          synchronize do
            @cache.delete(key)
          end
        end

        # Clear all cached values
        def clear
          synchronize do
            @cache.clear
          end
        end

        # Get cache statistics
        #
        # @return [Hash] Cache statistics
        def stats
          synchronize do
            now = Time.now
            valid_entries = @cache.count { |_k, v| v[:expires_at] >= now }
            expired_entries = @cache.size - valid_entries

            {
              size: @cache.size,
              valid: valid_entries,
              expired: expired_entries
            }
          end
        end
      end
    end
  end
end
