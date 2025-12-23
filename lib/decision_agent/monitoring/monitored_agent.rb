module DecisionAgent
  module Monitoring
    # Wrapper around Agent that automatically records metrics
    class MonitoredAgent
      attr_reader :agent, :metrics_collector

      def initialize(agent:, metrics_collector:)
        @agent = agent
        @metrics_collector = metrics_collector
      end

      # Make a decision and automatically record metrics
      def decide(context:, feedback: {})
        ctx = context.is_a?(Context) ? context : Context.new(context)

        start_time = Time.now

        begin
          result = @agent.decide(context: ctx, feedback: feedback)
          duration_ms = (Time.now - start_time) * 1000

          # Record decision metrics
          @metrics_collector.record_decision(result, ctx, duration_ms: duration_ms)

          # Record each evaluation
          result.evaluations.each do |evaluation|
            @metrics_collector.record_evaluation(evaluation)
          end

          # Record successful performance
          @metrics_collector.record_performance(
            operation: "decide",
            duration_ms: duration_ms,
            success: true,
            metadata: {
              evaluators_count: result.evaluations.size,
              decision: result.decision,
              confidence: result.confidence
            }
          )

          result
        rescue => error
          duration_ms = (Time.now - start_time) * 1000

          # Record error
          @metrics_collector.record_error(error, context: ctx.to_h)

          # Record failed performance
          @metrics_collector.record_performance(
            operation: "decide",
            duration_ms: duration_ms,
            success: false,
            metadata: { error_class: error.class.name }
          )

          raise
        end
      end

      # Delegate other methods to the wrapped agent
      def method_missing(method, *args, **kwargs, &block)
        @agent.send(method, *args, **kwargs, &block)
      end

      def respond_to_missing?(method, include_private = false)
        @agent.respond_to?(method, include_private) || super
      end
    end
  end
end
