# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2025-01-15

### Fixed

- Fixed race condition in FileStorageAdapter causing JSON parsing errors during concurrent version creation
- Added atomic file writes to prevent corrupted version files when multiple threads write simultaneously
- Added Ruby 4.0 compatibility workaround for Bundler::ORIGINAL_ENV in web server

## [0.1.1] - 2025-01-15

### Added

- Version management system with FileStorageAdapter
- Rule versioning with changelog support
- Version activation and rollback capabilities
- Web UI for rule building and management

## [0.1.0] - 2025-01-15

### Added

- Initial release of DecisionAgent
- Core agent orchestration with pluggable evaluators
- StaticEvaluator for simple rules
- JsonRuleEvaluator with full DSL support
- JSON Rule DSL with operators: eq, neq, gt, gte, lt, lte, in, present, blank
- Condition combinators: all, any
- Nested field access via dot notation
- Four scoring strategies: WeightedAverage, MaxWeight, Consensus, Threshold
- Audit system with NullAdapter and LoggerAdapter
- Decision replay with strict and non-strict modes
- Deterministic hash generation for audit payloads
- Full immutability of Context, Evaluation, and Decision objects
- Comprehensive error handling with namespaced exceptions
- Complete RSpec test suite with 90%+ coverage
- Production-ready documentation with examples
- Healthcare and issue triage example rulesets

### Design Principles

- Deterministic by default
- AI-optional architecture
- Framework-agnostic (no Rails/ActiveRecord dependencies)
- Full explainability and auditability
- Safe for regulated domains (healthcare, finance)

[0.1.0]: https://github.com/samaswin87/decision_agent/releases/tag/v0.1.0
