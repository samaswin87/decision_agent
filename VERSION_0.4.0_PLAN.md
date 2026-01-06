# Version 0.4.0 Development Plan

**Target Release Date:** Q2 2026  
**Current Version:** 0.3.0  
**Status:** Planning Phase

---

## Executive Summary

Version 0.4.0 focuses on completing **Phase 2: Enterprise Features** from the gap analysis, bringing DecisionAgent to competitive parity with mid-market decision engines. This release will add critical enterprise capabilities: data enrichment, simulation/testing, and governance workflows.

**Key Goals:**
- Complete remaining Phase 2 features (REST API data enrichment, simulation, optional common workflow DSL)
- Finish mathematical expression operators
- Add shadow testing and test scenario library
- Establish foundation for Phase 3 advanced capabilities
- Maintain backward compatibility and production stability

**Estimated Timeline:** 
- **Core features (without workflow DSL):** 10-14 weeks (2.5-3.5 months) with 2-3 developers
- **Common workflow DSL (optional configurable feature):** 5-6 weeks (can be developed in parallel or after core features)
- **Note:** The common workflow DSL is an optional, configurable feature that users can enable via environment variable (`DECISION_AGENT_ENABLE_WORKFLOWS=true`) and run migrations when needed. The foundation exists (versioning + RBAC + audit), so workflows can be added as an optional feature that users enable when they need it. The DSL supports any workflow type (approval, review, testing, deployment, custom), not just approvals.

---

## Strategic Context

### Current State (v0.3.0)
✅ **Completed:**
- DMN 1.3 standard support (full FEEL, visual editor, import/export)
- Advanced operators (regex, dates, strings, collections, geospatial)
- Real-time calculations and statistical operators
- RBAC system with multiple adapter support
- A/B testing framework
- Batch testing with CSV/Excel import
- Comprehensive monitoring and analytics
- Web UI with rule builder and DMN editor

### Remaining Gaps (Phase 2)
❌ **Missing:**
- ~~REST API for data enrichment~~ ✅ **COMPLETED**
- ~~Simulation and what-if analysis (including backtesting/historical replay)~~ ✅ **COMPLETED**
- Common workflow DSL system (foundation exists: versioning + RBAC + audit, but built-in workflow engine missing) - **Will be optional configurable feature supporting any workflow type**
- Complete mathematical expressions (sin, cos, sqrt, etc.) - partial: between, modulo exist
- ~~Shadow testing (compare new rules against production without affecting outcomes)~~ ✅ **COMPLETED** (included in Simulation module)

### Market Position
DecisionAgent currently has **feature parity** with mid-market solutions in core areas (versioning, testing, monitoring, DMN). Version 0.4.0 will close the remaining enterprise gaps (data enrichment, simulation, mathematical expressions) and position the platform for broader enterprise adoption. 

**Performance Status:** Current throughput (7,300-7,800+ decisions/second) is production-ready for most enterprise use cases, capable of handling ~26-28 million decisions/day on a single instance.

---

## Feature Breakdown

### 1. REST API Data Enrichment ⭐ **HIGH PRIORITY** ✅ **COMPLETED**

**Goal:** Enable rules to fetch external data during decision-making without manual context assembly.

**Status:** ✅ **COMPLETED** - All core features implemented, tested, and documented.

**Business Value:**
- Eliminates manual data preparation overhead
- Enables real-time decision-making with live data
- Reduces errors from stale or missing context
- Critical for fraud detection, credit scoring, and dynamic pricing

**Technical Requirements:**

#### 1.1 HTTP Client Integration
- **DataEnrichmentClient** class for HTTP requests
- Support for GET, POST, PUT, DELETE methods
- Configurable timeouts and retries
- SSL/TLS certificate validation
- Request/response logging for audit

#### 1.2 Response Caching
- **CacheAdapter** interface (Memory, Redis, custom)
- Configurable TTL per endpoint
- Cache invalidation strategies (time-based, manual, event-driven)
- Cache key generation from request parameters
- Cache hit/miss metrics

#### 1.3 Error Handling & Resilience
- Circuit breaker pattern (fail-fast after N failures)
- Exponential backoff retry strategy
- Graceful degradation (fallback to cached data or default values)
- Timeout handling with configurable thresholds
- Error classification (network, timeout, 4xx, 5xx)

#### 1.4 DSL Integration
- New operator: `fetch_from_api` for rule conditions
- Context enrichment hooks in Agent class
- Pre-decision and post-decision enrichment hooks
- Field mapping from API responses to context

#### 1.5 Configuration & Security
- API endpoint configuration (base URL, headers, auth)
- Authentication support (API key, OAuth2, Basic Auth)
- Secret management (environment variables, vault integration)
- Rate limiting per endpoint
- Request signing for security

**API Design:**
```ruby
# Configuration
DecisionAgent.configure_data_enrichment do |config|
  config.add_endpoint(:credit_bureau,
    url: "https://api.creditbureau.com/v1/score",
    method: :post,
    auth: { type: :api_key, header: "X-API-Key" },
    cache: { ttl: 3600, adapter: :redis },
    retry: { max_attempts: 3, backoff: :exponential }
  )
end

# Usage in rules
{
  "field": "credit_score",
  "op": "fetch_from_api",
  "value": {
    "endpoint": "credit_bureau",
    "params": { "ssn": "{{customer.ssn}}" },
    "mapping": { "score": "credit_score" }
  }
}
```

