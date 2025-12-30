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

module DecisionAgent
  # Global RBAC configuration
  @rbac_config = Auth::RbacConfig.new

  class << self
    attr_reader :rbac_config

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
      @rbac_config
    end

    # Get the configured permission checker
    def permission_checker
      @permission_checker ||= Auth::PermissionChecker.new(adapter: @rbac_config.adapter)
    end

    # Set a custom permission checker
    attr_writer :permission_checker
  end
end
