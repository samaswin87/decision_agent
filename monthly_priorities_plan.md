# Monthly Priorities Plan

**Month:** Current Month  
**Focus:** Critical Foundation Features for Enterprise Adoption  
**Status:** In Progress

---

## Executive Summary

This plan focuses on completing the remaining **Phase 1: Foundation** features that are critical blockers for enterprise adoption. With versioning, A/B testing, and monitoring already completed, the focus this month is on **Batch Testing** and **Role-Based Access Control (RBAC)**.

**Total Estimated Effort:** 5-7 weeks (1.25-1.75 months)  
**This Month Target:** Complete Batch Testing + Begin RBAC implementation

---

## Priority 1: Batch Testing Capabilities ⚡

**Status:** 🔴 Not Started  
**Priority:** Critical - Blocker for Enterprise Adoption  
**Estimated Effort:** 2-3 weeks  
**Target Completion:** End of Week 3

### Business Impact
Without batch testing, teams cannot validate rule changes against large datasets before deployment. This is essential for:
- Regulatory compliance validation
- Risk mitigation before production changes
- Performance testing at scale
- Quality assurance workflows

### Requirements

#### 1.1 CSV/Excel Import for Test Scenarios
- **Accept CSV/Excel files** with test case data
- **Parse and validate** input format
- **Support multiple context fields** (columns map to context attributes)
- **Handle large files** (10k+ rows efficiently)
- **Error handling** for malformed data

**User Story:**
> As a QA engineer, I want to import 10,000 test scenarios from a CSV file to validate rule changes before deployment.

**Technical Tasks:**
- [ ] Create `BatchTestImporter` class
- [ ] Add CSV parsing (using `csv` gem)
- [ ] Add Excel parsing (using `roo` or `rubyXL` gem)
- [ ] Implement data validation and error reporting
- [ ] Add progress tracking for large imports
- [ ] Write unit tests

**Files to Create/Modify:**
- `lib/decision_agent/testing/batch_test_importer.rb` (new)
- `lib/decision_agent/testing/batch_test_runner.rb` (new)
- `lib/decision_agent/testing/test_scenario.rb` (new)
- `spec/testing/batch_test_importer_spec.rb` (new)
- `spec/testing/batch_test_runner_spec.rb` (new)

#### 1.2 Batch Test Execution Engine
- **Execute rules** against all test scenarios
- **Track results** (decision, confidence, execution time)
- **Support parallel execution** for performance
- **Progress reporting** during execution
- **Resume capability** for interrupted tests

**User Story:**
> As a developer, I want to run 10,000 test scenarios and see progress in real-time, with results available in under 60 seconds.

**Technical Tasks:**
- [ ] Create `BatchTestRunner` class
- [ ] Implement parallel execution (using threads or async)
- [ ] Add progress callback mechanism
- [ ] Implement result aggregation
- [ ] Add performance metrics (throughput, latency)
- [ ] Write unit and integration tests

#### 1.3 Expected vs Actual Comparison
- **Compare expected results** with actual decisions
- **Generate diff reports** showing mismatches
- **Calculate accuracy metrics** (match rate, confidence delta)
- **Export comparison reports** (CSV, JSON)
- **Visualize differences** in web UI

**User Story:**
> As a business analyst, I want to see which test cases failed and why, so I can fix rule issues before deployment.

**Technical Tasks:**
- [ ] Create `TestResultComparator` class
- [ ] Implement comparison logic (exact match, fuzzy match, confidence threshold)
- [ ] Generate detailed diff reports
- [ ] Add accuracy metrics calculation
- [ ] Create report export functionality
- [ ] Add web UI endpoint for viewing results
- [ ] Write tests

#### 1.4 Test Coverage Reporting
- **Track which rules** are exercised by test scenarios
- **Identify untested rules** or rule paths
- **Calculate coverage percentage**
- **Generate coverage reports**
- **Highlight gaps** in test coverage

**User Story:**
> As a QA manager, I want to see test coverage metrics to ensure all critical rules are tested before deployment.

**Technical Tasks:**
- [ ] Create `TestCoverageAnalyzer` class
- [ ] Track rule execution during batch tests
- [ ] Calculate coverage metrics (rule-level, condition-level)
- [ ] Generate coverage reports
- [ ] Add web UI visualization
- [ ] Write tests

### API Design