**Estimated Effort:** 3-4 weeks  
**Actual Effort:** ✅ **COMPLETED**  
**Dependencies:** HTTP client gem (net/http or faraday), optional Redis for caching  
**Files Created:**
- ✅ `lib/decision_agent/data_enrichment/config.rb`
- ✅ `lib/decision_agent/data_enrichment/client.rb`
- ✅ `lib/decision_agent/data_enrichment/cache_adapter.rb`
- ✅ `lib/decision_agent/data_enrichment/cache/memory_adapter.rb`
- ✅ `lib/decision_agent/data_enrichment/circuit_breaker.rb`
- ✅ `lib/decision_agent/data_enrichment/errors.rb`
- ✅ `lib/decision_agent/dsl/condition_evaluator.rb` (extended with fetch_from_api operator)
- ✅ `lib/decision_agent/dsl/schema_validator.rb` (updated with fetch_from_api operator validation)
- ✅ `spec/data_enrichment/config_spec.rb`
- ✅ `spec/data_enrichment/cache/memory_adapter_spec.rb`
- ✅ `spec/data_enrichment/circuit_breaker_spec.rb`
- ✅ `spec/data_enrichment/client_spec.rb` (comprehensive client integration tests)
- ✅ `spec/data_enrichment/fetch_from_api_integration_spec.rb` (operator integration tests)
- ✅ `examples/data_enrichment_example.rb` (complete working example)
- ✅ `docs/DATA_ENRICHMENT.md` (comprehensive documentation)

**Implementation Notes:**
- HTTP client implemented using Ruby's standard `net/http` library (no external dependencies)
- Memory cache adapter implemented (Redis adapter can be added as future enhancement)
- Circuit breaker pattern fully implemented with CLOSED/OPEN/HALF_OPEN states
- `fetch_from_api` operator integrated into ConditionEvaluator with template parameter expansion
- Authentication support for API key, Basic Auth, and Bearer tokens
- Comprehensive error handling with graceful degradation
- Full documentation and test suite included
- Schema validator updated to recognize `fetch_from_api` operator with proper validation
- Complete integration tests for client and operator usage
- Working example file demonstrating all features
- Added `webmock` gem as development dependency for HTTP mocking in tests

---

### 2. Simulation and What-If Analysis ⭐ **HIGH PRIORITY** ✅ **COMPLETED**

**Goal:** Enable teams to test rule changes against historical data and simulate scenarios before deployment.

**Status:** ✅ **COMPLETED** - All core features implemented, tested, and documented.

**Business Value:**
- Predict impact of rule changes before production
- Validate compliance with historical data
- Reduce risk of deploying problematic rules
- Enable data-driven rule optimization

**Technical Requirements:**

#### 2.1 Scenario Testing Framework ✅ **COMPLETED**
- **ScenarioEngine** for defining and executing scenarios ✅
- Support for multiple scenario types (historical replay, synthetic, edge cases) ✅
- **Test scenario library** and template management ✅
- Batch scenario execution with parallel processing ✅
- Scenario comparison (baseline vs. proposed rules) ✅
- **Shadow testing** to compare new rules against production without affecting outcomes ✅

#### 2.2 Historical Replay / Backtesting ✅ **COMPLETED**
- **ReplayEngine** for replaying historical decisions ✅
- Import historical context data (CSV, JSON, database) ✅
- Replay with different rule versions ✅
- Compare outcomes (decision changes, confidence shifts) ✅
- Impact analysis reports (how many decisions changed, by how much) ✅
- **Backtesting** against historical data to validate rule changes ✅
- Support for large historical datasets (10k+ decisions) ✅

#### 2.3 What-If Analysis
- ✅ **WhatIfAnalyzer** for scenario simulation
- ✅ Modify context values and see decision impact
- ✅ Sensitivity analysis (which inputs affect decisions most)
- ✅ Decision boundary visualization
- ✅ Monte Carlo simulation for probabilistic outcomes

#### 2.4 Impact Analysis
- ✅ **ImpactAnalyzer** for quantifying rule change effects
- ✅ Decision distribution changes
- ✅ Confidence score shifts
- ✅ Rule execution frequency changes
- ✅ Performance impact estimation
- ✅ Risk assessment (regression detection)

#### 2.6 Shadow Testing
- ✅ **ShadowTestEngine** for comparing new rules against production without affecting outcomes
- ✅ Execute new rules in parallel with production rules
- ✅ Compare decision differences (shadow vs. production)
- ✅ Track confidence score variations
- ✅ Identify edge cases and regressions
- ✅ Zero impact on production traffic

#### 2.5 Web UI Integration ✅ **COMPLETED**
- ✅ Scenario builder interface - Interactive scenario builder in what-if analysis UI
- ✅ Historical data import wizard - CSV/JSON file upload with drag-and-drop support
- ✅ What-if analysis dashboard - Complete UI at `/simulation/whatif`
- ✅ Impact visualization - Risk scores, metrics, and decision distribution charts
- ✅ Comparison reports - Before/after visualization in impact analysis and replay
- ✅ Simulation dashboard - Main entry point at `/simulation` with feature overview
- ✅ Shadow testing UI - Production comparison interface at `/simulation/shadow`

