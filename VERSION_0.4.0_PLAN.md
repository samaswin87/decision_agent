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

