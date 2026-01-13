# DecisionAgent API Contract Specification

This document formally defines the API contracts for the DecisionAgent library. All implementations MUST conform to these contracts to ensure determinism, reproducibility, and compliance requirements.

## Version

Contract Version: 1.1
Library Version: 0.4.0
Last Updated: 2026-01-14

---

## 1. Evaluator Interface Contract

### 1.1 Method Signature

```ruby
evaluate(context, feedback: {}) → DecisionAgent::Evaluation | nil
```

**Parameters:**
- `context` (required): `DecisionAgent::Context` or Hash - The decision context
- `feedback` (optional): Hash - Optional feedback data (default: `{}`)

**Returns:**
- `DecisionAgent::Evaluation` - When a decision can be made
- `nil` - When no decision can be made

### 1.2 Evaluation Object Contract

When returning an `Evaluation`, it MUST contain:

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| `decision` | String | ✓ | Non-empty | The decision value |
| `weight` | Float | ✓ | 0.0 ≤ weight ≤ 1.0 | Confidence weight |
| `reason` | String | ✓ | Any (can be empty) | Human-readable explanation |
| `evaluator_name` | String | ✓ | Non-empty | Name of the evaluator |
| `metadata` | Hash | ✓ | Any | Additional context (default: `{}`) |

### 1.3 Metadata Requirements

**For Rule-Based Evaluators:**
- MUST include `rule_id` field when a rule matches
- SHOULD include `ruleset` field to identify the ruleset
- MAY include additional fields like `type`, `version`, etc.

**Example:**
```ruby
{
  rule_id: "auto_approve_rule",
  ruleset: "approval_rules",
  type: "json_rule"
}
```

### 1.4 Weight Bounds Validation

**Valid Ranges:**
- Minimum: `0.0` (inclusive)
- Maximum: `1.0` (inclusive)

**Error Handling:**
- Values < 0.0 MUST raise `DecisionAgent::InvalidWeightError`
- Values > 1.0 MUST raise `DecisionAgent::InvalidWeightError`

### 1.5 Implementation Requirements

All evaluators MUST:
1. Inherit from `DecisionAgent::Evaluators::Base`
2. Implement the `evaluate(context, feedback: {})` method
3. Return `Evaluation` or `nil` (never raise errors for business logic)
4. Be stateless (same input → same output)
5. Set `evaluator_name` to identify the evaluator

---

## 2. Decision Object API Contract

### 2.1 Standard API

The `Decision` object exposes the following read-only attributes:

```ruby
result.decision          # String
result.confidence        # Float (0.0–1.0)
result.evaluations       # Array<Evaluation>
result.explanations      # Array<String>
result.audit_payload     # Hash (frozen)
result.because           # Array<String> - Conditions that led to decision
result.failed_conditions # Array<String> - Conditions that failed
result.explainability    # Hash - Machine-readable explainability data
```

### 2.2 Field Specifications

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `decision` | String | Non-empty | The final decision value |
| `confidence` | Float | 0.0 ≤ confidence ≤ 1.0 | Confidence score |
| `evaluations` | Array | Non-empty | All evaluations considered |
| `explanations` | Array<String> | Non-empty | Human-readable explanations |
| `audit_payload` | Hash | Frozen, complete | Full audit trail |
| `because` | Array<String> | Non-empty | Conditions that led to decision |
| `failed_conditions` | Array<String> | May be empty | Conditions that failed during evaluation |
| `explainability` | Hash | Frozen | Machine-readable explainability data |

### 2.3 Audit Payload Specification

The `audit_payload` is a **fully reproducible Hash** containing:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `timestamp` | String | ✓ | ISO 8601 timestamp (UTC) |
| `context` | Hash | ✓ | Original decision context |
| `feedback` | Hash | ✓ | Feedback data (may be empty) |
| `evaluations` | Array<Hash> | ✓ | All evaluation details |
| `decision` | String | ✓ | Final decision |
| `confidence` | Float | ✓ | Final confidence (0.0–1.0) |
| `scoring_strategy` | String | ✓ | Fully qualified class name |
| `agent_version` | String | ✓ | Library version |
| `deterministic_hash` | String | ✓ | SHA256 hash (64 hex chars) |

### 2.4 Timestamp Format

**Format:** ISO 8601 with microseconds
**Pattern:** `YYYY-MM-DDTHH:MM:SS.µµµµµµZ`
**Timezone:** UTC (denoted by `Z`)
**Example:** `2025-01-15T10:30:45.123456Z`

### 2.5 Deterministic Hash Generation

**Algorithm:** SHA256
**Input:** Canonical JSON of `{ context, evaluations, decision, confidence, scoring_strategy }`