**API Design:**
```ruby
# Historical replay / Backtesting
replay_engine = DecisionAgent::Simulation::ReplayEngine.new(agent)
results = replay_engine.replay(
  historical_data: "decisions_2025.csv",
  rule_version: new_version_id,
  compare_with: baseline_version_id
)
# => { changed_decisions: 150, confidence_delta: -0.05, ... }

# What-if analysis
analyzer = DecisionAgent::Simulation::WhatIfAnalyzer.new(agent)
scenarios = [
  { amount: 1000, credit_score: 750 },
  { amount: 5000, credit_score: 650 }
]
results = analyzer.analyze(scenarios, rule_version: v2_id)
# => Array of decision outcomes for each scenario

# Impact analysis
impact = DecisionAgent::Simulation::ImpactAnalyzer.new
report = impact.analyze(
  baseline_version: v1_id,
  proposed_version: v2_id,
  test_data: historical_contexts
)
# => { decision_changes: {...}, confidence_impact: {...}, risk_score: 0.15 }

# Shadow testing
shadow_engine = DecisionAgent::Simulation::ShadowTestEngine.new(agent)
shadow_results = shadow_engine.test(
  production_version: v1_id,
  shadow_version: v2_id,
  context: production_context
)
# => { production_decision: "approve", shadow_decision: "reject", 
#      confidence_delta: 0.12, matches: false }
```

**Estimated Effort:** 6-8 weeks (includes shadow testing and scenario library)  
**Actual Effort:** ✅ **COMPLETED**  
**Dependencies:** CSV parsing (existing), statistical analysis gems  
**Files Created:**
- ✅ `lib/decision_agent/simulation/errors.rb` - Error classes for simulation module
- ✅ `lib/decision_agent/simulation/replay_engine.rb` - Historical replay and backtesting engine
- ✅ `lib/decision_agent/simulation/what_if_analyzer.rb` - What-if scenario analysis engine
- ✅ `lib/decision_agent/simulation/impact_analyzer.rb` - Rule change impact analysis engine
- ✅ `lib/decision_agent/simulation/shadow_test_engine.rb` - Shadow testing engine for production comparison
- ✅ `lib/decision_agent/simulation/scenario_engine.rb` - Scenario management and execution engine
- ✅ `lib/decision_agent/simulation/scenario_library.rb` - Pre-defined scenario templates library
- ✅ `lib/decision_agent/simulation.rb` - Main simulation module entry point
- ✅ `spec/simulation/replay_engine_spec.rb` - ReplayEngine comprehensive tests
- ✅ `spec/simulation/what_if_analyzer_spec.rb` - WhatIfAnalyzer comprehensive tests
- ✅ `spec/simulation/impact_analyzer_spec.rb` - ImpactAnalyzer comprehensive tests
- ✅ `spec/simulation/shadow_test_engine_spec.rb` - ShadowTestEngine comprehensive tests
- ✅ `spec/simulation/scenario_engine_spec.rb` - ScenarioEngine comprehensive tests
- ✅ `spec/simulation/scenario_library_spec.rb` - ScenarioLibrary comprehensive tests
- ✅ `examples/simulation_example.rb` - Complete working example demonstrating all features
- ✅ `docs/SIMULATION.md` - Comprehensive documentation guide (600+ lines)
- ✅ `lib/decision_agent/web/public/simulation.html` - Simulation dashboard UI
- ✅ `lib/decision_agent/web/public/simulation_replay.html` - Historical replay UI
- ✅ `lib/decision_agent/web/public/simulation_whatif.html` - What-if analysis UI
- ✅ `lib/decision_agent/web/public/simulation_impact.html` - Impact analysis UI
- ✅ `lib/decision_agent/web/public/simulation_shadow.html` - Shadow testing UI
- ✅ API endpoints in `lib/decision_agent/web/server.rb` for all simulation features

**Implementation Notes:**
- All core components implemented with full feature set
- Historical replay supports CSV and JSON file import
- What-if analysis includes sensitivity analysis
- Impact analysis includes risk score calculation
- Shadow testing provides zero-impact production comparison
- Scenario engine supports batch execution and version comparison
- Scenario library includes pre-defined templates and edge case generation
- Comprehensive test suite with 6 test files covering all components
- Complete documentation with examples and best practices
- Thread-safe implementation with parallel execution support
- Integration with existing versioning system

---

### 3. Common Workflow DSL System 🟡 **OPTIONAL / CONFIGURABLE FEATURE**

**Goal:** Create a flexible, extensible workflow DSL that supports any workflow type (approval, review, testing, deployment, custom workflows) with a unified interface.

**Installation Model:** This is an **optional, configurable feature** built into the main gem that users can enable whenever they need it:
- **Enabled via environment variable:** `DECISION_AGENT_ENABLE_WORKFLOWS=true`
- **Database migrations:** Run migrations when enabling (if using database adapters)
- **Lazy loading:** Workflow code only loaded when feature is enabled
- **No breaking changes:** Feature is completely optional and can be enabled at any time

**Note:** The foundation for workflows already exists:
- ✅ Versioning with draft/active/archived status
- ✅ RBAC system for access control
- ✅ Audit logging for compliance
- Applications can build workflows on top, or use external systems (Git PRs, CI/CD, workflow tools)

