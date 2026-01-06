module DecisionAgent
  module Explainability
    # Collects condition traces during evaluation
    class TraceCollector
      attr_reader :traces

      def initialize
        @traces = []
      end

      def add_trace(trace)
        @traces << trace
      end

      def clear
        @traces.clear
      end

      def empty?
        @traces.empty?
      end
    end
  end
end

