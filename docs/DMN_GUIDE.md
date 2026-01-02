# DMN Guide

Welcome to the DecisionAgent DMN (Decision Model and Notation) Guide. This guide will help you understand and use DMN support in DecisionAgent.

## Table of Contents

- [What is DMN?](#what-is-dmn)
- [Why Use DMN?](#why-use-dmn)
- [Getting Started](#getting-started)
- [DMN Concepts](#dmn-concepts)
- [Importing DMN Models](#importing-dmn-models)
- [Exporting to DMN](#exporting-to-dmn)
- [FEEL Expressions](#feel-expressions)
- [Decision Tables](#decision-tables)
- [Hit Policies](#hit-policies)
- [Integration with DecisionAgent](#integration-with-decisionagent)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## What is DMN?

DMN (Decision Model and Notation) is an industry standard maintained by the Object Management Group (OMG) for modeling and executing business decisions. DMN provides:

- **Standard notation** for decision modeling
- **Visual decision tables** that business users can understand
- **FEEL expression language** for defining decision logic
- **Interoperability** between different tools and platforms
- **Formal semantics** for precise execution

DecisionAgent implements **DMN 1.3**, supporting decision tables with the FEEL expression language.

## Why Use DMN?

### Portability
Import decision models from tools like Camunda, Drools, or IBM ODM, and export your models for use in other DMN-compliant systems.

### Standards Compliance
Meet enterprise requirements for standardized decision modeling and align with industry best practices.

### Business-Friendly
Decision tables are visual and intuitive, making them accessible to business analysts and domain experts.

### Vendor Interoperability
DMN is vendor-neutral, preventing lock-in to any specific tool or platform.

### Regulatory Compliance
DMN provides traceable, auditable decision logic for industries with strict compliance requirements.

## Getting Started

### Installation

DMN support is included in DecisionAgent. No additional gems are required:

```ruby
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/dmn/exporter"
require "decision_agent/evaluators/dmn_evaluator"
```

### Quick Example

```ruby
# Import a DMN file
importer = DecisionAgent::Dmn::Importer.new
result = importer.import("loan_approval.dmn", created_by: "analyst")

# Create an evaluator
evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: result[:model],
  decision_id: "loan_decision"
)

# Make a decision
evaluation = evaluator.evaluate(
  DecisionAgent::Context.new(
    credit_score: 750,
    income: 75000
  )
)

puts evaluation.decision  # => "approved"
```

## DMN Concepts

### Definitions

The root element of a DMN document. Contains metadata and one or more decisions.

```xml
<definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
             id="my_model"
             name="My Decision Model"
             namespace="http://example.com">
  <!-- decisions go here -->
</definitions>
```

### Decision

Represents a single decision point. Can contain a decision table, literal expression, or other decision logic.

```xml
<decision id="credit_check" name="Credit Worthiness Check">
  <decisionTable>
    <!-- table definition -->
  </decisionTable>
</decision>
```

### Decision Table

A tabular representation of decision logic with:
- **Input columns**: Variables to evaluate
- **Output columns**: Results to produce
- **Rules (rows)**: Conditions and corresponding outputs

### Input Clause

Defines an input variable and its type:

```xml
<input id="input_age" label="Customer Age">
  <inputExpression typeRef="number">
    <text>age</text>
  </inputExpression>
</input>
```

### Output Clause

Defines what the decision produces:

```xml
<output id="output_approval"
        label="Approval Decision"
        name="approved"
        typeRef="string"/>
```

### Rule

A row in the decision table with conditions (input entries) and results (output entries):

```xml
<rule id="rule_1">
  <description>Approve if age >= 18</description>
  <inputEntry>
    <text>>= 18</text>
  </inputEntry>
  <outputEntry>
    <text>"approved"</text>
  </outputEntry>
</rule>
```

## Importing DMN Models

### From a File

```ruby
importer = DecisionAgent::Dmn::Importer.new
result = importer.import(
  "path/to/model.dmn",
  ruleset_name: "my_rules",  # Optional: custom name
  created_by: "username"
)

puts "Imported #{result[:decisions_imported]} decisions"
puts "Model: #{result[:model].name}"
```

### From XML String

```ruby
dmn_xml = File.read("model.dmn")

importer = DecisionAgent::Dmn::Importer.new
result = importer.import_from_xml(
  dmn_xml,
  ruleset_name: "my_rules",
  created_by: "username"
)
```

### With Version Management

DecisionAgent automatically stores imported DMN models in the versioning system:

```ruby
# Import creates a version
importer = DecisionAgent::Dmn::Importer.new(version_manager: my_version_manager)
result = importer.import("model.dmn", ruleset_name: "rules_v1", created_by: "user")

# Retrieve active version
version = my_version_manager.get_active_version(rule_id: "rules_v1")

# Get version history
versions = my_version_manager.get_versions(rule_id: "rules_v1")
```

### Import Result

The import method returns a hash with:

```ruby
{
  model: DecisionAgent::Dmn::Model,          # Parsed DMN model
  rules: Array,                               # Converted JSON rules
  versions: Array,                            # Version records
  decisions_imported: Integer                 # Count of decisions
}
```

## Exporting to DMN

### Basic Export

```ruby
exporter = DecisionAgent::Dmn::Exporter.new(version_manager: my_version_manager)

# Export to string
dmn_xml = exporter.export("ruleset_id")

# Export to file
exporter.export("ruleset_id", output_path: "exported_model.dmn")
```

### Round-Trip Conversion

DecisionAgent supports round-trip conversion - you can import a DMN file, modify it through the versioning system, export it, and re-import with preserved structure:

```ruby
# Import
result1 = importer.import("original.dmn", ruleset_name: "v1", created_by: "user")

# Export
exported_xml = exporter.export("v1")

# Re-import
result2 = importer.import_from_xml(exported_xml, ruleset_name: "v2", created_by: "user")

# Both produce equivalent results
```

## FEEL Expressions

FEEL (Friendly Enough Expression Language) is used in DMN for decision logic.

### Phase 2A Support

DecisionAgent Phase 2A supports essential FEEL expressions:

#### Literals

```xml
<text>42</text>                    <!-- Number -->
<text>"approved"</text>            <!-- String (quotes required!) -->
<text>true</text>                  <!-- Boolean -->
```

#### Comparisons

```xml
<text>>= 18</text>                 <!-- Greater than or equal -->
<text>< 100</text>                 <!-- Less than -->
<text>> 50</text>                  <!-- Greater than -->
<text><= 1000</text>               <!-- Less than or equal -->
```

#### Ranges

```xml
<text>[18..65]</text>              <!-- Between 18 and 65 (inclusive) -->
<text>(0..100)</text>              <!-- Between 0 and 100 (exclusive) -->
```

#### Don't Care

```xml
<text>-</text>                     <!-- Match any value -->
```

### Phase 2B (Coming Soon)

Full FEEL 1.3 support including:
- Lists: `[1, 2, 3]`
- Contexts: `{name: "John", age: 30}`
- Functions: `date("2024-01-01")`
- Logical operators: `and`, `or`, `not`
- Arithmetic: `+`, `-`, `*`, `/`

## Decision Tables

### Structure

A decision table consists of:

1. **Header**: Input and output column definitions
2. **Rules**: Rows with conditions and results
3. **Hit Policy**: How to handle multiple matching rules

### Example

```xml
<decisionTable id="loan_table" hitPolicy="FIRST">
  <!-- Inputs -->
  <input id="input_score" label="Credit Score">
    <inputExpression typeRef="number">
      <text>credit_score</text>
    </inputExpression>
  </input>

  <input id="input_income" label="Income">
    <inputExpression typeRef="number">
      <text>income</text>
    </inputExpression>
  </input>

  <!-- Output -->
  <output id="output_decision" label="Decision" name="decision" typeRef="string"/>

  <!-- Rules -->
  <rule id="approve_excellent">
    <inputEntry><text>>= 750</text></inputEntry>
    <inputEntry><text>>= 75000</text></inputEntry>
    <outputEntry><text>"approved"</text></outputEntry>
  </rule>

  <rule id="approve_good">
    <inputEntry><text>>= 650</text></inputEntry>
    <inputEntry><text>>= 50000</text></inputEntry>
    <outputEntry><text>"conditional"</text></outputEntry>
  </rule>

  <rule id="reject_default">
    <inputEntry><text>-</text></inputEntry>
    <inputEntry><text>-</text></inputEntry>
    <outputEntry><text>"rejected"</text></outputEntry>
  </rule>
</decisionTable>
```

### Rule Evaluation

Rules are evaluated top-to-bottom. The hit policy determines what happens when multiple rules match.

### Input Mapping

Input expressions (e.g., `credit_score`) map to context variables:

```ruby
context = DecisionAgent::Context.new(
  credit_score: 720,  # Maps to 'credit_score' input
  income: 65000       # Maps to 'income' input
)
```

## Hit Policies

Hit policies define how to handle multiple matching rules.

### FIRST (Phase 2A)

Returns the first matching rule. Most common and simplest policy.

```xml
<decisionTable hitPolicy="FIRST">
  <!-- rules evaluated top-to-bottom, first match wins -->
</decisionTable>
```

**When to use**: Clear rule precedence, mutually exclusive conditions

### UNIQUE, PRIORITY, ANY, COLLECT (Phase 2B)

Coming in Phase 2B:

- **UNIQUE**: Exactly one rule must match (error if multiple)
- **PRIORITY**: Return highest priority match
- **ANY**: All matches must have same output
- **COLLECT**: Return all matches as a list

## Integration with DecisionAgent

### Creating a DMN Evaluator

```ruby
evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: dmn_model,
  decision_id: "my_decision",
  name: "MyDmnEvaluator"  # Optional
)
```

### Using with an Agent

```ruby
agent = DecisionAgent::Agent.new(
  evaluators: [dmn_evaluator]
)

decision = agent.decide(context: { credit_score: 720 })
```

### Combining with JSON Evaluators

```ruby
agent = DecisionAgent::Agent.new(
  evaluators: [
    dmn_evaluator,        # Standards-based decision tables
    json_evaluator        # Custom business rules
  ]
)

# Agent combines results from both evaluators
decision = agent.decide(context: input_data)
```

### Accessing Evaluations

```ruby
decision = agent.decide(context: data)

# Overall decision
puts decision.decision

# Individual evaluations
decision.evaluations.each do |eval|
  puts "#{eval.evaluator_name}: #{eval.decision} (#{eval.confidence})"
  eval.explanations.each do |exp|
    puts "  - #{exp.reason}"
  end
end
```

## Best Practices

### 1. Use Descriptive IDs and Labels

```xml
<!-- Good -->
<decision id="loan_approval_decision" name="Loan Approval Decision">
  <input id="input_credit_score" label="Credit Score">

<!-- Avoid -->
<decision id="d1" name="Decision 1">
  <input id="i1" label="Input">
```

### 2. Add Rule Descriptions

```xml
<rule id="approve_excellent_credit">
  <description>Approve excellent credit (>=750) with high income (>=75k)</description>
  <!-- ... -->
</rule>
```

### 3. Order Rules by Priority

With FIRST hit policy, put most specific/important rules first:

```xml
<!-- 1. Special cases first -->
<rule id="vip_customer">...</rule>

<!-- 2. Standard cases -->
<rule id="good_credit">...</rule>

<!-- 3. Default case last -->
<rule id="default_reject">
  <inputEntry><text>-</text></inputEntry>
  <outputEntry><text>"rejected"</text></outputEntry>
</rule>
```

### 4. Use Semantic Versioning

```ruby
importer.import("model.dmn", ruleset_name: "loan_rules_v1.0", created_by: "analyst")
importer.import("model_v2.dmn", ruleset_name: "loan_rules_v2.0", created_by: "analyst")
```

### 5. Test Round-Trip Conversion

Always verify exports can be re-imported:

```ruby
# Import original
original = importer.import("model.dmn", ruleset_name: "test", created_by: "user")

# Export
xml = exporter.export("test")

# Re-import and test
reimported = importer.import_from_xml(xml, ruleset_name: "test2", created_by: "user")

# Verify equivalence
test_contexts.each do |ctx|
  assert_equal(
    original_evaluator.evaluate(ctx).decision,
    reimported_evaluator.evaluate(ctx).decision
  )
end
```

### 6. Validate Models

```ruby
require "decision_agent/dmn/validator"

validator = DecisionAgent::Dmn::Validator.new(model)
validator.validate!  # Raises error if invalid
```

## Troubleshooting

### Empty Decision Values

**Problem**: Decision is empty string after re-import

**Cause**: Missing quotes around string literals in output entries

**Solution**: Ensure string outputs have quotes:

```xml
<!-- Wrong -->
<outputEntry><text>approved</text></outputEntry>

<!-- Correct -->
<outputEntry><text>"approved"</text></outputEntry>
```

### Input Not Matching

**Problem**: Rules don't match despite correct input values

**Cause**: Input expression doesn't match context variable name

**Solution**: Ensure inputExpression text matches context keys:

```xml
<input id="input_1" label="Age">
  <inputExpression typeRef="number">
    <text>age</text>  <!-- Must match context key -->
  </inputExpression>
</input>
```

```ruby
# Context must have matching key
context = DecisionAgent::Context.new(age: 25)  # Matches 'age'
```

### Invalid DMN Structure

**Problem**: `InvalidDmnModelError` when importing

**Cause**: Mismatched input entries count

**Solution**: Ensure each rule has exactly as many input entries as the table has inputs:

```xml
<!-- Table has 2 inputs -->
<input id="input_1">...</input>
<input id="input_2">...</input>

<!-- Each rule must have 2 input entries -->
<rule id="rule_1">
  <inputEntry><text>>= 18</text></inputEntry>
  <inputEntry><text>"active"</text></inputEntry>  <!-- Must have 2! -->
  <outputEntry><text>"approved"</text></outputEntry>
</rule>
```

### Namespace Issues

**Problem**: Parser can't find DMN elements

**Cause**: Incorrect or missing namespace

**Solution**: Use DMN 1.3 namespace:

```xml
<definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
             xmlns:dmndi="https://www.omg.org/spec/DMN/20191111/DMNDI/"
             xmlns:dc="http://www.omg.org/spec/DMN/20180521/DC/">
```

## Next Steps

- Review [DMN API Reference](DMN_API.md) for detailed API documentation
- Study [FEEL Reference](FEEL_REFERENCE.md) for expression syntax
- Explore [DMN examples](../examples/dmn/) for practical use cases
- Read the [DMN 1.3 Specification](https://www.omg.org/spec/DMN/1.3/) for complete details

## Resources

- [OMG DMN Specification](https://www.omg.org/spec/DMN/)
- [DMN Tutorial](https://camunda.com/dmn/)
- [FEEL Language Guide](https://docs.camunda.org/manual/latest/reference/dmn/feel/)
- [DMN Test Compatibility Kit](https://github.com/dmn-tck/tck)