**Business Value:**
- **Flexible workflow support:** Not limited to approvals - supports any workflow type (approval, review, testing, deployment, custom)
- **Unified DSL:** Single workflow definition language for all workflow types
- **Reusable templates:** Create workflow templates once, reuse for different contexts
- **Enforce separation of duties:** SOX, HIPAA compliance for any workflow type
- **Maintain audit trail:** Complete history for regulatory compliance
- **Extensible:** Easy to add new workflow step types and behaviors

**Configuration:**
```ruby
# Enable via environment variable
ENV['DECISION_AGENT_ENABLE_WORKFLOWS'] = 'true'

# Or in configuration
DecisionAgent.configure do |config|
  config.enable_workflows = ENV.fetch('DECISION_AGENT_ENABLE_WORKFLOWS', 'false') == 'true'
end

# Run migrations when enabling (if using database adapters)
# rails db:migrate  # or rake db:migrate
# Migrations will only create tables if workflows are enabled
```

**Technical Requirements:**

#### 3.1 Workflow DSL Core
- **WorkflowDSL** - Domain-specific language for defining workflows
- **WorkflowTemplate** - Reusable workflow definitions
- **WorkflowInstance** - Running instance of a workflow
- **WorkflowEngine** - Execution engine for workflows
- Support for multiple workflow types (approval, review, testing, deployment, custom)
- Workflow state machine with configurable states
- Workflow versioning and history

#### 3.2 Workflow Step Types
- **ApprovalStep** - Requires approval from specified roles/users
- **ReviewStep** - Review and comment (non-blocking)
- **ActionStep** - Execute custom actions (e.g., run tests, deploy, notify)
- **ConditionStep** - Conditional branching based on context
- **ParallelStep** - Execute multiple steps in parallel
- **SequentialStep** - Execute steps in sequence
- **TimerStep** - Wait for specified duration or until deadline
- **CustomStep** - User-defined step types via plugins

#### 3.3 Workflow DSL Syntax
- **Declarative DSL** - Define workflows using Ruby DSL or JSON/YAML
- **Step configuration** - Configure each step with type, roles, conditions, actions
- **Flow control** - Support for branching, loops, parallel execution
- **Context variables** - Pass data between steps
- **Conditional execution** - Steps can be conditional based on context
- **Error handling** - Define error handling and retry strategies

#### 3.4 Workflow Execution
- **State machine** - Track workflow state (pending, in_progress, completed, failed, cancelled)
- **Step execution** - Execute steps based on workflow definition
- **Role-based access** - Integrate with existing RBAC system
- **Parallel execution** - Support for parallel step execution
- **Retry logic** - Configurable retry strategies for failed steps
- **Timeout handling** - Timeout and escalation for stuck workflows

#### 3.5 Workflow Context & Data
- **WorkflowContext** - Context data passed through workflow
- **Step results** - Store results from each step
- **Metadata** - Attach metadata to workflows (description, justification, attachments)
- **Search and filtering** - Query workflows by status, type, user, date range
- **Workflow history** - Complete audit trail of workflow execution

#### 3.6 Integration Points
- **Versioning integration** - Link workflows to rule versions
- **RBAC integration** - Use existing roles/permissions for step authorization
- **A/B testing integration** - Approve test configurations via workflows
- **Notification integration** - Notify users at workflow events
- **Audit logging** - All workflow events logged for compliance
- **Webhook support** - Trigger external systems on workflow events

#### 3.7 Notifications
- **NotificationService** - Unified notification system for workflow events
- **Email notifications** - SMTP integration for email alerts
- **Webhook notifications** - HTTP callbacks for external systems
- **In-app notifications** - Notification center in Web UI
- **Notification templates** - Customizable notification templates
- **Event subscriptions** - Subscribe to specific workflow events

**API Design:**

```ruby
# Define workflow using DSL
approval_workflow = DecisionAgent::Workflow::DSL.define do
  name "Production Rule Approval"
  description "Multi-step approval for production rule changes"
  
  step :review do
    type :review
    role :editor
    required true
    allow_comments true
  end
  
  step :approval do
    type :approval
    role :approver
    required true
    parallel false
    min_approvals 1
  end
  
  step :deploy do
    type :action
    role :admin
    required true
    action do |context|
      version_manager = DecisionAgent::Versioning::VersionManager.new
      version_manager.activate_version(context[:version_id])
    end
  end
  
  on_complete do |workflow|
    NotificationService.notify(
      user: workflow.created_by,
      message: "Workflow completed: #{workflow.name}"
    )
  end
end

# Create workflow template
template = DecisionAgent::Workflow::WorkflowTemplate.create(
  name: "Production Rule Approval",
  definition: approval_workflow.to_h
)

# Start workflow instance
workflow_instance = DecisionAgent::Workflow::WorkflowEngine.start(
  template: template,
  context: {
    rule_id: "loan_approval",
    version_id: new_version_id,
    description: "Lower approval threshold from 0.8 to 0.75",
    justification: "Increase approval rate by 5% based on A/B test results"
  },
  created_by: current_user
)

# Execute workflow step
workflow_instance.approve_step(
  step_id: :approval,
  approver: current_user,
  comment: "Looks good"
)

# Custom workflow example (testing workflow)
testing_workflow = DecisionAgent::Workflow::DSL.define do
  name "Rule Testing Workflow"
  
  step :run_tests do
    type :action
    action do |context|
      test_runner = DecisionAgent::Testing::BatchTestRunner.new
      test_runner.run(context[:test_scenarios])
    end
  end
  
  step :check_coverage do
    type :condition
    condition do |context|
      context[:test_coverage] >= 0.8
    end
    on_true :approve
    on_false :reject
  end
  
  step :approve do
    type :approval
    role :qa_lead
  end
end

# JSON/YAML workflow definition (alternative to DSL)
workflow_json = {
  "name": "Production Rule Approval",
  "steps": [
    {
      "id": "review",
      "type": "review",
      "role": "editor",
      "required": true
    },
    {
      "id": "approval",
      "type": "approval",
      "role": "approver",
      "required": true,
      "parallel": false,
      "min_approvals": 1
    },
    {
      "id": "deploy",
      "type": "action",
      "role": "admin",
      "action": {
        "type": "activate_version",
        "version_id": "{{context.version_id}}"
      }
    }
  ],
  "on_complete": {
    "notify": {
      "user": "{{workflow.created_by}}",
      "message": "Workflow completed"
    }
  }
}
```

