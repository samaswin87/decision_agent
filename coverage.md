# Code Coverage Report

**Last Updated:** 2025-12-29 21:14:51

## Summary

| Metric | Value |
|--------|-------|
| **Total Coverage** | **28.81%** |
| Total Files | 56 |
| Total Relevant Lines | 3051 |
| Lines Covered | 879 |
| Lines Missed | 2172 |

> **Note:** This report excludes files in the `examples/` directory as they are sample code, not production code.

## Coverage by File

| File | Coverage | Lines Covered | Lines Missed | Total Lines |
|------|----------|---------------|--------------|-------------|
| `lib/decision_agent.rb` | ⚠️ 89.39% | 59 | 7 | 66 |
| `lib/decision_agent/ab_testing/ab_test.rb` | ❌ 28.92% | 24 | 59 | 83 |
| `lib/decision_agent/ab_testing/ab_test_assignment.rb` | ❌ 32.14% | 9 | 19 | 28 |
| `lib/decision_agent/ab_testing/ab_test_manager.rb` | ❌ 21.64% | 29 | 105 | 134 |
| `lib/decision_agent/ab_testing/ab_testing_agent.rb` | ❌ 27.66% | 13 | 34 | 47 |
| `lib/decision_agent/ab_testing/storage/adapter.rb` | ❌ 60.0% | 12 | 8 | 20 |
| `lib/decision_agent/ab_testing/storage/memory_adapter.rb` | ❌ 26.87% | 18 | 49 | 67 |
| `lib/decision_agent/agent.rb` | ❌ 23.08% | 15 | 50 | 65 |
| `lib/decision_agent/audit/adapter.rb` | ⚠️ 80.0% | 4 | 1 | 5 |
| `lib/decision_agent/audit/logger_adapter.rb` | ❌ 66.67% | 8 | 4 | 12 |
| `lib/decision_agent/audit/null_adapter.rb` | ✅ 100.0% | 4 | 0 | 4 |
| `lib/decision_agent/auth/access_audit_logger.rb` | ❌ 38.89% | 21 | 33 | 54 |
| `lib/decision_agent/auth/authenticator.rb` | ❌ 28.0% | 21 | 54 | 75 |
| `lib/decision_agent/auth/password_reset_manager.rb` | ❌ 31.43% | 11 | 24 | 35 |
| `lib/decision_agent/auth/password_reset_token.rb` | ❌ 56.25% | 9 | 7 | 16 |
| `lib/decision_agent/auth/permission.rb` | ⚠️ 72.73% | 8 | 3 | 11 |
| `lib/decision_agent/auth/permission_checker.rb` | ❌ 50.0% | 12 | 12 | 24 |
| `lib/decision_agent/auth/rbac_adapter.rb` | ❌ 25.38% | 33 | 97 | 130 |
| `lib/decision_agent/auth/rbac_config.rb` | ❌ 50.0% | 12 | 12 | 24 |
| `lib/decision_agent/auth/role.rb` | ❌ 52.63% | 10 | 9 | 19 |
| `lib/decision_agent/auth/session.rb` | ❌ 56.25% | 9 | 7 | 16 |
| `lib/decision_agent/auth/session_manager.rb` | ❌ 31.43% | 11 | 24 | 35 |
| `lib/decision_agent/auth/user.rb` | ❌ 38.46% | 15 | 24 | 39 |
| `lib/decision_agent/context.rb` | ❌ 52.38% | 11 | 10 | 21 |
| `lib/decision_agent/decision.rb` | ❌ 36.0% | 9 | 16 | 25 |
| `lib/decision_agent/dsl/condition_evaluator.rb` | ❌ 11.3% | 20 | 157 | 177 |
| `lib/decision_agent/dsl/rule_parser.rb` | ❌ 40.0% | 6 | 9 | 15 |
| `lib/decision_agent/dsl/schema_validator.rb` | ❌ 17.86% | 25 | 115 | 140 |
| `lib/decision_agent/errors.rb` | ❌ 60.66% | 37 | 24 | 61 |
| `lib/decision_agent/evaluation.rb` | ❌ 37.5% | 9 | 15 | 24 |
| `lib/decision_agent/evaluation_validator.rb` | ❌ 24.39% | 10 | 31 | 41 |
| `lib/decision_agent/evaluators/base.rb` | ⚠️ 75.0% | 6 | 2 | 8 |
| `lib/decision_agent/evaluators/json_rule_evaluator.rb` | ❌ 26.32% | 10 | 28 | 38 |
| `lib/decision_agent/evaluators/static_evaluator.rb` | ❌ 46.15% | 6 | 7 | 13 |
| `lib/decision_agent/monitoring/alert_manager.rb` | ❌ 24.44% | 33 | 102 | 135 |
| `lib/decision_agent/monitoring/metrics_collector.rb` | ❌ 20.25% | 33 | 130 | 163 |
| `lib/decision_agent/monitoring/monitored_agent.rb` | ❌ 32.0% | 8 | 17 | 25 |
| `lib/decision_agent/monitoring/prometheus_exporter.rb` | ❌ 18.25% | 23 | 103 | 126 |
| `lib/decision_agent/monitoring/storage/activerecord_adapter.rb` | ❌ 30.43% | 28 | 64 | 92 |
| `lib/decision_agent/monitoring/storage/base_adapter.rb` | ❌ 59.09% | 13 | 9 | 22 |
| `lib/decision_agent/monitoring/storage/memory_adapter.rb` | ❌ 25.25% | 25 | 74 | 99 |
| `lib/decision_agent/replay/replay.rb` | ❌ 19.3% | 11 | 46 | 57 |
| `lib/decision_agent/scoring/base.rb` | ⚠️ 70.0% | 7 | 3 | 10 |
| `lib/decision_agent/scoring/consensus.rb` | ❌ 30.0% | 6 | 14 | 20 |
| `lib/decision_agent/scoring/max_weight.rb` | ❌ 57.14% | 4 | 3 | 7 |
| `lib/decision_agent/scoring/threshold.rb` | ❌ 31.58% | 6 | 13 | 19 |
| `lib/decision_agent/scoring/weighted_average.rb` | ❌ 30.77% | 4 | 9 | 13 |
| `lib/decision_agent/testing/batch_test_importer.rb` | ❌ 12.12% | 16 | 116 | 132 |
| `lib/decision_agent/testing/batch_test_runner.rb` | ❌ 19.09% | 21 | 89 | 110 |
| `lib/decision_agent/testing/test_coverage_analyzer.rb` | ❌ 22.62% | 19 | 65 | 84 |
| `lib/decision_agent/testing/test_result_comparator.rb` | ❌ 20.24% | 17 | 67 | 84 |
| `lib/decision_agent/testing/test_scenario.rb` | ❌ 42.11% | 8 | 11 | 19 |
| `lib/decision_agent/versioning/activerecord_adapter.rb` | ❌ 31.37% | 16 | 35 | 51 |
| `lib/decision_agent/versioning/adapter.rb` | ❌ 45.16% | 14 | 17 | 31 |
| `lib/decision_agent/versioning/file_storage_adapter.rb` | ❌ 24.29% | 34 | 106 | 140 |
| `lib/decision_agent/versioning/version_manager.rb` | ❌ 42.5% | 17 | 23 | 40 |

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