```ruby
# Batch Testing API
importer = DecisionAgent::Testing::BatchTestImporter.new
scenarios = importer.import_csv('test_cases.csv')

runner = DecisionAgent::Testing::BatchTestRunner.new(agent)
results = runner.run(scenarios, parallel: true, progress_callback: ->(progress) { ... })

comparator = DecisionAgent::Testing::TestResultComparator.new
comparison = comparator.compare(results, expected_results)
comparison.accuracy_rate # => 0.95
comparison.mismatches # => Array of failed test cases

coverage = DecisionAgent::Testing::TestCoverageAnalyzer.new
report = coverage.analyze(results)
report.coverage_percentage # => 0.87
report.untested_rules # => Array of rules not covered
```

### Web UI Integration

- **New endpoint:** `POST /api/testing/batch/import` - Upload CSV/Excel
- **New endpoint:** `POST /api/testing/batch/run` - Execute batch test
- **New endpoint:** `GET /api/testing/batch/:id/results` - Get results
- **New endpoint:** `GET /api/testing/batch/:id/coverage` - Get coverage report
- **New page:** `/testing/batch` - Batch testing interface

### Success Criteria

- ✅ Import 10,000+ test scenarios from CSV in <30 seconds
- ✅ Execute 10,000 test scenarios in <60 seconds
- ✅ Generate comparison reports with accuracy metrics
- ✅ Calculate and display test coverage percentage
- ✅ All tests pass with >90% code coverage

### Dependencies

- `csv` gem (Ruby standard library)
- `roo` gem for Excel support (optional)
- Existing `DecisionAgent::Agent` for rule evaluation

---

## Priority 2: Role-Based Access Control (RBAC) 🔐

**Status:** 🔴 Not Started  
**Priority:** Critical - Blocker for Enterprise Adoption  
**Estimated Effort:** 3-4 weeks  
**Target Completion:** End of Week 4 (beginning this month, completing next)

### Business Impact
Without RBAC, organizations cannot enforce:
- Separation of duties (compliance requirement)
- Multi-person approval workflows
- Audit trails for access control
- Regulatory compliance (SOX, HIPAA, GDPR)

### Requirements

#### 2.1 User Authentication System
- **User model** with authentication
- **Session management** (JWT or session-based)
- **Password hashing** (bcrypt)
- **Login/logout endpoints**
- **Password reset** functionality

**User Story:**
> As a system administrator, I want users to authenticate before accessing rule management features.

**Technical Tasks:**
- [ ] Create `User` model (ActiveRecord or in-memory)
- [ ] Implement authentication middleware
- [ ] Add login/logout API endpoints
- [ ] Implement password hashing (bcrypt)
- [ ] Add session management
- [ ] Write authentication tests

**Files to Create/Modify:**
- `lib/decision_agent/auth/user.rb` (new)
- `lib/decision_agent/auth/authenticator.rb` (new)
- `lib/decision_agent/auth/session_manager.rb` (new)
- `lib/decision_agent/web/middleware/auth_middleware.rb` (new)
- `spec/auth/user_spec.rb` (new)
- `spec/auth/authenticator_spec.rb` (new)

#### 2.2 Role and Permission Management
- **Role definitions** (admin, editor, viewer, auditor)
- **Permission system** (read, write, delete, approve, deploy)
- **Resource-level permissions** (rule-level, version-level)
- **Role assignment** to users
- **Permission checking** middleware

**User Story:**
> As a compliance officer, I want to assign "viewer" role to auditors so they can see rules but not modify them.

**Technical Tasks:**
- [ ] Create `Role` model
- [ ] Create `Permission` model
- [ ] Implement role-permission mapping
- [ ] Add user-role assignment
- [ ] Create permission checker
- [ ] Add permission checks to API endpoints
- [ ] Write tests

**Files to Create/Modify:**
- `lib/decision_agent/auth/role.rb` (new)
- `lib/decision_agent/auth/permission.rb` (new)
- `lib/decision_agent/auth/permission_checker.rb` (new)
- `lib/decision_agent/web/middleware/permission_middleware.rb` (new)
- `spec/auth/role_spec.rb` (new)
- `spec/auth/permission_spec.rb` (new)

#### 2.3 Audit Logging for Access
- **Log all access attempts** (successful and failed)
- **Track permission checks** (who tried to access what)
- **Log authentication events** (login, logout, password reset)
- **Store audit logs** in database or file
- **Query and search** audit logs

**User Story:**
> As a security officer, I want to see who accessed which rules and when, for compliance auditing.

**Technical Tasks:**
- [ ] Extend existing audit adapter for access logging
- [ ] Create `AccessAuditLogger` class
- [ ] Log authentication events
- [ ] Log permission checks
- [ ] Add audit log query API
- [ ] Write tests