**Estimated Effort:** 5-6 weeks (optional configurable feature)  
**Dependencies:** RBAC system (existing), optional email gem (mail)  
**Files to Create:**
- `lib/decision_agent/workflow/workflow_engine.rb` (loaded conditionally when enabled)
- `lib/decision_agent/workflow/workflow_template.rb`
- `lib/decision_agent/workflow/workflow_instance.rb`
- `lib/decision_agent/workflow/workflow_dsl.rb`
- `lib/decision_agent/workflow/steps/` (step type implementations)
  - `approval_step.rb`
  - `review_step.rb`
  - `action_step.rb`
  - `condition_step.rb`
  - `parallel_step.rb`
  - `sequential_step.rb`
  - `timer_step.rb`
  - `base_step.rb`
- `lib/decision_agent/workflow/storage/` (storage adapters)
  - `adapter.rb`
  - `file_storage_adapter.rb`
  - `activerecord_adapter.rb`
- `lib/decision_agent/workflow/notification_service.rb`
- `lib/decision_agent/workflow/errors.rb`
- `lib/decision_agent/web/public/workflows.html`
- `db/migrate/YYYYMMDDHHMMSS_create_workflow_tables.rb` (conditional migrations)
- `spec/workflow/` (comprehensive test suite)
- `docs/WORKFLOW_DSL.md` (workflow DSL guide)
- `docs/WORKFLOW_EXAMPLES.md` (workflow examples)

**Migration Strategy:**
- Migrations are included in the gem but only create tables when workflows are enabled
- Users run migrations when they decide to enable workflows: `rails db:migrate` or `rake db:migrate`
- Migrations check for `DECISION_AGENT_ENABLE_WORKFLOWS` or configuration flag
- If workflows are disabled, migrations are no-ops (safe to run)

**Alternative Approach:** If workflows are not enabled, applications can still implement workflows using:
- Version status (draft/active/archived) for workflow states
- RBAC for step permissions
- Audit logging for compliance
- External systems (Git PRs, CI/CD, workflow tools) for orchestration

---

### 4. Complete Mathematical Expressions 🔧 **MEDIUM PRIORITY**

**Goal:** Finish mathematical operator implementation to complete advanced operators feature.

**Current State:** Partial implementation - `between` and `modulo` operators exist, but advanced mathematical functions are missing.

**Business Value:**
- Enable complex financial calculations in rules
- Support scientific and engineering use cases
- Complete parity with FEEL mathematical functions
- Reduce need for custom evaluators

**Technical Requirements:**

#### 4.1 Additional Mathematical Operators
- Add basic trigonometric: `sin`, `cos`, `tan` (if not already present)
- Add inverse trigonometric: `asin`, `acos`, `atan`, `atan2`
- Add hyperbolic functions: `sinh`, `cosh`, `tanh`
- Add logarithmic variants: `log10`, `log2` (in addition to existing `log`)
- Add advanced math: `factorial`, `gcd`, `lcm`
- Add power and root functions: `power`, `sqrt`, `cbrt`
- Add rounding functions: `round`, `floor`, `ceil`, `truncate`

#### 4.2 Integration
- Add to `ConditionEvaluator` class
- Update schema validator
- Update Web UI dropdown
- Add comprehensive tests
- Update documentation

**Estimated Effort:** 1-2 weeks  
**Dependencies:** None (Ruby Math module)  
**Files to Modify:**
- `lib/decision_agent/dsl/condition_evaluator.rb`
- `lib/decision_agent/dsl/schema_validator.rb`
- `lib/decision_agent/web/public/index.html`
- `spec/advanced_operators_spec.rb`

---

## Implementation Timeline

### Sprint 1-2: Mathematical Expressions (Weeks 1-2)
**Goal:** Complete remaining mathematical operators  
**Deliverables:**
- ✅ All mathematical operators implemented
- ✅ Tests and documentation updated
- ✅ Web UI integration complete

**Success Criteria:**
- All operators pass tests
- Documentation updated
- Zero breaking changes

---

