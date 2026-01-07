require "digest"
require "json"
require "json/canonicalization"

module DecisionAgent
  class Agent
    attr_reader :evaluators, :scoring_strategy, :audit_adapter

    # Thread-safe cache for deterministic hash computation
    # This significantly improves performance when the same context/evaluations
    # are processed multiple times (common in benchmarks and high-throughput scenarios)
    @hash_cache = {}
    @hash_cache_mutex = Mutex.new
    @hash_cache_max_size = 1000 # Limit cache size to prevent memory bloat

    class << self
      attr_reader :hash_cache, :hash_cache_mutex, :hash_cache_max_size
    end

    def initialize(evaluators:, scoring_strategy: nil, audit_adapter: nil, validate_evaluations: nil)
      @evaluators = Array(evaluators)
      @scoring_strategy = scoring_strategy || Scoring::WeightedAverage.new
      @audit_adapter = audit_adapter || Audit::NullAdapter.new
      # Default to validating in development, skip in production for performance
      @validate_evaluations = validate_evaluations.nil? ? (ENV["RAILS_ENV"] != "production") : validate_evaluations

      validate_configuration!

      # Freeze instance variables for thread-safety
      @evaluators.freeze
    end

    def decide(context:, feedback: {})
      ctx = context.is_a?(Context) ? context : Context.new(context)

      evaluations = collect_evaluations(ctx, feedback)

      raise NoEvaluationsError if evaluations.empty?

      # Validate all evaluations for correctness and thread-safety (optional for performance)
      EvaluationValidator.validate_all!(evaluations) if @validate_evaluations

      scored_result = @scoring_strategy.score(evaluations)

      decision_value = scored_result[:decision]
      confidence_value = scored_result[:confidence]

      explanations = build_explanations(evaluations, decision_value, confidence_value)

      audit_payload = build_audit_payload(
        context: ctx,
        evaluations: evaluations,
        decision: decision_value,
        confidence: confidence_value,
        feedback: feedback
      )

      decision = Decision.new(
        decision: decision_value,
        confidence: confidence_value,
        explanations: explanations,
        evaluations: evaluations,
        audit_payload: audit_payload
      )

      @audit_adapter.record(decision, ctx)

      decision
    end

    private

    def validate_configuration!
      raise InvalidConfigurationError, "At least one evaluator is required" if @evaluators.empty?

      @evaluators.each do |evaluator|
        raise InvalidEvaluatorError unless evaluator.respond_to?(:evaluate)
      end

      raise InvalidScoringStrategyError unless @scoring_strategy.respond_to?(:score)

      return if @audit_adapter.respond_to?(:record)

      raise InvalidAuditAdapterError
    end

    def collect_evaluations(context, feedback)
      @evaluators.map do |evaluator|
        evaluator.evaluate(context, feedback: feedback)
      rescue StandardError
        nil
      end.compact
    end

    def build_explanations(evaluations, final_decision, confidence)
      explanations = []

      matching_evals = evaluations.select { |e| e.decision == final_decision }

      explanations << "Decision: #{final_decision} (confidence: #{confidence.round(2)})"

      if matching_evals.size == 1
        eval = matching_evals.first
        explanations << "#{eval.evaluator_name}: #{eval.reason} (weight: #{eval.weight})"
      elsif matching_evals.size > 1
        explanations << "Based on #{matching_evals.size} evaluators:"
        matching_evals.each do |eval|
          explanations << "  - #{eval.evaluator_name}: #{eval.reason} (weight: #{eval.weight})"
        end
      end

      conflicting_evals = evaluations.reject { |e| e.decision == final_decision }
      if conflicting_evals.any?
        explanations << "Conflicting evaluations resolved by #{@scoring_strategy.class.name.split('::').last}:"
        conflicting_evals.each do |eval|
          explanations << "  - #{eval.evaluator_name}: suggested '#{eval.decision}' (weight: #{eval.weight})"
        end
      end

      explanations
    end

    def build_audit_payload(context:, evaluations:, decision:, confidence:, feedback:)
      timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%6NZ")

      payload = {
        timestamp: timestamp,
        context: context.to_h,
        feedback: feedback,
        evaluations: evaluations.map(&:to_h),
        decision: decision,
        confidence: confidence,
        scoring_strategy: @scoring_strategy.class.name,
        agent_version: DecisionAgent::VERSION
      }

      payload[:deterministic_hash] = compute_deterministic_hash(payload)
      payload
    end

    def compute_deterministic_hash(payload)
      hashable = payload.slice(:context, :evaluations, :decision, :confidence, :scoring_strategy)

      # Use fast hash (MD5) as cache key to avoid expensive canonicalization on cache hits
      # This is much faster than canonical JSON and sufficient for cache key purposes
      fast_key = fast_hash_key(hashable)

      # Fast path: check cache without lock first (unsafe read, but acceptable for cache)
      # This allows concurrent reads without mutex overhead
      cache = self.class.hash_cache
      cached_hash = cache[fast_key]
      return cached_hash if cached_hash

      # Cache miss - compute canonical JSON (required for deterministic hashing)
      # This is expensive, but only happens on cache misses
      canonical = canonical_json(hashable)

      # Compute SHA256 hash (also expensive, but only on cache misses)
      computed_hash = Digest::SHA256.hexdigest(canonical)

      # Store in cache (thread-safe, with size limit)
      # Only lock when we need to write
      self.class.hash_cache_mutex.synchronize do
        # Double-check after acquiring lock (another thread may have added it)
        return self.class.hash_cache[fast_key] if self.class.hash_cache[fast_key]

        # Clear cache if it gets too large (simple FIFO eviction)
        if self.class.hash_cache.size >= self.class.hash_cache_max_size
          # Remove oldest 10% of entries (simple approximation)
          keys_to_remove = self.class.hash_cache.keys.first(self.class.hash_cache_max_size / 10)
          keys_to_remove.each { |key| self.class.hash_cache.delete(key) }
        end
        self.class.hash_cache[fast_key] = computed_hash
      end

      computed_hash
    end

    # Fast hash key generation using MD5 (much faster than canonical JSON + SHA256)
    # Used as cache key to avoid expensive canonicalization on cache hits
    # MD5 is sufficient for cache keys (collision resistance not critical, speed is)
    def fast_hash_key(hashable)
      # Create a deterministic string representation for hashing
      # Use sorted JSON to ensure determinism (though not RFC 8785 canonical)
      json_str = sort_hash_keys(hashable).to_json
      Digest::MD5.hexdigest(json_str)
    end

    # Recursively sort hash keys for deterministic hashing
    # This is faster than canonical JSON but still deterministic
    def sort_hash_keys(obj)
      case obj
      when Hash
        sorted = obj.sort.to_h
        sorted.transform_values { |v| sort_hash_keys(v) }
      when Array
        obj.map { |v| sort_hash_keys(v) }
      else
        obj
      end
    end

    # Uses RFC 8785 (JSON Canonicalization Scheme) for deterministic JSON serialization
    # This is the industry standard for cryptographic hashing of JSON data
    def canonical_json(obj)
      obj.to_json_c14n
    end
  end
end
