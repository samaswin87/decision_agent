require "logger"
require "json"

module DecisionAgent
  module Audit
    class LoggerAdapter < Adapter
      attr_reader :logger

      def initialize(logger: nil, level: Logger::INFO)
        @logger = logger || Logger.new($stdout)
        @logger.level = level
      end

      def record(decision, context)
        log_entry = {
          timestamp: decision.audit_payload[:timestamp],
          decision: decision.decision,
          confidence: decision.confidence,
          context: context.to_h,
          audit_hash: decision.audit_payload[:deterministic_hash]
        }

        @logger.info(JSON.generate(log_entry))
      end
    end
  end
end
