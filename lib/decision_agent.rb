require_relative "decision_agent/version"
require_relative "decision_agent/errors"
require_relative "decision_agent/context"
require_relative "decision_agent/evaluation"
require_relative "decision_agent/evaluation_validator"
require_relative "decision_agent/decision"
require_relative "decision_agent/agent"

require_relative "decision_agent/evaluators/base"
require_relative "decision_agent/evaluators/static_evaluator"
require_relative "decision_agent/evaluators/json_rule_evaluator"

require_relative "decision_agent/dsl/schema_validator"
require_relative "decision_agent/dsl/rule_parser"
require_relative "decision_agent/dsl/condition_evaluator"

require_relative "decision_agent/scoring/base"
require_relative "decision_agent/scoring/weighted_average"
require_relative "decision_agent/scoring/max_weight"
require_relative "decision_agent/scoring/consensus"
require_relative "decision_agent/scoring/threshold"

require_relative "decision_agent/audit/adapter"
require_relative "decision_agent/audit/null_adapter"
require_relative "decision_agent/audit/logger_adapter"

require_relative "decision_agent/replay/replay"

require_relative "decision_agent/versioning/adapter"
require_relative "decision_agent/versioning/file_storage_adapter"
require_relative "decision_agent/versioning/version_manager"

require_relative "decision_agent/monitoring/metrics_collector"
require_relative "decision_agent/monitoring/prometheus_exporter"
require_relative "decision_agent/monitoring/alert_manager"
require_relative "decision_agent/monitoring/monitored_agent"
# dashboard_server has additional dependencies (faye/websocket) - require it explicitly when needed

require_relative "decision_agent/ab_testing/ab_test"
require_relative "decision_agent/ab_testing/ab_test_assignment"
require_relative "decision_agent/ab_testing/ab_test_manager"
require_relative "decision_agent/ab_testing/ab_testing_agent"
require_relative "decision_agent/ab_testing/storage/adapter"
require_relative "decision_agent/ab_testing/storage/memory_adapter"

require_relative "decision_agent/testing/test_scenario"
require_relative "decision_agent/testing/batch_test_importer"
require_relative "decision_agent/testing/batch_test_runner"
require_relative "decision_agent/testing/test_result_comparator"
require_relative "decision_agent/testing/test_coverage_analyzer"

require_relative "decision_agent/auth/user"
require_relative "decision_agent/auth/role"
require_relative "decision_agent/auth/permission"
require_relative "decision_agent/auth/session"
require_relative "decision_agent/auth/session_manager"
require_relative "decision_agent/auth/password_reset_token"
require_relative "decision_agent/auth/password_reset_manager"
require_relative "decision_agent/auth/authenticator"
require_relative "decision_agent/auth/rbac_adapter"
require_relative "decision_agent/auth/rbac_config"
require_relative "decision_agent/auth/permission_checker"
require_relative "decision_agent/auth/access_audit_logger"

require_relative "decision_agent/data_enrichment/config"
require_relative "decision_agent/data_enrichment/client"
require_relative "decision_agent/data_enrichment/cache_adapter"
require_relative "decision_agent/data_enrichment/cache/memory_adapter"
require_relative "decision_agent/data_enrichment/circuit_breaker"
require_relative "decision_agent/data_enrichment/errors"

require_relative "decision_agent/simulation"

module DecisionAgent
  # Global RBAC configuration
  @rbac_config = Auth::RbacConfig.new
  # Global data enrichment configuration
  @data_enrichment_config = DataEnrichment::Config.new
  @data_enrichment_client = nil
  @permission_checker = nil
  @permission_checker_mutex = Mutex.new
  @data_enrichment_client_mutex = Mutex.new

  class << self
    attr_reader :rbac_config, :data_enrichment_config

    # Configure RBAC adapter
    # @param adapter_type [Symbol] :default, :devise_cancan, :pundit, or :custom
    # @param options [Hash] Options for the adapter
    # @yield [RbacConfig] Configuration block
    # @example
    #   DecisionAgent.configure_rbac(:devise_cancan, ability_class: Ability)
    # @example
    #   DecisionAgent.configure_rbac(:custom) do |config|
    #     config.adapter = MyCustomAdapter.new
    #   end
    def configure_rbac(adapter_type = nil, **options)
      if block_given?
        yield @rbac_config
      elsif adapter_type
        @rbac_config.use(adapter_type, **options)
      end
      # Initialize permission checker at configuration time (thread-safe write-once pattern)
      @permission_checker = Auth::PermissionChecker.new(adapter: @rbac_config.adapter)
      @rbac_config
    end

    # Get the configured permission checker
    # Thread-safe: uses double-checked locking for lazy initialization fallback
    def permission_checker
      return @permission_checker if @permission_checker

      @permission_checker_mutex.synchronize do
        @permission_checker ||= Auth::PermissionChecker.new(adapter: @rbac_config.adapter)
      end
    end

    # Set a custom permission checker
    attr_writer :permission_checker

    # Configure data enrichment endpoints
    # @yield [DataEnrichment::Config] Configuration block
    # @example
    #   DecisionAgent.configure_data_enrichment do |config|
    #     config.add_endpoint(:credit_bureau,
    #       url: "https://api.creditbureau.com/v1/score",
    #       method: :post,
    #       auth: { type: :api_key, header: "X-API-Key" },
    #       cache: { ttl: 3600, adapter: :memory }
    #     )
    #   end
    def configure_data_enrichment
      yield @data_enrichment_config if block_given?
      # Initialize client at configuration time (thread-safe write-once pattern)
      @data_enrichment_client = DataEnrichment::Client.new(config: @data_enrichment_config)
      @data_enrichment_config
    end

    # Get the data enrichment client
    # Thread-safe: uses double-checked locking for lazy initialization fallback
    def data_enrichment_client
      return @data_enrichment_client if @data_enrichment_client

      @data_enrichment_client_mutex.synchronize do
        @data_enrichment_client ||= DataEnrichment::Client.new(config: @data_enrichment_config)
      end
    end

    # Set a custom data enrichment client
    attr_writer :data_enrichment_client
  end
end
