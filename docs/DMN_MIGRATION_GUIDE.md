# DMN Migration Guide

Complete guide for migrating from JSON rules to DMN format in DecisionAgent.

## Table of Contents

1. [Why Migrate to DMN?](#why-migrate-to-dmn)
2. [Migration Strategies](#migration-strategies)
3. [Step-by-Step Migration](#step-by-step-migration)
4. [JSON to DMN Mapping](#json-to-dmn-mapping)
5. [Common Migration Patterns](#common-migration-patterns)
6. [Testing Your Migration](#testing-your-migration)
7. [Rollback Strategy](#rollback-strategy)
8. [Troubleshooting](#troubleshooting)

---

## Why Migrate to DMN?

### Benefits of DMN

- **Industry Standard**: DMN is an OMG standard supported by major vendors
- **Portability**: Share decision models with other DMN-compliant tools
- **Visual Modeling**: Use graphical decision tables and diagrams
- **Better Tooling**: Access to enterprise DMN editors and validators
- **Improved Governance**: Better audit trails and version control
- **Standards Compliance**: Meet regulatory and compliance requirements

### When to Migrate

Migrate to DMN when you:
- Need to integrate with enterprise DMN tools (Drools, Camunda, IBM ODM)
- Require visual decision modeling capabilities
- Have complex decision logic that benefits from standardization
- Need to share models with business analysts
- Want better decision governance and audit trails

### When NOT to Migrate

Stay with JSON rules when:
- You have simple, straightforward decision logic
- You don't need interoperability with other tools
- Your team is comfortable with JSON format
- Performance is critical and you want minimal overhead

---

## Migration Strategies

### 1. Big Bang Migration

Convert all rules at once.

**Pros**:
- Clean break, no dual maintenance
- Immediate access to DMN benefits

**Cons**:
- Higher risk
- Requires extensive testing
- Longer deployment window

### 2. Incremental Migration

Migrate rules gradually, model by model.

**Pros**:
- Lower risk
- Easier to test and validate
- Can learn and improve as you go

**Cons**:
- Requires running both formats simultaneously
- Longer overall migration timeline

### 3. Parallel Run

Run both JSON and DMN side-by-side for validation.

**Pros**:
- Safest approach
- Validates correctness before cutover
- Easy rollback

**Cons**:
- Most complex to set up
- Requires dual maintenance during transition
- Higher operational overhead

**Recommended**: Incremental Migration for most cases

---

## Step-by-Step Migration

### Step 1: Analyze Your Current Rules

```ruby
# Review your existing JSON rules
rules = File.read('my_rules.json')
parsed_rules = JSON.parse(rules)

# Count rules and complexity
puts "Total rulesets: #{parsed_rules['rules']&.size || 0}"
puts "Version: #{parsed_rules['version']}"
```

### Step 2: Create DMN Model

```ruby
require 'decision_agent/dmn'

# Create a new DMN model
model = DecisionAgent::Dmn::Model.new(
  id: "my_decision_model",
  name: "My Decision Model",
  namespace: "http://mycompany.com/dmn/decisions"
)
```

### Step 3: Add Decisions

```ruby
# Create a decision
decision = DecisionAgent::Dmn::Decision.new(
  id: "approval_decision",
  name: "Approval Decision"
)

# Add decision table
decision_table = DecisionAgent::Dmn::DecisionTable.new(
  id: "approval_table",
  hit_policy: "FIRST"
)

decision.instance_variable_set(:@decision_table, decision_table)
model.add_decision(decision)
```

### Step 4: Convert Rules to DMN

```ruby
# Add inputs (conditions)
decision_table.inputs << DecisionAgent::Dmn::Input.new(
  id: "amount_input",
  label: "Amount",
  type_ref: "number"
)

decision_table.inputs << DecisionAgent::Dmn::Input.new(
  id: "role_input",
  label: "User Role",
  type_ref: "string"
)

# Add outputs (actions/decisions)
decision_table.outputs << DecisionAgent::Dmn::Output.new(
  id: "decision_output",
  label: "Decision",
  type_ref: "string",
  name: "decision"
)

# Add rules
rule1 = DecisionAgent::Dmn::Rule.new(id: "rule_1")
rule1.instance_variable_set(:@input_entries, ["< 1000", '"admin"'])
rule1.instance_variable_set(:@output_entries, ['"auto_approve"'])
decision_table.rules << rule1

rule2 = DecisionAgent::Dmn::Rule.new(id: "rule_2")
rule2.instance_variable_set(:@input_entries, [">= 1000", '"admin"'])
rule2.instance_variable_set(:@output_entries, ['"manual_review"'])
decision_table.rules << rule2
```

### Step 5: Validate DMN Model

```ruby
# Validate the model
validator = DecisionAgent::Dmn::Validator.new(model)
if validator.validate
  puts "✓ Model is valid!"
else
  puts "✗ Validation errors:"
  validator.errors.each { |error| puts "  - #{error}" }
end
```

### Step 6: Export to DMN XML

```ruby
# Export to DMN XML file
exporter = DecisionAgent::Dmn::Exporter.new
xml = exporter.export(model)
File.write('my_decision_model.dmn', xml)

puts "Exported to my_decision_model.dmn"
```

### Step 7: Test Migration

```ruby
# Test with sample data
evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  dmn_model: model,
  decision_id: "approval_decision"
)

context = DecisionAgent::Context.new({
  amount: 500,
  role: "admin"
})

result = evaluator.evaluate(context: context)
puts "Decision: #{result.decision}"
```

---

## JSON to DMN Mapping

### Basic Rule Structure

**JSON Format**:
```json
{
  "version": "1.0",
  "ruleset": "approval_rules",
  "rules": [
    {
      "id": "admin_auto_approve",
      "if": {
        "all": [
          { "field": "role", "op": "eq", "value": "admin" },
          { "field": "amount", "op": "lt", "value": 1000 }
        ]
      },
      "then": {
        "decision": "approve",
        "weight": 0.95
      }
    }
  ]
}
```

**DMN Format** (Conceptual):
```
Decision Table: Approval Decision
Hit Policy: FIRST

| Role  | Amount | Decision |
|-------|--------|----------|
| admin | < 1000 | approve  |
```

### Condition Operators Mapping

| JSON Operator | DMN FEEL Expression |
|---------------|---------------------|
| `"op": "eq"` | `= value` |
| `"op": "gt"` | `> value` |
| `"op": "lt"` | `< value` |
| `"op": "gte"` | `>= value` |
| `"op": "lte"` | `<= value` |
| `"op": "in"` | `in [list]` |
| `"op": "between"` | `[min..max]` |
| `"op": "contains"` | `contains("text")` |

### Complex Conditions

**JSON** (`all`):
```json
{
  "all": [
    { "field": "age", "op": "gte", "value": 18 },
    { "field": "status", "op": "eq", "value": "active" }
  ]
}
```

**DMN**: Multiple input columns
```
| Age   | Status | Decision |
|-------|--------|----------|
| >= 18 | active | approve  |
```

**JSON** (`any`):
```json
{
  "any": [
    { "field": "role", "op": "eq", "value": "admin" },
    { "field": "role", "op": "eq", "value": "manager" }
  ]
}
```

**DMN**: Use FEEL `in` expression
```
| Role              | Decision |
|-------------------|----------|
| in ["admin","manager"] | approve  |
```

---

## Common Migration Patterns

### Pattern 1: Simple If-Then Rules

**Before (JSON)**:
```json
{
  "id": "low_risk",
  "if": { "field": "risk_score", "op": "lt", "value": 50 },
  "then": { "decision": "approve" }
}
```

**After (DMN)**:
- Input: `risk_score` (number)
- Condition: `< 50`
- Output: `approve`

### Pattern 2: Multiple Conditions

**Before (JSON)**:
```json
{
  "all": [
    { "field": "credit_score", "op": "gte", "value": 700 },
    { "field": "income", "op": "gte", "value": 50000 },
    { "field": "employment_status", "op": "eq", "value": "employed" }
  ]
}
```

**After (DMN)**:
Create three input columns, one rule with all conditions

### Pattern 3: Priority Rules

**Before (JSON)** (using weight):
```json
[
  { "id": "rule1", "then": { "decision": "A", "weight": 0.9 } },
  { "id": "rule2", "then": { "decision": "B", "weight": 0.8 } }
]
```

**After (DMN)**:
Use hit policy "PRIORITY" or "FIRST" with ordered rules

### Pattern 4: Default/Fallback Rules

**Before (JSON)**:
```json
{
  "id": "default",
  "if": { "field": "*", "op": "present" },
  "then": { "decision": "manual_review" }
}
```

**After (DMN)**:
Add final rule with all wildcards (`-`)

---

## Testing Your Migration

### Create Test Suite

```ruby
require 'decision_agent/dmn/testing'

# Create tester
tester = DecisionAgent::Dmn::DmnTester.new(model)

# Add test scenarios from old JSON tests
tester.add_scenario(
  decision_id: "approval_decision",
  inputs: { amount: 500, role: "admin" },
  expected_output: "approve",
  description: "Admin with low amount should auto-approve"
)

tester.add_scenario(
  decision_id: "approval_decision",
  inputs: { amount: 5000, role: "user" },
  expected_output: "manual_review",
  description: "User with high amount needs review"
)

# Run tests
report = tester.run_all_tests
puts "Pass rate: #{report[:summary][:pass_rate]}%"
```

### Compare Results

```ruby
# Test both old and new implementations
json_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: old_rules)
dmn_evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  dmn_model: model,
  decision_id: "approval_decision"
)

test_cases.each do |test_case|
  context = DecisionAgent::Context.new(test_case[:inputs])

  json_result = json_evaluator.evaluate(context: context)
  dmn_result = dmn_evaluator.evaluate(context: context)

  if json_result.decision != dmn_result.decision
    puts "MISMATCH: #{test_case[:description]}"
    puts "  JSON: #{json_result.decision}"
    puts "  DMN:  #{dmn_result.decision}"
  end
end
```

---

## Rollback Strategy

### Save Original Rules

```ruby
# Before migration, save original version
version_manager = DecisionAgent::Versioning::VersionManager.new
version_manager.save_version(
  rule_id: "approval_rules",
  rule_content: original_json_rules,
  created_by: "migration_script",
  changelog: "Pre-DMN migration backup"
)
```

### Keep Both Formats

```ruby
# Run both evaluators during transition
class MigrationAgent
  def initialize(json_rules, dmn_model, decision_id)
    @json_evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(
      rules_json: json_rules
    )
    @dmn_evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
      dmn_model: dmn_model,
      decision_id: decision_id
    )
    @use_dmn = false
  end

  def evaluate(context)
    if @use_dmn
      @dmn_evaluator.evaluate(context: context)
    else
      @json_evaluator.evaluate(context: context)
    end
  end

  def switch_to_dmn!
    @use_dmn = true
  end

  def rollback_to_json!
    @use_dmn = false
  end
end
```

---

## Troubleshooting

### Issue: Rules Don't Match Expected Behavior

**Cause**: FEEL expression syntax differences

**Solution**: Check FEEL expression syntax
```ruby
# Use DMN validator
validator.warnings.each { |warning| puts warning }
```

### Issue: Performance Degradation

**Cause**: No caching enabled

**Solution**: Use cached evaluator
```ruby
cached_evaluator = DecisionAgent::Dmn::CachedDmnEvaluator.new(
  dmn_model: model,
  decision_id: decision_id,
  enable_caching: true
)
```

### Issue: Complex Nested Logic

**Cause**: DMN decision tables work differently than nested JSON

**Solution**: Break into multiple decisions with dependencies

### Issue: Missing Features

**Cause**: DMN doesn't support all custom JSON features

**Solution**: Use custom functions or literal expressions for complex logic

---

## Best Practices

1. **Start Small**: Migrate simplest rules first
2. **Test Thoroughly**: Create comprehensive test suites
3. **Document Changes**: Note any behavioral differences
4. **Version Everything**: Save versions before and after migration
5. **Monitor Performance**: Track evaluation times
6. **Train Team**: Ensure team understands DMN format
7. **Use Visual Tools**: Take advantage of DMN editor for complex tables
8. **Validate Early**: Run DMN validator frequently during migration

---

## Next Steps

After successful migration:

1. Read [DMN Best Practices](DMN_BEST_PRACTICES.md)
2. Set up visual DMN editor for business users
3. Integrate with enterprise DMN tools if needed
4. Establish DMN governance processes
5. Create DMN modeling standards for your organization

---

**Document Version**: 1.0
**Last Updated**: January 2, 2026
**Status**: Ready for Use
