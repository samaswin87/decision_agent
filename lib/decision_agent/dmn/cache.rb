# frozen_string_literal: true

require "digest"
require "zlib"

module DecisionAgent
  module Dmn
    # DMN Evaluation Cache
    # Provides caching for DMN model parsing and evaluation results
    class EvaluationCache
      attr_reader :model_cache, :result_cache, :stats

      def initialize(max_model_cache_size: 100, max_result_cache_size: 1000, ttl: 3600)
        @model_cache = {}
        @result_cache = {}
        @max_model_cache_size = max_model_cache_size
        @max_result_cache_size = max_result_cache_size
        @ttl = ttl # Time to live in seconds
        @mutex = Mutex.new
        @stats = {
          model_cache_hits: 0,
          model_cache_misses: 0,
          result_cache_hits: 0,
          result_cache_misses: 0
        }
      end

      # Cache a parsed DMN model
      def cache_model(model_id, model)
        @mutex.synchronize do
          # Evict oldest if cache is full
          evict_oldest_model if @model_cache.size >= @max_model_cache_size

          @model_cache[model_id] = {
            model: model,
            cached_at: Time.now.to_i
          }
        end
      end

      # Get a cached model
      def get_model(model_id)
        @mutex.synchronize do
          entry = @model_cache[model_id]

          if entry && !expired?(entry[:cached_at])
            @stats[:model_cache_hits] += 1
            entry[:model]
          else
            @stats[:model_cache_misses] += 1
            @model_cache.delete(model_id) if entry
            nil
          end
        end
      end

      # Cache an evaluation result
      def cache_result(decision_id, context_hash, result)
        @mutex.synchronize do
          # Evict oldest if cache is full
          evict_oldest_result if @result_cache.size >= @max_result_cache_size

          cache_key = generate_result_key(decision_id, context_hash)
          @result_cache[cache_key] = {
            result: result,
            cached_at: Time.now.to_i
          }
        end
      end

      # Get a cached evaluation result
      def get_result(decision_id, context_hash)
        @mutex.synchronize do
          cache_key = generate_result_key(decision_id, context_hash)
          entry = @result_cache[cache_key]

          if entry && !expired?(entry[:cached_at])
            @stats[:result_cache_hits] += 1
            entry[:result]
          else
            @stats[:result_cache_misses] += 1
            @result_cache.delete(cache_key) if entry
            nil
          end
        end
      end

      # Clear all caches
      def clear
        @mutex.synchronize do
          @model_cache.clear
          @result_cache.clear
          @stats.each_key { |k| @stats[k] = 0 }
        end
      end

      # Clear model cache
      def clear_models
        @mutex.synchronize do
          @model_cache.clear
        end
      end

      # Clear result cache
      def clear_results
        @mutex.synchronize do
          @result_cache.clear
        end
      end

      # Get cache statistics
      def statistics
        @mutex.synchronize do
          model_hit_rate = calculate_hit_rate(@stats[:model_cache_hits], @stats[:model_cache_misses])
          result_hit_rate = calculate_hit_rate(@stats[:result_cache_hits], @stats[:result_cache_misses])

          @stats.merge(
            model_cache_size: @model_cache.size,
            result_cache_size: @result_cache.size,
            model_hit_rate: model_hit_rate,
            result_hit_rate: result_hit_rate
          )
        end
      end

      private

      def expired?(cached_at)
        (Time.now.to_i - cached_at) > @ttl
      end

      def evict_oldest_model
        return if @model_cache.empty?

        oldest_key = @model_cache.min_by { |_k, v| v[:cached_at] }[0]
        @model_cache.delete(oldest_key)
      end

      def evict_oldest_result
        return if @result_cache.empty?

        oldest_key = @result_cache.min_by { |_k, v| v[:cached_at] }[0]
        @result_cache.delete(oldest_key)
      end

      def generate_result_key(decision_id, context_hash)
        Digest::SHA256.hexdigest("#{decision_id}:#{context_hash}")
      end

      def calculate_hit_rate(hits, misses)
        total = hits + misses
        total.positive? ? (hits.to_f / total * 100).round(2) : 0
      end
    end

    # Enhanced DMN Evaluator with Caching
    class CachedDmnEvaluator
      attr_reader :cache, :evaluator

      def initialize(dmn_model:, decision_id:, cache: nil, enable_caching: true)
        @dmn_model = dmn_model
        @decision_id = decision_id
        @cache = cache || EvaluationCache.new
        @enable_caching = enable_caching

        # Create the underlying evaluator
        @evaluator = Evaluators::DmnEvaluator.new(
          dmn_model: dmn_model,
          decision_id: decision_id
        )
      end

      # Evaluate with caching
      def evaluate(context:)
        return @evaluator.evaluate(context: context) unless @enable_caching

        # Generate context hash for cache key
        context_hash = generate_context_hash(context)

        # Try to get cached result
        cached_result = @cache.get_result(@decision_id, context_hash)
        return cached_result if cached_result

        # Evaluate and cache result
        result = @evaluator.evaluate(context: context)
        @cache.cache_result(@decision_id, context_hash, result)

        result
      end

      # Warm up cache with common inputs
      def warm_cache(input_samples)
        input_samples.each do |inputs|
          context = Context.new(inputs)
          evaluate(context: context)
        end
      end

      # Get cache statistics
      def cache_stats
        @cache.statistics
      end

      # Clear cache
      def clear_cache
        @cache.clear_results
      end

      private

      def generate_context_hash(context)
        # Create a deterministic hash of the context
        # Use CRC32 for better performance (much faster than SHA256, still deterministic)
        data = context.is_a?(Context) ? context.to_h : context
        
        # For deterministic hashing, sort keys and create a stable representation
        # Use CRC32 which is faster than SHA256 while still being deterministic
        sorted_data = data.sort.to_h
        json_str = sorted_data.to_json
        Zlib.crc32(json_str)
      end
    end

    # FEEL Expression Cache
    # Caches compiled/parsed FEEL expressions for reuse
    class FeelExpressionCache
      def initialize(max_size: 500)
        @cache = {}
        @max_size = max_size
        @mutex = Mutex.new
        @stats = { hits: 0, misses: 0 }
      end

      # Cache a parsed FEEL expression
      def cache_expression(expression_string, parsed_expression)
        @mutex.synchronize do
          evict_oldest if @cache.size >= @max_size

          @cache[expression_string] = {
            expression: parsed_expression,
            accessed_at: Time.now.to_i,
            access_count: 0
          }
        end
      end

      # Get a cached expression
      def get_expression(expression_string)
        @mutex.synchronize do
          entry = @cache[expression_string]

          if entry
            @stats[:hits] += 1
            entry[:accessed_at] = Time.now.to_i
            entry[:access_count] += 1
            entry[:expression]
          else
            @stats[:misses] += 1
            nil
          end
        end
      end

      # Clear cache
      def clear
        @mutex.synchronize do
          @cache.clear
          @stats[:hits] = 0
          @stats[:misses] = 0
        end
      end

      # Get statistics
      def statistics
        @mutex.synchronize do
          hit_rate = @stats[:hits] + @stats[:misses]
          hit_rate = hit_rate.positive? ? (@stats[:hits].to_f / hit_rate * 100).round(2) : 0

          {
            size: @cache.size,
            hits: @stats[:hits],
            misses: @stats[:misses],
            hit_rate: hit_rate,
            most_accessed: most_accessed_expressions
          }
        end
      end

      private

      def evict_oldest
        return if @cache.empty?

        # Evict least recently accessed
        oldest_key = @cache.min_by { |_k, v| v[:accessed_at] }[0]
        @cache.delete(oldest_key)
      end

      def most_accessed_expressions
        @cache.sort_by { |_k, v| -v[:access_count] }.first(5).map do |expr, data|
          { expression: expr, count: data[:access_count] }
        end
      end
    end
  end
end