### Sprint 3-5: REST API Data Enrichment (Weeks 3-6) ✅ **COMPLETED**
**Goal:** Enable external data fetching in rules  
**Status:** ✅ **COMPLETED**  
**Deliverables:**
- ✅ DataEnrichmentClient with HTTP support (GET, POST, PUT, DELETE)
- ✅ Caching layer with MemoryAdapter (Redis adapter as future enhancement)
- ✅ Circuit breaker and retry logic
- ✅ DSL integration (`fetch_from_api` operator)
- ✅ Comprehensive test suite (config, cache, circuit breaker, client, operator integration)
- ✅ Full documentation (DATA_ENRICHMENT.md)
- ✅ Working example file (examples/data_enrichment_example.rb)
- ✅ Schema validator updated with `fetch_from_api` operator support

**Success Criteria:**
- ✅ Can fetch data from external APIs in rules
- ✅ Caching implemented with configurable TTL
- ✅ Circuit breaker prevents cascading failures
- ✅ All error cases handled gracefully
- ✅ Authentication support (API key, Basic, Bearer)
- ✅ Template parameter expansion for context values
- ✅ Complete test coverage including integration tests
- ✅ Example file demonstrating all features
- ✅ Schema validation for `fetch_from_api` operator

---

### Sprint 6-9: Simulation and What-If Analysis (Weeks 7-14) ✅ **COMPLETED**
**Goal:** Enable scenario testing, backtesting, shadow testing, and impact analysis  
**Status:** ✅ **COMPLETED** - All deliverables implemented and tested  
**Deliverables:**
- ✅ ScenarioEngine for scenario management
- ✅ ReplayEngine for historical replay / backtesting
- ✅ WhatIfAnalyzer for scenario simulation
- ✅ ImpactAnalyzer for change impact assessment
- ✅ ShadowTestEngine for production comparison without impact
- ✅ ScenarioLibrary for test scenario templates
- ✅ Comprehensive test suite (6 test files)
- ✅ Complete documentation (SIMULATION.md)
- ✅ Working example file (simulation_example.rb)

**Success Criteria:**
- ✅ Can replay 10k+ historical decisions in <5 minutes (backtesting) - Parallel execution supported
- ✅ What-if analysis supports 100+ scenarios - Parallel execution with configurable thread count
- ✅ Impact analysis provides actionable insights - Risk scoring and categorization implemented
- ✅ Shadow testing compares rules without affecting production - Zero-impact implementation
- ✅ Test scenario library with templates available - Pre-defined templates and edge case generation
- ✅ All simulation features have UI - Web UI integration completed
  - ✅ Simulation dashboard at `/simulation`
  - ✅ Historical replay UI with file upload support
  - ✅ What-if analysis UI with interactive scenario builder
  - ✅ Impact analysis UI with risk visualization
  - ✅ Shadow testing UI for production comparison
  - ✅ All API endpoints integrated in web server

---

### Sprint 10-11: Common Workflow DSL System (Weeks 15-20) - **OPTIONAL / CONFIGURABLE**
**Goal:** Enable flexible workflow DSL supporting any workflow type (approval, review, testing, deployment, custom) as an optional, configurable feature  
**Note:** This sprint is optional since the foundation (versioning + RBAC + audit) already exists. The workflow DSL system will be implemented as an **optional feature** that users can enable via environment variable (`DECISION_AGENT_ENABLE_WORKFLOWS=true`) and run migrations when needed. Users can enable it at any time, even after initial setup.

**Deliverables:**
- ✅ WorkflowDSL with declarative syntax (Ruby DSL and JSON/YAML support)
- ✅ WorkflowEngine with state machine
- ✅ Multiple step types (approval, review, action, condition, parallel, sequential, timer)
- ✅ WorkflowTemplate and WorkflowInstance management
- ✅ Notification system (email + webhooks)
- ✅ Web UI for workflow management
- ✅ Integration with RBAC and versioning
- ✅ Storage adapters (file and ActiveRecord)
- ✅ Comprehensive test suite
- ✅ Documentation and examples

**Success Criteria:**
- Can define workflows using DSL (Ruby or JSON/YAML)
- Supports multiple workflow types (not just approvals)
- Workflow execution with state machine
- Role-based step authorization
- Notifications sent for all workflow events
- Full audit trail for compliance
- Extensible for custom step types

**Alternative:** If skipping this sprint, document how applications can implement workflows using existing foundation (draft status + RBAC + audit logging).

---

## Technical Architecture

### New Modules Structure
```
lib/decision_agent/
├── data_enrichment/
│   ├── client.rb
│   ├── cache_adapter.rb
│   ├── circuit_breaker.rb
│   └── config.rb
├── simulation/
│   ├── scenario_engine.rb
│   ├── replay_engine.rb
│   ├── what_if_analyzer.rb
│   └── impact_analyzer.rb
└── workflow/  (conditionally loaded when DECISION_AGENT_ENABLE_WORKFLOWS=true)
    ├── workflow_engine.rb
    ├── workflow_template.rb
    ├── workflow_instance.rb
    ├── workflow_dsl.rb
    ├── notification_service.rb
    ├── errors.rb
    ├── steps/
    │   ├── base_step.rb
    │   ├── approval_step.rb
    │   ├── review_step.rb
    │   ├── action_step.rb
    │   ├── condition_step.rb
    │   ├── parallel_step.rb
    │   ├── sequential_step.rb
    │   └── timer_step.rb
    └── storage/
        ├── adapter.rb
        ├── file_storage_adapter.rb
        └── activerecord_adapter.rb
```

