# Code Coverage Report

**Last Updated:** 2026-01-06 22:13:58

## Summary

| Metric | Value |
|--------|-------|
| **Total Coverage** | **86.28%** |
| Total Files | 90 |
| Total Relevant Lines | 8623 |
| Lines Covered | 7440 |
| Lines Missed | 1183 |

> **Note:** This report excludes files in the `examples/` directory as they are sample code, not production code.

## Coverage by File

| File | Coverage | Lines Covered | Lines Missed | Total Lines |
|------|----------|---------------|--------------|-------------|
| `lib/decision_agent.rb` | ✅ 97.75% | 87 | 2 | 89 |
| `lib/decision_agent/ab_testing/ab_test.rb` | ✅ 93.98% | 78 | 5 | 83 |
| `lib/decision_agent/ab_testing/ab_test_assignment.rb` | ✅ 100.0% | 28 | 0 | 28 |
| `lib/decision_agent/ab_testing/ab_test_manager.rb` | ✅ 92.54% | 124 | 10 | 134 |
| `lib/decision_agent/ab_testing/ab_testing_agent.rb` | ✅ 100.0% | 63 | 0 | 63 |
| `lib/decision_agent/ab_testing/storage/adapter.rb` | ✅ 100.0% | 20 | 0 | 20 |
| `lib/decision_agent/ab_testing/storage/memory_adapter.rb` | ✅ 100.0% | 67 | 0 | 67 |
| `lib/decision_agent/agent.rb` | ✅ 100.0% | 81 | 0 | 81 |
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
| `lib/decision_agent/context.rb` | ✅ 100.0% | 32 | 0 | 32 |
| `lib/decision_agent/data_enrichment/cache/memory_adapter.rb` | ✅ 100.0% | 33 | 0 | 33 |
| `lib/decision_agent/data_enrichment/cache_adapter.rb` | ⚠️ 73.33% | 11 | 4 | 15 |
| `lib/decision_agent/data_enrichment/circuit_breaker.rb` | ✅ 96.88% | 62 | 2 | 64 |
| `lib/decision_agent/data_enrichment/client.rb` | ✅ 96.3% | 104 | 4 | 108 |
| `lib/decision_agent/data_enrichment/config.rb` | ✅ 100.0% | 19 | 0 | 19 |
| `lib/decision_agent/data_enrichment/errors.rb` | ⚠️ 76.92% | 10 | 3 | 13 |
| `lib/decision_agent/decision.rb` | ✅ 96.67% | 29 | 1 | 30 |
| `lib/decision_agent/dmn/adapter.rb` | ⚠️ 79.25% | 42 | 11 | 53 |
| `lib/decision_agent/dmn/decision_graph.rb` | ⚠️ 72.37% | 110 | 42 | 152 |
| `lib/decision_agent/dmn/decision_tree.rb` | ✅ 96.39% | 80 | 3 | 83 |
| `lib/decision_agent/dmn/errors.rb` | ✅ 100.0% | 11 | 0 | 11 |
| `lib/decision_agent/dmn/exporter.rb` | ⚠️ 80.19% | 85 | 21 | 106 |
| `lib/decision_agent/dmn/feel/evaluator.rb` | ❌ 63.9% | 246 | 139 | 385 |
| `lib/decision_agent/dmn/feel/functions.rb` | ✅ 99.55% | 220 | 1 | 221 |
| `lib/decision_agent/dmn/feel/parser.rb` | ✅ 91.94% | 114 | 10 | 124 |
| `lib/decision_agent/dmn/feel/simple_parser.rb` | ✅ 97.83% | 135 | 3 | 138 |
| `lib/decision_agent/dmn/feel/transformer.rb` | ❌ 69.47% | 91 | 40 | 131 |
| `lib/decision_agent/dmn/feel/types.rb` | ⚠️ 83.7% | 113 | 22 | 135 |
| `lib/decision_agent/dmn/importer.rb` | ✅ 100.0% | 30 | 0 | 30 |
| `lib/decision_agent/dmn/model.rb` | ✅ 98.37% | 121 | 2 | 123 |
| `lib/decision_agent/dmn/parser.rb` | ✅ 95.29% | 81 | 4 | 85 |
| `lib/decision_agent/dmn/validator.rb` | ⚠️ 87.58% | 141 | 20 | 161 |
| `lib/decision_agent/dsl/condition_evaluator.rb` | ⚠️ 84.63% | 672 | 122 | 794 |
| `lib/decision_agent/dsl/rule_parser.rb` | ✅ 100.0% | 15 | 0 | 15 |
| `lib/decision_agent/dsl/schema_validator.rb` | ✅ 97.56% | 160 | 4 | 164 |
| `lib/decision_agent/errors.rb` | ✅ 96.72% | 59 | 2 | 61 |
| `lib/decision_agent/evaluation.rb` | ✅ 96.55% | 28 | 1 | 29 |
| `lib/decision_agent/evaluation_validator.rb` | ✅ 100.0% | 37 | 0 | 37 |
| `lib/decision_agent/evaluators/base.rb` | ✅ 100.0% | 8 | 0 | 8 |
| `lib/decision_agent/evaluators/dmn_evaluator.rb` | ✅ 91.01% | 81 | 8 | 89 |
| `lib/decision_agent/evaluators/json_rule_evaluator.rb` | ✅ 97.37% | 37 | 1 | 38 |
| `lib/decision_agent/evaluators/static_evaluator.rb` | ✅ 100.0% | 13 | 0 | 13 |
| `lib/decision_agent/monitoring/alert_manager.rb` | ✅ 91.3% | 126 | 12 | 138 |
| `lib/decision_agent/monitoring/metrics_collector.rb` | ✅ 94.71% | 161 | 9 | 170 |
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
| `lib/decision_agent/simulation.rb` | ✅ 100.0% | 10 | 0 | 10 |
| `lib/decision_agent/simulation/errors.rb` | ✅ 100.0% | 7 | 0 | 7 |
| `lib/decision_agent/simulation/impact_analyzer.rb` | ✅ 90.28% | 195 | 21 | 216 |
| `lib/decision_agent/simulation/monte_carlo_simulator.rb` | ⚠️ 89.05% | 244 | 30 | 274 |
| `lib/decision_agent/simulation/replay_engine.rb` | ⚠️ 79.22% | 183 | 48 | 231 |
| `lib/decision_agent/simulation/scenario_engine.rb` | ⚠️ 87.5% | 126 | 18 | 144 |
| `lib/decision_agent/simulation/scenario_library.rb` | ✅ 98.21% | 55 | 1 | 56 |
| `lib/decision_agent/simulation/shadow_test_engine.rb` | ⚠️ 84.5% | 109 | 20 | 129 |
| `lib/decision_agent/simulation/what_if_analyzer.rb` | ✅ 92.05% | 405 | 35 | 440 |
| `lib/decision_agent/testing/batch_test_importer.rb` | ⚠️ 87.18% | 136 | 20 | 156 |
| `lib/decision_agent/testing/batch_test_runner.rb` | ✅ 94.55% | 104 | 6 | 110 |
| `lib/decision_agent/testing/test_coverage_analyzer.rb` | ✅ 96.43% | 81 | 3 | 84 |
| `lib/decision_agent/testing/test_result_comparator.rb` | ✅ 97.62% | 82 | 2 | 84 |
| `lib/decision_agent/testing/test_scenario.rb` | ✅ 94.74% | 18 | 1 | 19 |
| `lib/decision_agent/versioning/activerecord_adapter.rb` | ⚠️ 83.93% | 47 | 9 | 56 |
| `lib/decision_agent/versioning/adapter.rb` | ✅ 100.0% | 31 | 0 | 31 |
| `lib/decision_agent/versioning/file_storage_adapter.rb` | ✅ 90.68% | 146 | 15 | 161 |
| `lib/decision_agent/versioning/version_manager.rb` | ✅ 95.0% | 38 | 2 | 40 |
| `lib/decision_agent/web/middleware/auth_middleware.rb` | ✅ 100.0% | 25 | 0 | 25 |
| `lib/decision_agent/web/middleware/permission_middleware.rb` | ✅ 100.0% | 43 | 0 | 43 |
| `lib/decision_agent/web/server.rb` | ❌ 55.08% | 526 | 429 | 955 |

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
