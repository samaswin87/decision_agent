module DecisionAgent
  module Testing
    # Represents a single test scenario with context and expected results
    class TestScenario
      attr_reader :id, :context, :expected_decision, :expected_confidence, :metadata

      def initialize(id:, context:, expected_decision: nil, expected_confidence: nil, metadata: {})
        @id = id.to_s.freeze
        @context = context.is_a?(Hash) ? context.freeze : context
        @expected_decision = expected_decision&.to_s&.freeze
        @expected_confidence = expected_confidence&.to_f if expected_confidence
        @metadata = metadata.is_a?(Hash) ? metadata.freeze : metadata

        freeze
      end

      def to_h
        {
          id: @id,
          context: @context,
          expected_decision: @expected_decision,
          expected_confidence: @expected_confidence,
          metadata: @metadata
        }
      end

      def expected_result?
        !@expected_decision.nil?
      end

      def ==(other)
        other.is_a?(TestScenario) &&
          @id == other.id &&
          @context == other.context &&
          @expected_decision == other.expected_decision &&
          (@expected_confidence.nil? || other.expected_confidence.nil? ||
           (@expected_confidence - other.expected_confidence).abs < 0.0001) &&
          @metadata == other.metadata
      end
    end
  end
end
