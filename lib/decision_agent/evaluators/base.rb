module DecisionAgent
  module Evaluators
    class Base
      def evaluate(context, feedback: {})
        raise NotImplementedError, "Subclasses must implement #evaluate"
      end

      protected

      def evaluator_name
        self.class.name.split("::").last
      end
    end
  end
end
