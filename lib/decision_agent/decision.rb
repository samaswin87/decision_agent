module DecisionAgent
  class Decision
    attr_reader :decision, :confidence, :explanations, :evaluations, :audit_payload

    def initialize(decision:, confidence:, explanations:, evaluations:, audit_payload:)
      validate_confidence!(confidence)

      @decision = decision.to_s.freeze
      @confidence = confidence.to_f
      @explanations = Array(explanations).map(&:freeze).freeze
      @evaluations = Array(evaluations).freeze
      @audit_payload = deep_freeze(audit_payload)

      freeze
    end

    # Returns array of condition descriptions that led to this decision
    # @param verbose [Boolean] If true, returns detailed condition information
    # @return [Array<String>] Array of condition descriptions
    def because(verbose: false)
      all_explainability_results.flat_map { |er| er.because(verbose: verbose) }
    end

    # Returns array of condition descriptions that failed
    # @param verbose [Boolean] If true, returns detailed condition information
    # @return [Array<String>] Array of failed condition descriptions
    def failed_conditions(verbose: false)
      all_explainability_results.flat_map { |er| er.failed_conditions(verbose: verbose) }
    end

    # Returns explainability data in machine-readable format
    # @param verbose [Boolean] If true, returns detailed explainability information
    # @return [Hash] Explainability data
    def explainability(verbose: false)
      {
        decision: @decision,
        because: because(verbose: verbose),
        failed_conditions: failed_conditions(verbose: verbose),
        rule_traces: verbose ? all_explainability_results.map { |er| er.to_h(verbose: true) } : nil
      }.compact
    end

    def to_h
      # Structure decision result as explainability by default
      # This makes explainability the primary format for decision results
      explainability_data = explainability(verbose: false)
      
      {
        # Explainability fields (primary structure)
        decision: explainability_data[:decision],
        because: explainability_data[:because],
        failed_conditions: explainability_data[:failed_conditions],
        # Additional metadata for completeness
        confidence: @confidence,
        explanations: @explanations,
        evaluations: @evaluations.map(&:to_h),
        audit_payload: @audit_payload,
        # Full explainability data (includes rule_traces in verbose mode)
        explainability: explainability_data
      }
    end

    private

    def all_explainability_results
      @evaluations.flat_map do |evaluation|
        next [] unless evaluation.metadata.is_a?(Hash)
        next [] unless evaluation.metadata[:explainability]

        # Reconstruct ExplainabilityResult from metadata
        explainability_data = evaluation.metadata[:explainability]
        
        # Handle both hash and symbol keys
        explainability_data = explainability_data.transform_keys(&:to_sym) if explainability_data.is_a?(Hash)
        
        rule_traces = (explainability_data[:rule_traces] || explainability_data["rule_traces"] || []).map do |rt_data|
          rt_data = rt_data.transform_keys(&:to_sym) if rt_data.is_a?(Hash)
          
          condition_traces = (rt_data[:condition_traces] || rt_data["condition_traces"] || []).map do |ct_data|
            ct_data = ct_data.transform_keys(&:to_sym) if ct_data.is_a?(Hash)
            Explainability::ConditionTrace.new(
              field: ct_data[:field] || ct_data["field"],
              operator: ct_data[:operator] || ct_data["operator"],
              expected_value: ct_data[:expected_value] || ct_data["expected_value"],
              actual_value: ct_data[:actual_value] || ct_data["actual_value"],
              result: ct_data[:result] || ct_data["result"]
            )
          end
          Explainability::RuleTrace.new(
            rule_id: rt_data[:rule_id] || rt_data["rule_id"],
            matched: rt_data[:matched] || rt_data["matched"],
            condition_traces: condition_traces,
            decision: rt_data[:decision] || rt_data["decision"],
            weight: rt_data[:weight] || rt_data["weight"],
            reason: rt_data[:reason] || rt_data["reason"]
          )
        end
        [Explainability::ExplainabilityResult.new(
          evaluator_name: explainability_data[:evaluator_name] || explainability_data["evaluator_name"] || evaluation.evaluator_name,
          rule_traces: rule_traces
        )]
      end
    end

    public

    def ==(other)
      other.is_a?(Decision) &&
        @decision == other.decision &&
        (@confidence - other.confidence).abs < 0.0001 &&
        @explanations == other.explanations &&
        @evaluations == other.evaluations
    end

    private

    def validate_confidence!(confidence)
      c = confidence.to_f
      raise InvalidConfidenceError, confidence unless c.between?(0.0, 1.0)
    end

    def deep_freeze(obj)
      return obj if obj.frozen?

      case obj
      when Hash
        obj.each_value { |v| deep_freeze(v) }
        obj.freeze
      when Array
        obj.each { |v| deep_freeze(v) }
        obj.freeze
      when String, Symbol, Numeric, TrueClass, FalseClass, NilClass
        obj.freeze
      else
        obj.freeze if obj.respond_to?(:freeze)
      end
      obj
    end
  end
end
