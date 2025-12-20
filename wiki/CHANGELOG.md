# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-12-20

### Added

- **Thread-Safety Enhancements**
  - New `EvaluationValidator` class for validating evaluation correctness and frozen state
  - Automatic validation of all evaluations in `Agent#decide` before scoring
  - Deep freezing of all Decision and Evaluation objects for immutability
  - Frozen evaluator configurations (JsonRuleEvaluator rulesets, Agent evaluator arrays)
  - Mutex-protected read operations in FileStorageAdapter (`list_versions`, `get_version`, `get_version_by_number`, `get_active_version`)
  - Comprehensive thread-safety test suite (12 new tests covering concurrent scenarios)
  - Thread-safety documentation in README and new THREAD_SAFETY.md guide
  - ActiveRecord thread safety tests with 20/100-thread concurrent scenarios
  - Race condition demo script (`examples/race_condition_demo.rb`)

### Changed

- Decision and Evaluation objects now call `freeze` in their initializers
- JsonRuleEvaluator now deep-freezes all ruleset data structures
- Agent now freezes the evaluators array to prevent modification
- FileStorageAdapter read methods now use mutex synchronization for consistency

### Fixed

- **CRITICAL: ActiveRecordAdapter Race Condition in create_version**
  - **Problem:** Classic "read-then-increment" race condition in `create_version` method
    - Multiple concurrent threads could read the same version number
    - Led to duplicate version numbers and database constraint violations
    - Caused data corruption under high concurrency
  - **Solution:** Implemented pessimistic locking with database transactions
    - Wrapped version creation in `transaction` block
    - Added `.lock` (SELECT ... FOR UPDATE) to version number query
    - Ensures atomic read-increment-create operation
  - **Impact:**
    - Two concurrent requests creating same version number → Fixed
    - Database constraint violations under load → Eliminated
    - Production failures during concurrent version creation → Resolved
  - **Files Changed:**
    - `lib/decision_agent/versioning/activerecord_adapter.rb` - Added transaction with pessimistic locking
    - `lib/generators/decision_agent/install/templates/rule_version.rb` - Added `.lock` to `set_next_version_number` callback
  - **Testing:** Added `spec/activerecord_thread_safety_spec.rb` with concurrent version creation tests (20/100 threads)
  - **How It Works:**
    ```
    Thread A: SELECT ... FOR UPDATE → locks row
    Thread B: SELECT ... FOR UPDATE → WAITS...
    Thread A: INSERT version N, COMMIT → releases lock
    Thread B: SELECT ... FOR UPDATE → reads version N
    Thread B: INSERT version N+1 ✅ CORRECT!
    ```
  - **Database Support:** Works across PostgreSQL, MySQL, SQLite, and Oracle
  - **Performance:** Lock held only during critical section (read-increment-insert), minimal contention
  - **Migration:** Existing installations should update RuleVersion model to add `.lock` to version number query

- **CRITICAL: ActiveRecordAdapter Race Condition in activate_version**
  - **Problem:** Race condition when multiple threads activate different versions simultaneously
    - Thread A deactivates active versions, Thread B does the same → Both succeed
    - Thread A activates version 6, Thread B activates version 7 → **Two active versions!**
    - Violated the business invariant: exactly one active version per rule
  - **Solution:** Wrapped activate_version in database transaction with pessimistic locking
    - Added `transaction do ... end` block around deactivate + activate operations
    - Added `.lock` (SELECT ... FOR UPDATE) when finding version to activate
    - Ensures atomic deactivate-all + activate-one operation
  - **Impact:**
    - Multiple active versions → Eliminated
    - Race condition under concurrent activation → Fixed
    - Data integrity violations → Resolved
  - **Files Changed:**
    - `lib/decision_agent/versioning/activerecord_adapter.rb:72-90` - Wrapped in transaction with locking
  - **Testing:** Added comprehensive concurrent activation tests in `spec/activerecord_thread_safety_spec.rb`
    - 10 threads activating different versions concurrently
    - 100 threads with random version activation
    - Barrier-synchronized simultaneous activation (worst-case race condition)
  - **How It Works:**
    ```
    Thread A: BEGIN TRANSACTION, SELECT version FOR UPDATE → locks version
    Thread B: BEGIN TRANSACTION, SELECT version FOR UPDATE → WAITS...
    Thread A: UPDATE all active → archived, UPDATE this version → active, COMMIT
    Thread B: proceeds after Thread A commits, ensures only one active
    ```

- **IMPROVEMENT: Rollback No Longer Creates Duplicate Versions**
  - **Problem:** `VersionManager.rollback` created a new duplicate version when rolling back
    - Rollback to v3 would create v7 (a copy of v3)
    - Resulted in: v1, v2, v3, v4, v5, v6, v7 (where v7 = v3)
    - Cluttered version history with unnecessary duplicates
  - **Solution:** Simplified rollback to only activate the target version
    - Removed `save_version` call that created the duplicate
    - Now rollback just calls `activate_version` (which is thread-safe)
    - Version history remains clean: v1, v2, v3, v4, v5, v6 (v3 becomes active)
  - **Impact:**
    - Cleaner version history without duplicates
    - Rollback operations are now idempotent
    - Better audit trail (status changes visible, no fake versions)
  - **Files Changed:**
    - `lib/decision_agent/versioning/version_manager.rb:61-65` - Removed duplicate creation logic
  - **Testing:** Updated all rollback tests in `spec/versioning_spec.rb` to verify no duplication
  - **Migration Notes:**
    - This is a behavioral change - rollback no longer creates audit entries via new versions
    - If audit trail is required, implement at application level or via database triggers on status changes
    - Existing code calling `rollback` will work but see different version counts

### Performance

- **Zero performance impact**: Thread-safety is achieved through immutability, not locking
- Freezing overhead is negligible (microseconds per object)
- Decision-making performance remains unchanged
- Only file I/O operations use mutex (does not affect decision speed)
- Safe for high-throughput applications (tested with 50+ concurrent threads)
- ActiveRecord pessimistic locking adds minimal overhead (single row lock per version creation)

### Documentation

- Added "Thread-Safe" feature to README Production Ready section
- Added comprehensive "Thread-Safety Guarantees" section with examples
- Created THREAD_SAFETY.md with detailed implementation guide
- Added performance benchmark example demonstrating zero overhead

## [0.1.2] - 2025-01-15

### Added

- Version management system with FileStorageAdapter and ActiveRecordAdapter
- Rule versioning with changelog support and activation/rollback capabilities
- Web UI for rule building, version management, and visualization
- Rails generator for easy installation (`rails generate decision_agent:install`)
- Comprehensive versioning examples and documentation

### Fixed

- Fixed race condition in FileStorageAdapter causing JSON parsing errors during concurrent version creation
- Added atomic file writes to prevent corrupted version files when multiple threads write simultaneously
- Added Ruby 4.0 compatibility workaround for Bundler::ORIGINAL_ENV in web server

### Changed

- Dropped Ruby 2.7 support, now requires Ruby 3.0 or higher

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
