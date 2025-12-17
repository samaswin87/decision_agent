module DecisionAgent
  module Audit
    class Adapter
      def record(decision, context)
        raise NotImplementedError, "Subclasses must implement #record"
      end
    end
  end
end
