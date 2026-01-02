module DecisionAgent
  module Dmn
    # Base error for all DMN-related errors
    class DmnError < StandardError; end

    # Raised when DMN XML is invalid or malformed
    class InvalidDmnXmlError < DmnError; end

    # Raised when DMN model structure is invalid
    class InvalidDmnModelError < DmnError; end

    # Raised when hit policy is unsupported
    class UnsupportedHitPolicyError < DmnError; end

    # Raised when FEEL expression cannot be parsed
    class FeelParseError < DmnError; end

    # Raised when parse tree transformation to AST fails
    class FeelTransformError < DmnError; end

    # Raised when FEEL expression evaluation fails
    class FeelEvaluationError < DmnError; end

    # Raised when type conversion or type checking fails
    class FeelTypeError < DmnError; end

    # Raised when a function is not found or has invalid arguments
    class FeelFunctionError < DmnError; end
  end
end
