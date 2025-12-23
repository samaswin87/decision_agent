# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **RFC 8785 Canonical JSON Implementation**
  - **Problem:** Custom recursive JSON canonicalization could be optimized
    - Previous implementation used recursive `JSON.generate` calls creating intermediate strings
    - Not following an industry standard for canonical JSON
    - Potential for optimization in high-throughput scenarios
  - **Solution:** Replaced with RFC 8785 (JSON Canonicalization Scheme)
    - Added `json-canonicalization ~> 1.0` gem dependency
    - Replaced custom `canonical_json` method with RFC 8785 standard implementation
    - Uses `to_json_c14n` method from industry-standard gem
  - **Benefits:**
    - **Industry Standard** - Official IETF RFC 8785 specification
    - **Cryptographically Sound** - Designed specifically for secure hashing of JSON
    - **Better Performance** - Optimized single-pass implementation vs. recursive approach
    - **Interoperability** - Compatible with other systems using RFC 8785
    - **Correctness** - Handles edge cases (Unicode, floats, escaping) per ECMAScript spec
  - **Impact:**
    - Deterministic SHA-256 hashing maintained
    - Same input always produces same audit hash
    - Zero performance regression (~5,800 decisions/second unchanged)
    - Thread-safe (no shared state)
    - Enables tamper detection, replay verification, regulatory compliance
  - **Files Changed:**
    - `decision_agent.gemspec:26` - Added json-canonicalization dependency
    - `lib/decision_agent/agent.rb:3` - Added require statement
    - `lib/decision_agent/agent.rb:141-146` - Replaced custom implementation with RFC 8785
    - `README.md:209-222` - Added RFC 8785 documentation section
    - `wiki/THREAD_SAFETY.md:252-302` - Added RFC 8785 implementation details
  - **Testing:**
    - Added 13 new RFC 8785 compliance tests (`spec/rfc8785_canonicalization_spec.rb`)
    - All 46 core tests passing (agent + thread-safety + RFC 8785)
    - Validates deterministic hashing, property order canonicalization, float serialization
  - **Learn More:**
    - [RFC 8785 Specification](https://datatracker.ietf.org/doc/html/rfc8785)
    - [json-canonicalization gem](https://github.com/dryruby/json-canonicalization)
    - See README.md and THREAD_SAFETY.md for implementation details

### Fixed

- **Issue #8: FileStorageAdapter - Large Directory Scan Performance**
  - **Problem:** With 50,000 files (1000 rules × 50 versions), `get_version`, `activate_version`, and `delete_version` scanned ALL files
    - `all_versions_unsafe()` used `Dir.glob` to scan entire storage tree (O(n) where n = total files)
    - Every version lookup required reading and parsing 50,000 JSON files
    - Single `get_version` call = 100,000+ file I/O operations (scan twice + read files)
    - No caching or indexing mechanism
    - Version IDs didn't directly encode rule_id, requiring full scans to find parent directory
  - **Solution:** Implemented in-memory version index with O(1) lookups
    - Added `@version_index` hash mapping version_id → rule_id
    - Index loaded once at initialization, updated on writes
    - Thread-safe with dedicated `@version_index_lock` mutex
    - Eliminated need for `all_versions_unsafe()` in most operations
    - Operations now read only the specific rule's directory (50 files vs 50,000)
  - **Performance Impact:**
    - `get_version`: 100,000 I/O → 50 I/O (2000x improvement)
    - `activate_version`: 100,050 I/O → 100 I/O (1000x improvement)
    - `delete_version`: 100,000 I/O → 50 I/O (2000x improvement)
    - Memory cost: ~1MB per 50,000 versions (negligible)
  - **Files Changed:**
    - `lib/decision_agent/versioning/file_storage_adapter.rb:19-24` - Added index initialization
    - `lib/decision_agent/versioning/file_storage_adapter.rb:73-84` - Optimized `get_version` with index
    - `lib/decision_agent/versioning/file_storage_adapter.rb:100-125` - Optimized `activate_version` with index
    - `lib/decision_agent/versioning/file_storage_adapter.rb:127-158` - Optimized `delete_version` with index
    - `lib/decision_agent/versioning/file_storage_adapter.rb:187-199` - Optimized `update_version_status_unsafe`
    - `lib/decision_agent/versioning/file_storage_adapter.rb:215` - Update index on write
    - `lib/decision_agent/versioning/file_storage_adapter.rb:237-270` - Added index management methods
  - **Testing:** All 44 existing tests pass, verifying backward compatibility

- **Issue #9: Missing Validation on Status Field**
  - **Problem:** Invalid status values could be stored, bypassing model validations
    - `update_all` in ActiveRecordAdapter bypassed ActiveRecord validations (lines 30, 83)
    - `update_all` in RuleVersion model bypassed validations (line 34)
    - FileStorageAdapter had no validation layer at all
    - `metadata[:status]` accepted any string value without checking
    - Could store invalid values like "banana", "pending", "deleted"
  - **Valid Status Values:** `draft`, `active`, `archived`
  - **Solution:** Added comprehensive status validation across all adapters
    - Created shared `StatusValidator` module with `VALID_STATUSES` constant
    - Added `validate_status!` method that raises `ValidationError` for invalid statuses
    - Replaced all `update_all` calls with `find_each { |v| v.update! }` to trigger validations
    - Validate `metadata[:status]` before accepting it in both adapters
  - **Impact:**
    - All status assignments now validated against whitelist
    - Clear error messages: "Invalid status 'banana'. Must be one of: draft, active, archived"
    - Data integrity ensured at both adapter and model layers
    - Prevents corrupted status values in storage
  - **Files Changed:**
    - `lib/decision_agent/versioning/file_storage_adapter.rb:7-17` - Added StatusValidator module
    - `lib/decision_agent/versioning/file_storage_adapter.rb:21` - Include StatusValidator
    - `lib/decision_agent/versioning/file_storage_adapter.rb:52-54` - Validate status in create_version
    - `lib/decision_agent/versioning/file_storage_adapter.rb:59` - Pass rule_id to update helper
    - `lib/decision_agent/versioning/file_storage_adapter.rb:115` - Pass rule_id to update helper
    - `lib/decision_agent/versioning/file_storage_adapter.rb:204-206` - Validate status in update_version_status
    - `lib/decision_agent/versioning/activerecord_adapter.rb:2` - Import StatusValidator
    - `lib/decision_agent/versioning/activerecord_adapter.rb:9` - Include StatusValidator
    - `lib/decision_agent/versioning/activerecord_adapter.rb:21-23` - Validate status in create_version
    - `lib/decision_agent/versioning/activerecord_adapter.rb:35-38` - Replace update_all with find_each
    - `lib/decision_agent/versioning/activerecord_adapter.rb:83-88` - Replace update_all with find_each
    - `lib/generators/decision_agent/install/templates/rule_version.rb:31-37` - Replace update_all with find_each
  - **Testing:** Added 3 new test cases for status validation (all passing)

- **Issue #6: Missing ConfigurationError Alias**
  - **Problem:** Code referenced `DecisionAgent::ConfigurationError` but only `InvalidConfigurationError` was defined
    - Caused `NameError: uninitialized constant DecisionAgent::ConfigurationError`
    - ActiveRecordAdapter initialization failures
    - Version management operations crashed
  - **Solution:** Added `ConfigurationError = InvalidConfigurationError` alias
    - Maintains backward compatibility with both names
    - Zero breaking changes
  - **Impact:**
    - All error references now work correctly
    - Clearer naming convention available
  - **Files Changed:**
    - `lib/decision_agent/errors.rb:76` - Added ConfigurationError alias
  - **Testing:** Added 8 comprehensive error class verification specs

- **Issue #7: JSON Serialization Crashes in ActiveRecordAdapter**
  - **Problem:** `serialize_version` called `JSON.parse` without error handling
    - Invalid JSON crashed entire adapter with `JSON::ParserError`
    - Empty strings, nil content, malformed UTF-8 caused unhandled exceptions
    - Data corruption made all adapter operations fail
    - No graceful degradation or clear error messages
  - **Solution:** Added comprehensive error handling with clear ValidationError messages
    - Catches `JSON::ParserError`, `TypeError`, `NoMethodError`
    - Raises `DecisionAgent::ValidationError` with version ID and rule ID in message
    - Provides actionable debugging information
  - **Impact:**
    - Corrupted data now produces clear error messages
    - Operations fail gracefully with proper error types
    - Better debugging experience with version/rule context
  - **Edge Cases Handled:**
    - Invalid JSON: `"{ broken"`
    - Empty content: `""`
    - Nil content: `nil`
    - Malformed UTF-8: `"\xFF\xFE"`
    - Truncated JSON: `'{"version":"1.0","rules":[{"id"'`
  - **Files Changed:**
    - `lib/decision_agent/versioning/activerecord_adapter.rb:104-126` - Added JSON error handling
  - **Testing:** Added 10 edge case specs covering all JSON failure scenarios

- **Issue #5: FileStorageAdapter Global Mutex Performance Bottleneck**
  - **Problem:** Single global `@mutex` serialized ALL operations, even for different rules
    - Thread A reading `loan_approval` blocked Thread B reading `fraud_detection`
    - Zero parallelism for read operations on different rules
    - Unnecessary performance bottleneck in multi-tenant scenarios
  - **Solution:** Implemented per-rule locking with Hash of mutexes
    - Each rule_id gets its own Mutex (lazy-created)
    - Different rules can be read/written in parallel
    - Same rule operations still properly serialized
    - Thread-safe Hash access via `@rule_mutexes_lock`
  - **Impact:**
    - ~5x potential speedup for concurrent reads of different rules
    - Better CPU utilization in multi-threaded environments
    - Maintains all thread-safety guarantees
  - **Implementation:**
    ```ruby
    # Before: Global mutex blocks everything
    @mutex.synchronize { ... }

    # After: Per-rule mutex allows parallelism
    with_rule_lock(rule_id) { ... }

    def with_rule_lock(rule_id)
      mutex = @rule_mutexes_lock.synchronize { @rule_mutexes[rule_id] }
      mutex.synchronize { yield }
    end
    ```
  - **Files Changed:**
    - `lib/decision_agent/versioning/file_storage_adapter.rb:14-20` - Initialize per-rule mutexes
    - `lib/decision_agent/versioning/file_storage_adapter.rb:22-150` - Replace global mutex with per-rule locking
    - `lib/decision_agent/versioning/file_storage_adapter.rb:193-198` - Add `with_rule_lock` helper
  - **Testing:** Added 3 performance benchmark specs demonstrating parallelism improvements

### Changed

- **Issue #4: Enhanced Database Constraint Documentation**
  - **Status:** Unique constraint was already present, added comprehensive documentation
  - **Changes:**
    - Added critical importance comments for `[rule_id, version_number]` unique constraint
    - Documented protection against race conditions in concurrent version creation
    - Added optional PostgreSQL partial unique index example for one-active-version enforcement
  - **Files Changed:**
    - `lib/generators/decision_agent/install/templates/migration.rb:23-35` - Enhanced comments
  - **Testing:** Added 8 specs demonstrating race condition prevention with/without constraints

### Added

- Comprehensive issue verification test suite (`spec/issue_verification_spec.rb`)
  - 29 new test cases covering all 4 issues
  - Performance benchmarks for mutex improvements
  - Edge case coverage for JSON serialization
  - Race condition demonstrations

### Performance

- **FileStorageAdapter:** Up to 5x speedup for concurrent operations on different rules
- **ActiveRecordAdapter:** No performance impact from JSON error handling (<1% overhead)
- **Error Classes:** Zero overhead from alias
- All fixes maintain 94.9% code coverage (800/843 lines)

### Documentation

- Enhanced migration template comments for database constraints
- Added comprehensive CHANGELOG entries with implementation details

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