**Properties:**
- MUST be deterministic (same input → same hash)
- MUST exclude `timestamp` (not deterministic)
- MUST exclude `feedback` (doesn't affect decision)
- MUST use canonical JSON (sorted keys, consistent formatting)

**Hash Format:** 64 hexadecimal characters (lowercase)

**Example:**
```ruby
"a3f2b9c8d1e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0"
```

### 2.6 Evaluation Hash Format

Each evaluation in `audit_payload[:evaluations]` contains:

```ruby
{
  decision: "approve",
  weight: 0.85,
  reason: "Rule matched successfully",
  evaluator_name: "JsonRuleEvaluator",
  metadata: { rule_id: "auto_approve", ruleset: "approvals" }
}
```

### 2.7 Decision#to_h Structure

The `Decision#to_h` method returns a hash with explainability as the primary structure:

```ruby
result.to_h
# => {
#   decision: "approve",
#   because: ["amount > 1000", "status = active"],
#   failed_conditions: ["credit_score < 700"],
#   confidence: 0.85,
#   explanations: ["High value transaction"],
#   evaluations: [...],
#   audit_payload: {...},
#   explainability: {
#     decision: "approve",
#     because: ["amount > 1000", "status = active"],
#     failed_conditions: ["credit_score < 700"]
#   }
# }
```

**Structure:**
- **Primary fields (explainability-first):**
  - `decision` (String) - The decision value
  - `because` (Array<String>) - Conditions that led to the decision
  - `failed_conditions` (Array<String>) - Conditions that failed
- **Additional metadata:**
  - `confidence` (Float) - Confidence score (0.0–1.0)
  - `explanations` (Array<String>) - Human-readable explanations
  - `evaluations` (Array<Hash>) - All evaluations considered
  - `audit_payload` (Hash) - Complete audit trail
  - `explainability` (Hash) - Full explainability data structure

**Note:** This structure ensures explainability is the primary format for decision results, making it easy to understand why decisions were made while maintaining backward compatibility with existing attributes.

### 2.8 Confidence Bounds Validation

**Valid Range:** 0.0 ≤ confidence ≤ 1.0

**Error Handling:**
- Values < 0.0 MUST raise `DecisionAgent::InvalidConfidenceError`
- Values > 1.0 MUST raise `DecisionAgent::InvalidConfidenceError`

---

## 3. Scoring Strategy Contracts

### 3.1 WeightedAverage

**Algorithm:**
```
confidence = sum(weights for winning decision) / sum(all weights)
```

**Behavior:**
- Sums weights for each decision
- Selects decision with highest total weight
- Normalizes confidence relative to all evaluations

**Example:**
- Evaluation 1: `approve`, weight 0.8
- Evaluation 2: `approve`, weight 0.7
- Total weight: 1.5
- Winning weight: 1.5
- **Confidence: 1.5 / 1.5 = 1.0** (100% agreement)

### 3.2 MaxWeight

**Algorithm:**
```
confidence = max(weight) among all evaluations for winning decision
```

**Behavior:**
- Selects decision with highest individual weight
- Confidence equals that weight (no normalization)

### 3.3 Consensus

**Algorithm:**
```
agreement_ratio = count(evaluators agreeing) / total_evaluators
confidence = agreement_ratio if agreement_ratio >= minimum_agreement else 0.0
```

**Parameters:**
- `minimum_agreement`: Float (0.0–1.0)

**Behavior:**
- Requires minimum agreement threshold
- Returns 0.0 confidence if threshold not met

### 3.4 Threshold

**Algorithm:**
```
if winning_weight >= threshold:
  return winning_decision with confidence = winning_weight
else:
  return fallback_decision with confidence = winning_weight * 0.5
```

**Parameters:**
- `threshold`: Float (0.0–1.0)
- `fallback_decision`: String

**Fallback Behavior:**
- When no evaluation meets threshold, returns `fallback_decision`
- Confidence is **reduced by 50%** (not 0.0)
- This indicates "some confidence but below threshold"

**Example:**
```ruby
# Evaluation weight: 0.5, Threshold: 0.8
# Result: fallback_decision with confidence 0.25 (0.5 * 0.5)
```

---

## 4. Replay Behavior Contract

### 4.1 Replay Method Signature

```ruby
DecisionAgent::Replay.run(audit_payload, strict: true) → Decision
```

**Parameters:**
- `audit_payload` (required): Hash - Complete audit payload
- `strict` (optional): Boolean - Strict mode flag (default: `true`)

### 4.2 Strict Mode Behavior

**When `strict: true`:**
- MUST raise `ReplayMismatchError` if decision differs
- MUST raise `ReplayMismatchError` if confidence differs (tolerance: 0.0001)
- MUST validate exact reproducibility

**Error Details:**
```ruby
DecisionAgent::ReplayMismatchError
  .expected    # Hash with original values
  .actual      # Hash with replayed values
  .differences # Array of difference descriptions
```

### 4.3 Non-Strict Mode Behavior

**When `strict: false`:**
- MUST NOT raise errors for mismatches
- MUST log differences to stderr via `warn`
- MUST return replayed result even if different

**Log Format:**
```
[DecisionAgent::Replay] Non-strict mode differences detected:
  - Decision changed: reject -> approve
  - Confidence changed: 0.75 -> 0.82
```

### 4.4 Required Payload Fields

The following fields MUST be present in the audit payload:

- `context` (or `"context"`)
- `evaluations` (or `"evaluations"`)
- `decision` (or `"decision"`)
- `confidence` (or `"confidence"`)

**Error:** Missing required field raises `InvalidRuleDslError`

### 4.5 Key Flexibility

Replay MUST accept both symbol and string keys:

```ruby
# Both are valid:
{ context: {...}, decision: "approve" }
{ "context" => {...}, "decision" => "approve" }
```

### 4.6 Metadata Preservation

Replay MUST preserve original metadata:

**Original evaluation metadata:**
```ruby
{ rule_id: "auto_approve", custom: "value" }
```

**Replayed evaluation metadata:**
```ruby
{ rule_id: "auto_approve", custom: "value" }  # Exact match
```

### 4.7 Missing Evaluator Handling

**Behavior:**
- Replay MUST work even if original evaluator class no longer exists
- Uses `StaticEvaluator` to reconstruct evaluations from audit payload
- Preserves `evaluator_name` from original evaluation

**Example:**
```ruby
# Original evaluator: "DeletedCustomEvaluator" (no longer exists)
# Replay creates: StaticEvaluator with name "DeletedCustomEvaluator"
# Result: Successful replay with preserved evaluator name
```

### 4.8 Scoring Strategy Evolution

**Unknown Strategy Handling:**
- If scoring strategy class not found, falls back to `WeightedAverage`
- Logs warning in non-strict mode
- May cause mismatch in strict mode

### 4.9 Deterministic Hash Verification

**Invariant:**
```ruby
replayed_result.audit_payload[:deterministic_hash] ==
  original_result.audit_payload[:deterministic_hash]
```

This MUST hold when context, evaluations, decision, and confidence match.

---

## 5. Error Handling Contract

### 5.1 Error Hierarchy

```
DecisionAgent::Error (StandardError)
  ├─ InvalidRuleDslError
  ├─ NoEvaluationsError
  ├─ ReplayMismatchError
  ├─ InvalidConfigurationError
  ├─ InvalidEvaluatorError
  ├─ InvalidScoringStrategyError
  ├─ InvalidAuditAdapterError
  ├─ InvalidConfidenceError
  └─ InvalidWeightError
```

### 5.2 Error Specifications

| Error | When Raised | Attributes |
|-------|-------------|------------|
| `InvalidWeightError` | Weight < 0.0 or > 1.0 | - |
| `InvalidConfidenceError` | Confidence < 0.0 or > 1.0 | - |
| `NoEvaluationsError` | No evaluator returned a decision | - |
| `ReplayMismatchError` | Replay doesn't match in strict mode | `expected`, `actual`, `differences` |
| `InvalidRuleDslError` | Malformed rules or missing payload fields | - |

### 5.3 Error Messages

**Format:** Clear, actionable messages

**Examples:**
```ruby
"Weight must be between 0.0 and 1.0, got: 1.5"
"Confidence must be between 0.0 and 1.0, got: -0.1"
"Audit payload missing required key: context"
"Replay mismatch detected: decision mismatch (expected: approve, got: reject)"
```

---

## 6. Immutability Contract

### 6.1 Frozen Objects

The following objects MUST be frozen (immutable):

- `Decision#audit_payload`
- `Evaluation` fields (decision, reason, evaluator_name, metadata)
- `Context#data`

### 6.2 Deep Freezing

Nested structures MUST be deeply frozen:

```ruby
metadata = { user: { role: "admin" }, tags: ["urgent"] }
# After freezing:
metadata.frozen?           # true
metadata[:user].frozen?    # true
metadata[:tags].frozen?    # true
```

### 6.3 Determinism Requirements

**Evaluators MUST:**
- Be stateless
- Return same output for same input
- Not depend on external state (time, random, I/O)
- Not modify input context

---

## 7. Testing Requirements

### 7.1 Contract Verification

All implementations MUST pass the contract tests in:
- `spec/api_contract_spec.rb`
- `spec/replay_edge_cases_spec.rb`

### 7.2 Minimum Coverage

- Evaluator interface: 100%
- Decision object: 100%
- Replay functionality: 100%
- Error handling: 100%

---

## 8. Versioning and Compatibility

### 8.1 Semantic Versioning

Contract follows [Semantic Versioning 2.0.0](https://semver.org/):

- **MAJOR**: Breaking contract changes
- **MINOR**: Backward-compatible additions
- **PATCH**: Clarifications, bug fixes

### 8.2 Backward Compatibility

**Breaking Changes (Major Version):**
- Changing field types or constraints
- Removing required fields
- Changing method signatures
- Modifying deterministic hash algorithm

**Non-Breaking Changes (Minor Version):**
- Adding optional fields
- Adding new error types
- Extending metadata schemas
- New evaluator types

### 8.3 Audit Payload Compatibility

Replay MUST support audit payloads from:
- Same major version
- Previous minor versions within same major version

**Example:**
- Version 1.5.0 MUST replay payloads from 1.0.0, 1.4.0
- Version 2.0.0 MAY NOT replay payloads from 1.x.x

---

## 9. Compliance and Audit Requirements

### 9.1 Regulatory Compliance

This contract supports compliance with:
- HIPAA (healthcare)
- SOX (financial)
- GDPR (data protection)
- 21 CFR Part 11 (FDA electronic records)

### 9.2 Audit Trail Requirements

**Every decision MUST:**
- Be reproducible from audit payload
- Include complete context
- Preserve all evaluation details
- Generate deterministic hash
- Record timestamp (for ordering)

### 9.3 Explainability Requirements

**Every decision MUST:**
- Include human-readable explanations
- Show which evaluators contributed
- Explain conflict resolution
- Preserve reasoning chains
- Provide machine-readable explainability data via `explainability` attribute
- Track conditions that led to the decision via `because` attribute
- Track conditions that failed via `failed_conditions` attribute
- Include condition-level traces with actual/expected values
- Support both short and verbose explanation modes

**Explainability Data Structure:**
```ruby
{
  decision: "approved",
  because: ["risk_score < 0.7", "account_age > 180"],
  failed_conditions: ["credit_hold = true"],
  rule_traces: [...] # In verbose mode
}
```

---

## 10. Implementation Checklist

When implementing a new evaluator:

- [ ] Inherits from `DecisionAgent::Evaluators::Base`
- [ ] Implements `evaluate(context, feedback: {})`
- [ ] Returns `Evaluation` or `nil`
- [ ] Validates weight bounds (0.0–1.0)
- [ ] Sets `evaluator_name` appropriately
- [ ] Includes metadata (especially `rule_id` for rules)
- [ ] Is stateless and deterministic
- [ ] Passes contract tests

When implementing a new scoring strategy:

- [ ] Inherits from `DecisionAgent::Scoring::Base`
- [ ] Implements `score(evaluations)`
- [ ] Returns `{ decision:, confidence: }`
- [ ] Validates confidence bounds (0.0–1.0)
- [ ] Documents algorithm clearly
- [ ] Handles edge cases (empty evaluations, ties)
- [ ] Passes contract tests

---


## Appendix A: Complete Example

```ruby
# 1. Define evaluator
evaluator = DecisionAgent::Evaluators::StaticEvaluator.new(
  decision: "approve",
  weight: 0.85,
  reason: "User meets criteria"
)

# 2. Create agent
agent = DecisionAgent::Agent.new(
  evaluators: [evaluator],
  scoring_strategy: DecisionAgent::Scoring::WeightedAverage.new,
  audit_adapter: DecisionAgent::Audit::LoggerAdapter.new
)

# 3. Make decision
result = agent.decide(context: { user: "alice" })

# 4. Inspect result
result.decision                           # "approve"
result.confidence                         # 1.0
result.explanations                       # ["Decision: approve...", ...]
result.audit_payload[:deterministic_hash] # "a3f2b9c..."

# 5. Replay decision
replayed = DecisionAgent::Replay.run(result.audit_payload, strict: true)

# 6. Verify replay
replayed.decision == result.decision           # true
replayed.confidence == result.confidence       # true
replayed.audit_payload[:deterministic_hash] ==
  result.audit_payload[:deterministic_hash]    # true
```

---

## Appendix B: Contract Changes

### Version 1.1.0 (2026-01-14)
- Removed Data Enrichment API contract (architectural decision - applications should handle data fetching)

### Version 1.0.0 (2025-01-17)
- Initial contract specification
- Formalized evaluator interface
- Defined decision object API
- Specified replay behavior
- Documented threshold strategy fallback
- Added metadata preservation requirements
