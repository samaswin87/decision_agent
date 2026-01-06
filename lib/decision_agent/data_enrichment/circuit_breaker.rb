# frozen_string_literal: true

require "monitor"

module DecisionAgent
  module DataEnrichment
    # Circuit breaker pattern for resilience
    #
    # Prevents cascading failures by opening the circuit after N failures
    class CircuitBreaker
      include MonitorMixin

      # Circuit states
      CLOSED = :closed    # Normal operation
      OPEN = :open        # Circuit is open, failing fast
      HALF_OPEN = :half_open # Testing if service recovered

      def initialize(failure_threshold: 5, timeout: 60, success_threshold: 2)
        super()
        @failure_threshold = failure_threshold
        @timeout = timeout
        @success_threshold = success_threshold
        @state = CLOSED
        @failure_count = 0
        @success_count = 0
        @last_failure_time = nil
      end

      # Execute block with circuit breaker protection
      #
      # @yield Block to execute
      # @return [Object] Result of block execution
      # @raise [CircuitOpenError] If circuit is open
      def call
        synchronize do
          check_state
          raise CircuitOpenError, "Circuit is open" if @state == OPEN
        end

        begin
          result = yield
          record_success
          result
        rescue StandardError => e
          record_failure
          raise e
        end
      end

      # Check if circuit is open
      #
      # @return [Boolean]
      def open?
        synchronize do
          check_state
          @state == OPEN
        end
      end

      # Reset circuit breaker to closed state
      def reset
        synchronize do
          @state = CLOSED
          @failure_count = 0
          @success_count = 0
          @last_failure_time = nil
        end
      end

      # Get current state
      #
      # @return [Symbol] Current state
      def state
        synchronize do
          check_state
          @state
        end
      end

      private

      def check_state
        case @state
        when OPEN
          # Check if timeout has elapsed, move to half-open
          if @last_failure_time && (Time.now - @last_failure_time) >= @timeout
            @state = HALF_OPEN
            @success_count = 0
          end
        when HALF_OPEN
          # State remains half-open until success threshold is met
        when CLOSED
          # State remains closed until failure threshold is met
        end
      end

      def record_success
        synchronize do
          case @state
          when HALF_OPEN
            @success_count += 1
            if @success_count >= @success_threshold
              @state = CLOSED
              @failure_count = 0
              @success_count = 0
            end
          when CLOSED
            @failure_count = 0 # Reset failure count on success
          end
        end
      end

      def record_failure
        synchronize do
          @failure_count += 1
          @last_failure_time = Time.now

          case @state
          when HALF_OPEN
            # Failures in half-open state immediately open the circuit
            @state = OPEN
            @success_count = 0
          when CLOSED
            # Open circuit if failure threshold is met
            @state = OPEN if @failure_count >= @failure_threshold
          end
        end
      end

      # Error raised when circuit is open
      class CircuitOpenError < StandardError
      end
    end
  end
end
