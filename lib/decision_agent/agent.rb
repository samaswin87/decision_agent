require "digest"
require "json"

module DecisionAgent
  class Agent
    attr_reader :evaluators, :scoring_strategy, :audit_adapter

    def initialize(evaluators:, scoring_strategy: nil, audit_adapter: nil)
      @evaluators = Array(evaluators)
      @scoring_strategy = scoring_strategy || Scoring::WeightedAverage.new
      @audit_adapter = audit_adapter || Audit::NullAdapter.new

      validate_configuration!
    end

    def decide(context:, feedback: {})
      ctx = context.is_a?(Context) ? context : Context.new(context)

      evaluations = collect_evaluations(ctx, feedback)

      raise NoEvaluationsError if evaluations.empty?

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
      if @evaluators.empty?
        raise InvalidConfigurationError, "At least one evaluator is required"
      end

      @evaluators.each do |evaluator|
        unless evaluator.respond_to?(:evaluate)
          raise InvalidEvaluatorError
        end
      end

      unless @scoring_strategy.respond_to?(:score)
        raise InvalidScoringStrategyError
      end

      unless @audit_adapter.respond_to?(:record)
        raise InvalidAuditAdapterError
      end
    end

    def collect_evaluations(context, feedback)
      @evaluators.map do |evaluator|
        begin
          evaluator.evaluate(context, feedback: feedback)
        rescue => e
          nil
        end
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
      canonical = canonical_json(hashable)
      Digest::SHA256.hexdigest(canonical)
    end

    def canonical_json(obj)
      case obj
      when Hash
        sorted = obj.keys.sort.map { |k| [k.to_s, canonical_json(obj[k])] }.to_h
        JSON.generate(sorted, quirks_mode: false)
      when Array
        JSON.generate(obj.map { |v| canonical_json(v) }, quirks_mode: false)
      else
        obj.to_s
      end
    end
  end
end