**Files to Create/Modify:**
- `lib/decision_agent/auth/access_audit_logger.rb` (new)
- `lib/decision_agent/audit/access_adapter.rb` (new)
- `spec/auth/access_audit_logger_spec.rb` (new)

### API Design

```ruby
# Authentication API
authenticator = DecisionAgent::Auth::Authenticator.new
session = authenticator.login('user@example.com', 'password')
authenticator.logout(session.token)

# Permission API
checker = DecisionAgent::Auth::PermissionChecker.new
checker.can?(user, :write, rule) # => true/false
checker.can?(user, :approve, version) # => true/false

# Role Management API
user.assign_role(:editor)
user.has_permission?(:write) # => true
user.has_permission?(:approve) # => false
```

### Web UI Integration

- **New endpoint:** `POST /api/auth/login` - User login
- **New endpoint:** `POST /api/auth/logout` - User logout
- **New endpoint:** `GET /api/auth/me` - Current user info
- **New endpoint:** `GET /api/auth/roles` - List roles
- **New endpoint:** `POST /api/auth/users/:id/roles` - Assign role
- **New endpoint:** `GET /api/auth/audit` - Query access audit logs
- **New page:** `/auth/login` - Login page
- **New page:** `/auth/users` - User management (admin only)

### Default Roles

1. **Admin** - Full access (read, write, delete, approve, deploy, manage users)
2. **Editor** - Can create and modify rules (read, write)
3. **Viewer** - Read-only access (read)
4. **Auditor** - Read access + audit log access (read, audit)
5. **Approver** - Can approve rule changes (read, approve)

### Success Criteria

- ✅ Users must authenticate before accessing rule management
- ✅ Role-based permissions enforced on all API endpoints
- ✅ All access attempts logged to audit trail
- ✅ Permission checks complete in <10ms
- ✅ All tests pass with >90% code coverage

### Dependencies

- `bcrypt` gem for password hashing
- Existing audit adapter system
- Existing web server (Sinatra)

---

## Implementation Timeline

### Week 1: Batch Testing Foundation
- **Days 1-2:** CSV/Excel import implementation
- **Days 3-4:** Batch test execution engine
- **Day 5:** Testing and bug fixes

### Week 2: Batch Testing Completion
- **Days 1-2:** Expected vs actual comparison
- **Days 3-4:** Test coverage reporting
- **Day 5:** Web UI integration and testing

### Week 3: Batch Testing Polish
- **Days 1-2:** Performance optimization
- **Days 3-4:** Documentation and examples
- **Day 5:** Final testing and code review

### Week 4: RBAC Foundation
- **Days 1-2:** User authentication system
- **Days 3-4:** Role and permission management
- **Day 5:** Initial testing and integration

---

## Risk Mitigation

### Technical Risks

1. **Performance Issues with Large Batch Tests**
   - **Mitigation:** Implement parallel execution, add progress tracking, optimize early
   - **Fallback:** Add batch size limits, streaming processing

2. **RBAC Complexity**
   - **Mitigation:** Start with simple role model, iterate
   - **Fallback:** Use file-based user storage initially, upgrade to DB later

3. **Integration with Existing Code**
   - **Mitigation:** Use existing patterns (adapters, middleware)
   - **Fallback:** Create wrapper classes to minimize changes

### Timeline Risks

1. **Scope Creep**
   - **Mitigation:** Strict focus on MVP features only
   - **Fallback:** Defer nice-to-have features to next month

2. **Unexpected Complexity**
   - **Mitigation:** Daily standups, early prototyping
   - **Fallback:** Reduce scope, focus on core functionality

---

## Success Metrics

### Batch Testing
- ✅ 10,000+ test scenarios processed in <60 seconds
- ✅ 95%+ test accuracy on known good rules
- ✅ Coverage analysis identifies untested rules
- ✅ Zero data loss during import/export

### RBAC
- ✅ All API endpoints protected with authentication
- ✅ Permission checks enforced on all write operations
- ✅ 100% of access attempts logged
- ✅ Login completes in <500ms

---

## Next Month Preview

After completing this month's priorities, next month will focus on:
- Completing RBAC implementation (if not finished)
- Beginning **Approval Workflow System** (Phase 2)
- Starting **REST API for Data Enrichment** (Phase 2)
- Completing **Mathematical Expressions** operators (1-2 weeks)

---

## Notes

- All code should follow existing patterns and conventions
- Maintain backward compatibility where possible
- Add comprehensive test coverage (>90%)
- Update documentation and examples
- Consider performance implications early
- Get code review before merging