**Note:** The workflow module is conditionally loaded based on the `DECISION_AGENT_ENABLE_WORKFLOWS` environment variable or configuration setting. Code checks for feature flag before requiring workflow classes.

### Database Schema Additions

#### Data Enrichment Cache (Optional)
```ruby
create_table :data_enrichment_cache do |t|
  t.string :cache_key, null: false, index: { unique: true }
  t.text :response_data, null: false
  t.datetime :expires_at, null: false, index: true
  t.timestamps
end
```

#### Workflow Templates (Conditional - only created when workflows enabled)
```ruby
# Migration checks DECISION_AGENT_ENABLE_WORKFLOWS or config flag
if DecisionAgent.config.enable_workflows
  create_table :workflow_templates do |t|
    t.string :name, null: false
    t.text :description
    t.text :definition, null: false  # JSON workflow definition
    t.string :workflow_type, null: false, index: true  # approval, review, testing, deployment, custom
    t.boolean :active, default: true
    t.string :created_by, null: false
    t.timestamps
  end
end
```

#### Workflow Instances (Conditional - only created when workflows enabled)
```ruby
# Migration checks DECISION_AGENT_ENABLE_WORKFLOWS or config flag
if DecisionAgent.config.enable_workflows
  create_table :workflow_instances do |t|
    t.references :workflow_template, null: false, index: true
    t.string :rule_id, index: true
    t.string :version_id, index: true
    t.string :status, null: false, default: 'pending', index: true  # pending, in_progress, completed, failed, cancelled
    t.text :context  # JSON context data
    t.text :metadata  # JSON metadata (description, justification, etc.)
    t.string :current_step_id
    t.string :created_by, null: false
    t.datetime :started_at
    t.datetime :completed_at
    t.timestamps
  end
end
```

#### Workflow Steps (Conditional - only created when workflows enabled)
```ruby
# Migration checks DECISION_AGENT_ENABLE_WORKFLOWS or config flag
if DecisionAgent.config.enable_workflows
  create_table :workflow_steps do |t|
    t.references :workflow_instance, null: false, index: true
    t.string :step_id, null: false  # Step identifier from workflow definition
    t.string :step_type, null: false  # approval, review, action, condition, etc.
    t.string :status, null: false, default: 'pending', index: true  # pending, in_progress, completed, failed, skipped
    t.text :configuration  # JSON step configuration
    t.text :result  # JSON step result
    t.string :assigned_to  # User/role assigned to step
    t.text :comments
    t.datetime :started_at
    t.datetime :completed_at
    t.timestamps
  end
end
```

**Note:** These migrations are safe to run even if workflows are disabled - they will be no-ops. Users can enable workflows later and re-run migrations if needed.

---

## Testing Strategy

### Unit Tests
- **Target Coverage:** 90%+ for all new modules
- **Focus Areas:**
  - Data enrichment: HTTP client, caching, circuit breaker
  - Simulation: scenario execution, replay accuracy, impact calculation
  - Workflow: state machine, step execution, DSL parsing, notifications

### Integration Tests
- End-to-end data enrichment with mock HTTP server
- Simulation with real historical data
- Workflow execution with RBAC integration (approval, review, action steps)
- Web UI interactions for all new features

### Performance Tests
- Data enrichment: cache hit rates, API call reduction
- Simulation: 10k+ scenario execution time
- Workflow: concurrent approval processing

### Security Tests
- API key management and secret handling
- Workflow permission enforcement
- Audit trail completeness

---

## Documentation Requirements

### User Documentation
1. **Data Enrichment Guide** (`docs/DATA_ENRICHMENT.md`)
   - Configuration examples
   - API endpoint setup
   - Caching strategies
   - Error handling patterns

2. **Simulation Guide** (`docs/SIMULATION.md`)
   - Historical replay tutorial
   - What-if analysis examples
   - Impact analysis interpretation
   - Best practices

3. **Workflow DSL Guide** (`docs/WORKFLOW_DSL.md`)
   - Installation and configuration (environment variable setup)
   - Running migrations when enabling workflows
   - Workflow DSL syntax (Ruby DSL and JSON/YAML)
   - Creating workflows (approval, review, testing, deployment, custom)
   - Step types and configuration
   - Workflow execution and state management
   - Notification configuration
   - Integration with RBAC and versioning
   - Compliance use cases

4. **Workflow Examples** (`docs/WORKFLOW_EXAMPLES.md`)
   - Approval workflow examples
   - Review workflow examples
   - Testing workflow examples
   - Deployment workflow examples
   - Custom workflow examples
   - Best practices and patterns

### API Documentation
- Update `docs/API_CONTRACT.md` with new endpoints
- Add OpenAPI/Swagger specs for new APIs
- Code examples for all new features

### Migration Guide
- `docs/VERSION_0.4.0_MIGRATION.md`
- Breaking changes (if any)
- Configuration updates
- Database migration instructions (including conditional workflow migrations)
- Enabling optional features (workflows via environment variable)

---

## Risk Assessment

### Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Data enrichment API failures | High | Medium | Circuit breaker, caching, graceful degradation |
| Simulation performance at scale | Medium | Low | Parallel processing, optimization, benchmarking |
| Workflow complexity | Medium | Low | Optional configurable feature - enabled via env variable, can be deferred |
| Breaking changes | High | Low | Comprehensive testing, backward compatibility focus |
| Mathematical expressions edge cases | Low | Low | Comprehensive test coverage, handle edge cases (NaN, infinity) |

