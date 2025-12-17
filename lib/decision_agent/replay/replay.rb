require "digest"
require "json"

module DecisionAgent
  module Replay
    def self.run(audit_payload, strict: true)
      validate_payload!(audit_payload)

      context = Context.new(audit_payload[:context] || audit_payload["context"])
      feedback = audit_payload[:feedback] || audit_payload["feedback"] || {}

      original_evaluations = parse_evaluations(audit_payload)
      original_decision = audit_payload[:decision] || audit_payload["decision"]
      original_confidence = audit_payload[:confidence] || audit_payload["confidence"]

      scoring_strategy = instantiate_scoring_strategy(audit_payload)

      agent = Agent.new(
        evaluators: build_replay_evaluators(original_evaluations),
        scoring_strategy: scoring_strategy,
        audit_adapter: Audit::NullAdapter.new
      )

      replayed_result = agent.decide(context: context, feedback: feedback)

      if strict
        validate_strict_match!(
          original_decision: original_decision,
          original_confidence: original_confidence,
          replayed_decision: replayed_result.decision,
          replayed_confidence: replayed_result.confidence
        )
      else
        log_differences(
          original_decision: original_decision,
          original_confidence: original_confidence,
          replayed_decision: replayed_result.decision,
          replayed_confidence: replayed_result.confidence
        )
      end

      replayed_result
    end

    private

    def self.validate_payload!(payload)
      required_keys = ["context", "evaluations", "decision", "confidence"]

      required_keys.each do |key|
        unless payload.key?(key) || payload.key?(key.to_sym)
          raise InvalidRuleDslError, "Audit payload missing required key: #{key}"
        end
      end
    end

    def self.parse_evaluations(payload)
      evals = payload[:evaluations] || payload["evaluations"]

      evals.map do |eval_data|
        if eval_data.is_a?(Evaluation)
          eval_data
        else
          Evaluation.new(
            decision: eval_data[:decision] || eval_data["decision"],
            weight: eval_data[:weight] || eval_data["weight"],
            reason: eval_data[:reason] || eval_data["reason"],
            evaluator_name: eval_data[:evaluator_name] || eval_data["evaluator_name"],
            metadata: eval_data[:metadata] || eval_data["metadata"] || {}
          )
        end
      end
    end

    def self.build_replay_evaluators(evaluations)
      evaluations.map do |evaluation|
        Evaluators::StaticEvaluator.new(
          decision: evaluation.decision,
          weight: evaluation.weight,
          reason: evaluation.reason,
          name: evaluation.evaluator_name,
          metadata: evaluation.metadata
        )
      end
    end

    def self.instantiate_scoring_strategy(payload)
      strategy_name = payload[:scoring_strategy] || payload["scoring_strategy"]

      return Scoring::WeightedAverage.new unless strategy_name

      case strategy_name
      when /WeightedAverage/
        Scoring::WeightedAverage.new
      when /MaxWeight/
        Scoring::MaxWeight.new
      when /Consensus/
        Scoring::Consensus.new
      when /Threshold/
        Scoring::Threshold.new
      else
        Scoring::WeightedAverage.new
      end
    end

    def self.validate_strict_match!(original_decision:, original_confidence:, replayed_decision:, replayed_confidence:)
      differences = []

      if original_decision.to_s != replayed_decision.to_s
        differences << "decision mismatch (expected: #{original_decision}, got: #{replayed_decision})"
      end

      conf_diff = (original_confidence.to_f - replayed_confidence.to_f).abs
      if conf_diff > 0.0001
        differences << "confidence mismatch (expected: #{original_confidence}, got: #{replayed_confidence})"
      end

      if differences.any?
        raise ReplayMismatchError.new(
          expected: { decision: original_decision, confidence: original_confidence },
          actual: { decision: replayed_decision, confidence: replayed_confidence },
          differences: differences
        )
      end
    end

    def self.log_differences(original_decision:, original_confidence:, replayed_decision:, replayed_confidence:)
      differences = []

      if original_decision.to_s != replayed_decision.to_s
        differences << "Decision changed: #{original_decision} -> #{replayed_decision}"
      end

      conf_diff = (original_confidence.to_f - replayed_confidence.to_f).abs
      if conf_diff > 0.0001
        differences << "Confidence changed: #{original_confidence} -> #{replayed_confidence}"
      end

      if differences.any?
        warn "[DecisionAgent::Replay] Non-strict mode differences detected:"
        differences.each { |diff| warn "  - #{diff}" }
      end

      differences
    end
  end
end
