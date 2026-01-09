DecisionAgent – Workflow System
VERSION 1.1.0 Plan

Status: Planned – Stable, Backward-Compatible Release

1. Goal

Introduce a Rails-native, decision-aware workflow system inside decision_agent that enables teams to define, execute, monitor, and control workflows via UI or API, while ensuring:

Strong separation of concerns

Auditability and compliance

Async-safe execution

Zero breaking changes

The workflow system supports approval, review, and automation workflows and is designed for long-term extensibility.

2. Design Principles

Engine-first, UI-controlled
The workflow engine is UI-agnostic but explicitly designed to be controlled from a UI.

Decision-driven workflows
Workflow logic delegates all business decisions to the existing decision engine.

Async by default
All workflow execution paths must be background-job safe.

Minimal, stable core
Version 1.1.0 ships a small, reliable core — not a bloated orchestration system.

Enterprise-ready
RBAC, audit trails, versioning, and separation of duties are first-class concerns.

3. Feature Enablement
Configuration

Enable workflows via configuration:

DecisionAgent.configure do |config|
  config.enable_workflows = true
end


Workflow code is lazy-loaded

No environment-variable-based migrations

Feature can be enabled at any time

4. Scope Control (Strict)
Included in Version 1.1.0
Area	Included
Workflow DSL	Yes
Workflow Templates	Yes
Workflow Instances	Yes
Sequential execution	Yes
Approval steps	Yes
Action steps	Yes
Condition steps	Yes
ActiveRecord storage	Yes
UI control APIs	Yes
Audit trail	Yes
Async execution	Yes
Explicitly Deferred (Post-1.1)

Parallel execution

Timers / SLA steps

Plugin-based step loading

Built-in UI components

Webhooks

Visual workflow designer

5. Core Architecture
Core Objects
Component	Responsibility
WorkflowDSL	Declarative workflow definition
WorkflowTemplate	Versioned, reusable workflow blueprint
WorkflowInstance	Runtime execution and state
WorkflowEngine	Orchestrates execution
BaseStep	Shared step behavior
WorkflowUI	UI-safe workflow operations
6. Workflow DSL
DSL Rules

Step type is implicit

DSL maps directly to step classes

Definitions are serializable and safe for UI usage

Example DSL
DecisionAgent::Workflow.define do
  name "Production Rule Approval"
  description "Approval workflow for production rule changes"

  review :review do
    role :editor
    required true
  end

  approval :approval do
    role :approver
    min_approvals 1
  end

  action :deploy do
    role :admin
    run do |context|
      DecisionAgent::Versioning.activate!(context[:version_id])
    end
  end

  on_complete do |workflow|
    DecisionAgent::Events.publish(
      :workflow_completed,
      workflow_id: workflow.id
    )
  end
end

7. Step Types (Version 1.1.0)
ApprovalStep

Requires explicit user approval

RBAC enforced

Supports comments

Supports minimum approvals

ActionStep

Executes Ruby logic or service objects

Always async-capable

Retry-safe and idempotent

ConditionStep

Branches workflow execution

Delegates evaluation to the decision engine

SequentialStep

Default execution strategy

Deterministic, ordered execution

8. Execution Model
Rule: No Synchronous Execution

All workflow execution must be async-capable.

DecisionAgent::Workflow::Engine.start_async(
  template: template,
  context: {...},
  created_by: user
)


Benefits

Retry support

Timeouts

Horizontal scaling

Thread safety

9. Workflow State Model

Workflow instance states:

pending → in_progress → completed
                     → failed
                     → cancelled


Step-level state stored as JSON

Schema intentionally flexible

10. Storage Strategy
Version 1.1.0

ActiveRecord-only implementation:

decision_agent_workflow_templates
decision_agent_workflow_instances
decision_agent_workflow_steps
decision_agent_workflow_events


Namespaced tables

Safe, always-on migrations

Adapter interface exists, but only one implementation ships

11. UI Control & Governance
UI Responsibilities

The workflow system is explicitly designed to be controlled from UI:

Start workflows

View workflow status

Approve or reject steps

Add comments

Cancel workflows

View audit history

UI-Safe API Layer
DecisionAgent::Workflow::UI.start_workflow(...)
DecisionAgent::Workflow::UI.approve_step(...)
DecisionAgent::Workflow::UI.reject_step(...)
DecisionAgent::Workflow::UI.cancel_workflow(...)

UI Rules

UI cannot bypass workflow rules

UI cannot mutate workflow state directly

All actions go through engine-validated APIs

All actions are fully audited

12. Audit & Compliance

Guaranteed capabilities:

Complete workflow execution history

Step-level actor attribution

Immutable event records

Timestamped transitions

Compliance-ready logs

Integrated with the existing audit logging system.

13. Notifications

Notifications are event-driven only.

DecisionAgent::Events.publish(:workflow_step_completed, payload)


Consumers may implement:

Email notifications

Webhooks

In-app notifications

The workflow engine never sends notifications directly.

14. Thread Safety & Concurrency

Guaranteed properties:

No global mutable state

Explicit context passing

Per-workflow execution locking

Idempotent step execution

Safe under multi-threaded servers

15. Error Handling & Recovery

Step-level failure tracking

Retry policies supported

Configurable fail-fast vs continue behavior

Clear error propagation to UI

16. Files to Add
lib/decision_agent/workflow/
  engine.rb
  workflow_template.rb
  workflow_instance.rb
  dsl.rb
  ui.rb
  steps/
    base_step.rb
    approval_step.rb
    action_step.rb
    condition_step.rb
    sequential_step.rb
  storage/
    adapter.rb
    activerecord_adapter.rb
  events.rb
  errors.rb

db/migrate/
  create_decision_agent_workflows.rb

docs/
  WORKFLOW_OVERVIEW.md
  WORKFLOW_DSL.md
  WORKFLOW_UI_GUIDE.md
  WORKFLOW_EXAMPLES.md

spec/workflow/

17. Versioning Strategy

Version 1.1.0 introduces workflows

Fully backward-compatible

Workflow definitions are immutable once activated

Future versions extend execution modes and UI capabilities

18. Success Criteria

UI can safely control workflows

Approvals work end-to-end

Async execution is reliable

Audit trail is complete

RBAC enforced everywhere

No impact on existing users

Ready for regulated environments

19. Post-1.1 Roadmap

Parallel steps

Timer & SLA steps

Visual workflow designer

Webhook triggers

Plugin step system

Graph-based workflow visualization

Final Note

The UI is a controller, not an authority.
The engine is the source of truth.

This balance makes DecisionAgent workflows safe, scalable, and enterprise-ready.
