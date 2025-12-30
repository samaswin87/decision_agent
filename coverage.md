# Code Coverage Report

**Last Updated:** 2025-12-30 07:30:47

## Summary

| Metric | Value |
|--------|-------|
| **Total Coverage** | **95.49%** |
| Total Files | 59 |
| Total Relevant Lines | 3702 |
| Lines Covered | 3535 |
| Lines Missed | 167 |

> **Note:** This report excludes files in the `examples/` directory as they are sample code, not production code.

## Coverage by File

| File | Coverage | Lines Covered | Lines Missed | Total Lines |
|------|----------|---------------|--------------|-------------|
| `lib/decision_agent.rb` | ✅ 100.0% | 65 | 0 | 65 |
| `lib/decision_agent/ab_testing/ab_test.rb` | ✅ 93.98% | 78 | 5 | 83 |
| `lib/decision_agent/ab_testing/ab_test_assignment.rb` | ✅ 100.0% | 28 | 0 | 28 |
| `lib/decision_agent/ab_testing/ab_test_manager.rb` | ✅ 92.54% | 124 | 10 | 134 |
| `lib/decision_agent/ab_testing/ab_testing_agent.rb` | ✅ 100.0% | 47 | 0 | 47 |
| `lib/decision_agent/ab_testing/storage/adapter.rb` | ✅ 100.0% | 20 | 0 | 20 |
| `lib/decision_agent/ab_testing/storage/memory_adapter.rb` | ✅ 100.0% | 67 | 0 | 67 |
| `lib/decision_agent/agent.rb` | ✅ 100.0% | 66 | 0 | 66 |
| `lib/decision_agent/audit/adapter.rb` | ✅ 100.0% | 5 | 0 | 5 |
| `lib/decision_agent/audit/logger_adapter.rb` | ✅ 100.0% | 12 | 0 | 12 |
| `lib/decision_agent/audit/null_adapter.rb` | ✅ 100.0% | 4 | 0 | 4 |
| `lib/decision_agent/auth/access_audit_logger.rb` | ✅ 100.0% | 52 | 0 | 52 |
| `lib/decision_agent/auth/authenticator.rb` | ✅ 94.44% | 68 | 4 | 72 |
| `lib/decision_agent/auth/password_reset_manager.rb` | ✅ 100.0% | 34 | 0 | 34 |
| `lib/decision_agent/auth/password_reset_token.rb` | ✅ 93.75% | 15 | 1 | 16 |
| `lib/decision_agent/auth/permission.rb` | ✅ 100.0% | 11 | 0 | 11 |
| `lib/decision_agent/auth/permission_checker.rb` | ✅ 100.0% | 22 | 0 | 22 |
| `lib/decision_agent/auth/rbac_adapter.rb` | ✅ 99.23% | 129 | 1 | 130 |
| `lib/decision_agent/auth/rbac_config.rb` | ✅ 100.0% | 23 | 0 | 23 |
| `lib/decision_agent/auth/role.rb` | ✅ 100.0% | 19 | 0 | 19 |
| `lib/decision_agent/auth/session.rb` | ✅ 100.0% | 16 | 0 | 16 |
| `lib/decision_agent/auth/session_manager.rb` | ✅ 100.0% | 34 | 0 | 34 |
| `lib/decision_agent/auth/user.rb` | ✅ 94.87% | 37 | 2 | 39 |
| `lib/decision_agent/context.rb` | ✅ 96.88% | 31 | 1 | 32 |
| `lib/decision_agent/decision.rb` | ✅ 96.67% | 29 | 1 | 30 |
| `lib/decision_agent/dsl/condition_evaluator.rb` | ✅ 100.0% | 177 | 0 | 177 |
| `lib/decision_agent/dsl/rule_parser.rb` | ✅ 100.0% | 15 | 0 | 15 |
| `lib/decision_agent/dsl/schema_validator.rb` | ✅ 99.29% | 139 | 1 | 140 |
| `lib/decision_agent/errors.rb` | ✅ 96.72% | 59 | 2 | 61 |
| `lib/decision_agent/evaluation.rb` | ✅ 96.55% | 28 | 1 | 29 |
| `lib/decision_agent/evaluation_validator.rb` | ✅ 100.0% | 37 | 0 | 37 |
| `lib/decision_agent/evaluators/base.rb` | ✅ 100.0% | 8 | 0 | 8 |
| `lib/decision_agent/evaluators/json_rule_evaluator.rb` | ✅ 97.37% | 37 | 1 | 38 |
| `lib/decision_agent/evaluators/static_evaluator.rb` | ✅ 100.0% | 13 | 0 | 13 |
| `lib/decision_agent/monitoring/alert_manager.rb` | ✅ 91.11% | 123 | 12 | 135 |
| `lib/decision_agent/monitoring/metrics_collector.rb` | ✅ 93.87% | 153 | 10 | 163 |
| `lib/decision_agent/monitoring/monitored_agent.rb` | ✅ 100.0% | 25 | 0 | 25 |
| `lib/decision_agent/monitoring/prometheus_exporter.rb` | ✅ 100.0% | 126 | 0 | 126 |
| `lib/decision_agent/monitoring/storage/activerecord_adapter.rb` | ✅ 95.65% | 88 | 4 | 92 |
| `lib/decision_agent/monitoring/storage/base_adapter.rb` | ✅ 100.0% | 22 | 0 | 22 |
| `lib/decision_agent/monitoring/storage/memory_adapter.rb` | ✅ 100.0% | 99 | 0 | 99 |
| `lib/decision_agent/replay/replay.rb` | ✅ 96.49% | 55 | 2 | 57 |
| `lib/decision_agent/scoring/base.rb` | ✅ 90.0% | 9 | 1 | 10 |
| `lib/decision_agent/scoring/consensus.rb` | ✅ 100.0% | 20 | 0 | 20 |
| `lib/decision_agent/scoring/max_weight.rb` | ✅ 100.0% | 7 | 0 | 7 |
| `lib/decision_agent/scoring/threshold.rb` | ✅ 100.0% | 19 | 0 | 19 |
| `lib/decision_agent/scoring/weighted_average.rb` | ✅ 100.0% | 13 | 0 | 13 |
| `lib/decision_agent/testing/batch_test_importer.rb` | ⚠️ 87.18% | 136 | 20 | 156 |
| `lib/decision_agent/testing/batch_test_runner.rb` | ✅ 94.55% | 104 | 6 | 110 |
| `lib/decision_agent/testing/test_coverage_analyzer.rb` | ✅ 96.43% | 81 | 3 | 84 |
| `lib/decision_agent/testing/test_result_comparator.rb` | ✅ 97.62% | 82 | 2 | 84 |
| `lib/decision_agent/testing/test_scenario.rb` | ✅ 94.74% | 18 | 1 | 19 |
| `lib/decision_agent/versioning/activerecord_adapter.rb` | ✅ 90.2% | 46 | 5 | 51 |
| `lib/decision_agent/versioning/adapter.rb` | ✅ 100.0% | 31 | 0 | 31 |
| `lib/decision_agent/versioning/file_storage_adapter.rb` | ✅ 90.68% | 146 | 15 | 161 |
| `lib/decision_agent/versioning/version_manager.rb` | ✅ 100.0% | 40 | 0 | 40 |
| `lib/decision_agent/web/middleware/auth_middleware.rb` | ✅ 100.0% | 25 | 0 | 25 |
| `lib/decision_agent/web/middleware/permission_middleware.rb` | ✅ 100.0% | 43 | 0 | 43 |
| `lib/decision_agent/web/server.rb` | ⚠️ 89.45% | 475 | 56 | 531 |

## Coverage Status

- ✅ **90%+** - Excellent coverage
- ⚠️ **70-89%** - Good coverage, improvements recommended
- ❌ **<70%** - Low coverage, needs attention

## How to Generate This Report

Run the tests with coverage enabled:

```bash
bundle exec rake coverage
```

Or run RSpec directly:

```bash
bundle exec rspec
```

Then regenerate this report:

```bash
ruby scripts/generate_coverage_report.rb
```

## View Detailed Coverage

For detailed line-by-line coverage, open `coverage/index.html` in your browser.
