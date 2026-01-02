# DMN Best Practices

Comprehensive guide to creating effective, maintainable DMN models in DecisionAgent.

## Table of Contents

1. [Modeling Best Practices](#modeling-best-practices)
2. [Decision Table Design](#decision-table-design)
3. [FEEL Expression Guidelines](#feel-expression-guidelines)
4. [Performance Optimization](#performance-optimization)
5. [Testing and Validation](#testing-and-validation)
6. [Governance and Maintenance](#governance-and-maintenance)
7. [Common Pitfalls](#common-pitfalls)
8. [Examples](#examples)

---

## Modeling Best Practices

### 1. Keep Models Focused

**DO**: Create separate models for distinct business domains
```ruby
# Good: Separate models
loan_approval_model = create_model("Loan Approval")
credit_assessment_model = create_model("Credit Assessment")
risk_scoring_model = create_model("Risk Scoring")
```

**DON'T**: Mix unrelated decisions in one model
```ruby
# Bad: Everything in one model
giant_model = create_model("All Business Rules")
# Contains: loans, credit, inventory, pricing, shipping...
```

### 2. Use Meaningful Names

**DO**: Use clear, business-friendly names
```ruby
decision = Decision.new(
  id: "customer_credit_approval",
  name: "Customer Credit Approval Decision"
)
```

**DON'T**: Use cryptic abbreviations
```ruby
decision = Decision.new(
  id: "cca_001",
  name: "CCA"
)
```

### 3. Document Your Decisions

**DO**: Add descriptions to decisions and rules
```ruby
decision.description = "Determines whether to approve customer credit based on score, income, and history"

rule.description = "High-value customers with excellent credit get auto-approval"
```

### 4. Model Decision Dependencies Explicitly

**DO**: Use information requirements
```ruby
final_decision.information_requirements << {
  decision_id: "credit_check",
  variable_name: "credit_result"
}

final_decision.information_requirements << {
  decision_id: "fraud_check",
  variable_name: "fraud_score"
}
```

---

## Decision Table Design

### Hit Policy Selection

| Hit Policy | Use When | Example |
|------------|----------|---------|
| **UNIQUE** | Exactly one rule should match | Tax brackets |
| **FIRST** | Multiple rules might match, want first | Priority-based routing |
| **PRIORITY** | Want highest priority match | Discount eligibility |
| **ANY** | Multiple rules match with same output | Validation rules |
| **COLLECT** | Want all matching results | Product recommendations |

### Table Structure

**DO**: Keep tables simple and focused
```
Decision Table: Loan Approval
Inputs: Credit Score, Income, Employment Status
Outputs: Decision
Rules: 5-10 rules

| Credit Score | Income   | Employment | Decision      |
|--------------|----------|------------|---------------|
| >= 750       | >= 50000 | employed   | auto_approve  |
| >= 700       | >= 75000 | employed   | approve       |
| < 600        | -        | -          | reject        |
| -            | -        | -          | manual_review |
```

**DON'T**: Create overly complex tables
```
Decision Table: Everything
Inputs: 15 different fields
Outputs: 8 different outputs
Rules: 200+ rules
# This should be multiple smaller tables!
```

### Rule Ordering

**DO**: Order rules from most specific to most general
```
| Credit | Income  | Decision      | Priority |
|--------|---------|---------------|----------|
| >= 800 | >= 100k | vip_approve   | 1 (most specific)
| >= 750 | >= 50k  | auto_approve  | 2
| >= 700 | -       | approve       | 3
| -      | -       | manual_review | 4 (catch-all)
```

### Use Wildcards Appropriately

**DO**: Use wildcards for "don't care" conditions
```
| Age   | Role  | Permission |
|-------|-------|------------|
| >= 18 | admin | full       |
| >= 18 | -     | limited    |  # Any role for adults
| -     | admin | full       |  # Any age for admins
```

**DON'T**: Overuse wildcards
```
| Age | Role | Permission |
|-----|------|------------|
| -   | -    | maybe      |  # Too vague!
```

### Handle Edge Cases

**DO**: Include boundary conditions and edge cases
```
| Amount | Decision      |
|--------|---------------|
| = 0    | reject        |  # Zero amount
| < 0    | reject        |  # Negative (invalid)
| [0..100] | auto_approve |
| > 100  | review        |
| -      | error         |  # Null/missing
```

---

## FEEL Expression Guidelines

### Keep Expressions Simple

**DO**: Use clear, simple expressions
```
>= 18
< 1000
in ["red", "green", "blue"]
[100..500]
```

**DON'T**: Create overly complex expressions
```
((age >= 18 and age <= 65) or (special_status = "exempt")) and (income > average_income * 1.5 or assets > 100000)
```

### Use Appropriate Data Types

**DO**: Match FEEL types to your data
```ruby
inputs << Input.new(
  id: "birth_date",
  type_ref: "date",  # Use proper date type
  label: "Birth Date"
)

# Then use date operations
"< date('2005-01-01')"  # Born before 2005
```

### Leverage Built-in Functions

**DO**: Use FEEL built-in functions
```
# String operations
contains("premium")
starts with("VIP")
matches("[A-Z]{3}-[0-9]{4}")

# List operations
in [1, 2, 3]
list contains("value")

# Numeric operations
between(100, 500)
abs(value) > 50
```

### Document Complex Expressions

**DO**: Add comments or descriptions
```ruby
rule.description = "Premium customers: Account age > 5 years AND (spend > $10k/year OR status = VIP)"
rule.input_entries = ["> 5", "> 10000 or status = 'VIP'"]
```

---

## Performance Optimization

### Use Caching

**DO**: Enable caching for frequently evaluated decisions
```ruby
# Enable caching
cached_evaluator = Dmn::CachedDmnEvaluator.new(
  dmn_model: model,
  decision_id: decision_id,
  enable_caching: true
)

# Warm up cache with common scenarios
cached_evaluator.warm_cache([
  { credit_score: 750, income: 60000 },
  { credit_score: 700, income: 50000 },
  { credit_score: 650, income: 40000 }
])
```

### Optimize Table Size

**DO**: Keep decision tables focused (10-20 rules max)
```ruby
# Break large tables into multiple smaller tables
instead of:
- 1 table with 100 rules

use:
- 5 tables with 20 rules each
- Link them with decision dependencies
```

### Order Rules Efficiently

**DO**: Put most common rules first (for FIRST hit policy)
```
# 80% of cases match first 2 rules
| Score  | Decision      | Frequency |
|--------|---------------|-----------|
| >= 750 | auto_approve  | 60%      |
| >= 700 | approve       | 20%      |
| >= 650 | review        | 15%      |
| < 650  | reject        | 5%       |
```

### Minimize FEEL Complexity

**DO**: Simplify expressions
```ruby
# Instead of
"(score >= 700 and score < 750) and (income >= 50000 and income < 75000)"

# Use ranges
"[700..750)" and "[50000..75000)"
```

---

## Testing and Validation

### Create Comprehensive Test Suites

**DO**: Test all rules and edge cases
```ruby
tester = Dmn::DmnTester.new(model)

# Test each rule
tester.add_scenario(
  decision_id: "approval",
  inputs: { score: 750, income: 60000 },
  expected_output: "approve",
  description: "Rule 1: High score, good income"
)

# Test boundaries
tester.add_scenario(
  decision_id: "approval",
  inputs: { score: 699, income: 60000 },  # Just below threshold
  expected_output: "review",
  description: "Boundary: Score just below approval"
)

# Test edge cases
tester.add_scenario(
  decision_id: "approval",
  inputs: { score: nil, income: 60000 },  # Missing data
  expected_output: "error",
  description: "Edge case: Missing score"
)

report = tester.run_all_tests
```

### Validate Models Regularly

**DO**: Run validation after every change
```ruby
validator = Dmn::Validator.new(model)

if validator.validate
  puts "✓ Model valid"
else
  puts "Errors:"
  validator.errors.each { |e| puts "  - #{e}" }
  puts "Warnings:"
  validator.warnings.each { |w| puts "  - #{w}" }
end
```

### Monitor Test Coverage

**DO**: Aim for 100% rule coverage
```ruby
coverage = tester.generate_coverage_report

puts "Coverage: #{coverage[:coverage_percentage]}%"
puts "Untested decisions: #{coverage[:untested_decisions]}"

coverage[:decision_coverage].each do |decision_id, cov|
  if cov[:rule_coverage]
    puts "#{decision_id}: #{cov[:rule_coverage][:coverage_percentage]}% rule coverage"
  end
end
```

---

## Governance and Maintenance

### Version Control

**DO**: Version all DMN models
```ruby
vmgr = Dmn::DmnVersionManager.new

# Save version before changes
vmgr.save_dmn_version(
  model: model,
  created_by: "john.doe",
  changelog: "Added new credit tier rules"
)

# Compare versions
diff = vmgr.compare_dmn_versions(
  version_id_1: "v1",
  version_id_2: "v2"
)
```

### Document Changes

**DO**: Maintain changelogs
```
Version 2.1 (2026-01-02):
- Added VIP customer fast-track rule
- Updated income thresholds for inflation
- Fixed edge case for zero-amount transactions

Version 2.0 (2025-12-15):
- Migrated from JSON to DMN format
- Restructured into 3 separate decision tables
```

### Establish Review Process

**DO**: Implement peer review
```ruby
# Workflow
1. Create/modify DMN model
2. Run validator
3. Run test suite
4. Submit for review
5. Get approval
6. Deploy new version
```

### Monitor Model Performance

**DO**: Track metrics
```ruby
# Log evaluation metrics
cache_stats = evaluator.cache_stats
puts "Cache hit rate: #{cache_stats[:result_hit_rate]}%"
puts "Avg evaluation time: #{stats[:avg_time]}ms"
```

---

## Common Pitfalls

### Pitfall 1: Overlapping Rules in UNIQUE Tables

**Problem**:
```
Hit Policy: UNIQUE
| Score  | Income | Decision |
|--------|--------|----------|
| >= 700 | >= 50k | approve  |
| >= 750 | >= 40k | approve  |  # Overlaps with rule 1!
```

**Solution**: Use FIRST or PRIORITY, or make rules mutually exclusive
```
Hit Policy: FIRST
| Score  | Income | Decision |
|--------|--------|----------|
| >= 750 | >= 40k | approve  |  # More specific first
| >= 700 | >= 50k | approve  |
```

### Pitfall 2: No Default Rule

**Problem**:
```
| Score  | Decision |
|--------|----------|
| >= 700 | approve  |
| < 600  | reject   |
# What about 600-699?
```

**Solution**: Always include catch-all
```
| Score  | Decision |
|--------|----------|
| >= 700 | approve  |
| < 600  | reject   |
| -      | review   |  # Catch-all
```

### Pitfall 3: Circular Dependencies

**Problem**:
```ruby
decision_a.information_requirements << { decision_id: "decision_b" }
decision_b.information_requirements << { decision_id: "decision_a" }
# Circular!
```

**Solution**: Restructure dependencies
```ruby
# Create intermediate decision
decision_a.information_requirements << { decision_id: "decision_c" }
decision_b.information_requirements << { decision_id: "decision_c" }
```

### Pitfall 4: Over-Engineering

**Problem**: Creating DMN for simple decisions

**Solution**: Use DMN for complex, changing business rules; keep simple logic in code

---

## Examples

### Example 1: Discount Eligibility

```ruby
model = Dmn::Model.new(
  id: "discount_model",
  name: "Customer Discount Eligibility"
)

decision = Dmn::Decision.new(
  id: "discount_decision",
  name: "Determine Discount Tier"
)

table = Dmn::DecisionTable.new(
  id: "discount_table",
  hit_policy: "FIRST"
)

# Inputs
table.inputs << Dmn::Input.new(id: "membership", label: "Membership Years", type_ref: "number")
table.inputs << Dmn::Input.new(id: "annual_spend", label: "Annual Spend", type_ref: "number")
table.inputs << Dmn::Input.new(id: "status", label: "Status", type_ref: "string")

# Output
table.outputs << Dmn::Output.new(id: "discount", label: "Discount %", type_ref: "number")

# Rules (ordered by priority)
add_rule(table, [">=10", ">=50000", '-'], ["25"])  # VIP: 10+ years, $50k+
add_rule(table, [">=5", ">=25000", '-'], ["15"])   # Gold: 5+ years, $25k+
add_rule(table, ['-', '-', '"premium"'], ["20"])   # Premium members
add_rule(table, [">=1", ">=10000", '-'], ["10"])   # Regular active
add_rule(table, ['-', '-', '-'], ["5"])            # New/basic: 5%

decision.instance_variable_set(:@decision_table, table)
model.add_decision(decision)
```

### Example 2: Risk Assessment with Dependencies

```ruby
# Decision 1: Calculate Risk Score
risk_score_decision = create_decision("risk_score_calculation")

# Decision 2: Determine Approval (depends on risk score)
approval_decision = create_decision("approval_determination")
approval_decision.information_requirements << {
  decision_id: "risk_score_calculation",
  variable_name: "risk_score"
}

# Use risk_score in approval rules
approval_table.rules << create_rule(
  inputs: ["< 30", '-'],  # risk_score < 30
  outputs: ["auto_approve"]
)
```

---

## Quick Reference Checklist

Before deploying a DMN model:

- [ ] All decisions have meaningful names and descriptions
- [ ] Hit policies are appropriate for each table
- [ ] Rules are ordered correctly
- [ ] All edge cases are handled
- [ ] Default/catch-all rules are present
- [ ] No circular dependencies
- [ ] Model passes validation
- [ ] Test coverage is >90%
- [ ] Performance is acceptable
- [ ] Version is saved
- [ ] Changes are documented
- [ ] Peer review completed

---

## Resources

- [DMN Guide](DMN_GUIDE.md) - Complete DMN usage guide
- [DMN API Reference](DMN_API.md) - API documentation
- [FEEL Reference](FEEL_REFERENCE.md) - FEEL language guide
- [Migration Guide](DMN_MIGRATION_GUIDE.md) - Migrating from JSON to DMN

---

**Document Version**: 1.0
**Last Updated**: January 2, 2026
**Status**: Production Ready
