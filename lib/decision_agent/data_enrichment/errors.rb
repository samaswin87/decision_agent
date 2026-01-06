# frozen_string_literal: true

module DecisionAgent
  module DataEnrichment
    # Base error class for data enrichment
    class Error < StandardError
    end

    # Error raised when endpoint is not configured
    class EndpointNotFoundError < Error
    end

    # Error raised when request fails
    class RequestError < Error
      attr_reader :status_code, :response_body

      def initialize(message, status_code: nil, response_body: nil)
        super(message)
        @status_code = status_code
        @response_body = response_body
      end
    end

    # Error raised when request times out
    class TimeoutError < RequestError
    end

    # Error raised when network error occurs
    class NetworkError < RequestError
    end

    # Error raised when circuit breaker is open
    class CircuitOpenError < Error
    end
  end
end