### Timeline Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Scope creep | High | Medium | Strict feature freeze after planning, workflow DSL optional |
| Resource availability | High | Low | Buffer time in estimates, prioritize core features |
| Integration complexity | Medium | Medium | Early integration testing |
| Workflow DSL scope | Medium | Low | Optional configurable feature - enabled via env variable, can be deferred or enabled later |

---

## Success Metrics

### Feature Completion
- ✅ All core features implemented and tested (mathematical expressions, data enrichment, simulation)
- ✅ Common workflow DSL implemented as optional configurable feature (enabled via env variable) OR documented foundation usage (if deferred)
- ✅ 90%+ test coverage for new code
- ✅ All documentation complete (including workflow installation/configuration guide)

### Performance Metrics
- Data enrichment: <100ms overhead per API call (with cache)
- Simulation: 10k scenarios in <5 minutes
- Workflow: Step processing <1 second per step

### Quality Metrics
- Zero critical bugs in production
- Backward compatibility maintained
- All existing tests passing

### Adoption Metrics
- Documentation views and engagement
- Feature usage in examples
- Community feedback

---

## Post-Release (v0.4.1 Considerations)

### Potential Follow-Up Features
1. **Advanced Simulation:**
   - Monte Carlo simulation
   - Sensitivity analysis visualization
   - Decision boundary plotting

2. **Enhanced Data Enrichment:**
   - GraphQL support
   - Database query integration
   - Message queue integration (Kafka, RabbitMQ)

3. **Workflow DSL Enhancements:**
   - Advanced branching and conditional logic
   - Workflow templates marketplace
   - Visual workflow designer
   - Workflow analytics and metrics

### Performance Optimizations
- Rule compilation for faster evaluation
- Advanced caching strategies
- Parallel rule evaluation

---

## Dependencies

### New Gem Dependencies
- `faraday` or `httparty` (HTTP client) - **Required** (for data enrichment)
- `redis` (optional, for caching) - **Optional**
- `mail` (optional, for email notifications) - **Optional** (only if approval workflows feature is enabled)

### Infrastructure Requirements
- Redis server (optional, for caching)
- SMTP server (optional, for email notifications)

---

## Release Checklist

### Pre-Release
- [ ] All features implemented and tested
- [ ] Documentation complete and reviewed
- [ ] Migration guide prepared
- [ ] Breaking changes documented
- [ ] Performance benchmarks completed
- [ ] Security audit completed

### Release
- [ ] Version number updated
- [ ] CHANGELOG.md updated
- [ ] Gem version bumped
- [ ] Release notes prepared
- [ ] GitHub release created
- [ ] RubyGems release published

### Post-Release
- [ ] Monitor error rates
- [ ] Collect user feedback
- [ ] Address critical issues
- [ ] Plan v0.4.1 hotfixes if needed

---

## Conclusion

Version 0.4.0 represents a **major milestone** in DecisionAgent's evolution, completing Phase 2 enterprise features and positioning the platform for broader enterprise adoption. With data enrichment, simulation, mathematical expressions, and optional approval workflows, DecisionAgent will have **competitive parity** with mid-market decision engines while maintaining its unique strengths: open source, Ruby-native, and developer-friendly.

**Note on Common Workflow DSL:** The foundation for workflows (versioning with draft/active/archived status + RBAC + audit logging) already exists. The common workflow DSL system will be implemented as an **optional, configurable feature** built into the main gem that users can enable whenever they need it:
- **Enable via environment variable:** `DECISION_AGENT_ENABLE_WORKFLOWS=true`
- **Run migrations when enabling:** `rails db:migrate` or `rake db:migrate` (migrations are conditional and safe to run)
- **Lazy loading:** Workflow code only loaded when feature is enabled
- **No breaking changes:** Feature is completely optional and can be enabled at any time
- **Flexible workflow support:** Supports any workflow type (approval, review, testing, deployment, custom), not just approvals

Users can also build custom workflows on top of the foundation, or integrate with external systems (Git PRs, CI/CD pipelines, workflow tools).

**Key Differentiators After v0.4.0:**
- ✅ Complete enterprise feature set (data enrichment, simulation, mathematical expressions)
- ✅ Open source with MIT license
- ✅ Ruby ecosystem integration
- ✅ Standards compliance (DMN 1.3)
- ✅ Production-ready performance (7,300-7,800+ decisions/second)
- ✅ Foundation for workflows (versioning + RBAC + audit) - applications can build on top, or use common workflow DSL

**Next Steps:**
1. Review and approve this plan
2. Decide on approval workflow implementation (optional vs. required)
3. Assign development resources
4. Begin Sprint 1 (Mathematical Expressions)
5. Weekly progress reviews
6. Adjust timeline as needed

**Recommended Approach:**
- **Priority 1:** Mathematical expressions, REST API data enrichment, simulation (10-14 weeks)
- **Priority 2:** Common workflow DSL (5-6 weeks) - **Optional configurable feature** that users can enable via environment variable and migrations when needed. Can be developed in parallel or after core features. Supports any workflow type (approval, review, testing, deployment, custom), not just approvals.

---

**Document Version:** 1.0  
**Last Updated:** January 2026  
**Author:** Development Team  
**Status:** Ready for Review

