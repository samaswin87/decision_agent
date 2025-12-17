module DecisionAgent
  module Audit
    class NullAdapter < Adapter
      def record(decision, context)
      end
    end
  end
end
