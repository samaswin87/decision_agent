# DMN Examples

This directory contains examples demonstrating DMN (Decision Model and Notation) support in DecisionAgent.

## Overview

DMN is an industry standard for decision modeling that enables:
- **Portability**: Import/export decision models from/to other DMN-compliant tools
- **Standards Compliance**: Work with tools like Drools, Camunda, IBM ODM
- **Visual Modeling**: Use industry-standard decision table format
- **Enterprise Adoption**: Meet requirements for organizations with existing DMN investments

## Examples

### 1. basic_import.rb

Demonstrates the fundamentals of DMN support:
- Importing a DMN XML model
- Creating a DMN evaluator
- Making decisions with the imported model
- Understanding FEEL expressions in decision tables

**Run:**
```bash
ruby examples/dmn/basic_import.rb
```

**Key Concepts:**
- DMN XML structure
- Decision tables with input/output clauses
- FEEL (Friendly Enough Expression Language) syntax
- Hit policies (FIRST, UNIQUE, etc.)

### 2. import_export.rb

Shows how to work with DMN files and the versioning system:
- Importing DMN files from disk
- Storing DMN models in the versioning system
- Exporting models back to DMN XML format
- Verifying round-trip conversion preserves the model

**Run:**
```bash
ruby examples/dmn/import_export.rb
```

**Key Concepts:**
- DMN file I/O operations
- Integration with DecisionAgent's versioning system
- Round-trip conversion fidelity
- Model equivalence testing

### 3. combining_evaluators.rb

Demonstrates using DMN and JSON evaluators together:
- Creating both DMN and JSON rule evaluators
- Combining them in a single agent
- Leveraging different evaluator types for different aspects
- Understanding how decisions from multiple sources are combined

**Run:**
```bash
ruby examples/dmn/combining_evaluators.rb
```

**Key Concepts:**
- Multi-evaluator agents
- DMN for standardized decision logic
- JSON rules for custom business policies
- Decision aggregation and conflict resolution

## DMN Structure

### Basic DMN XML

A minimal DMN decision table looks like this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/"
             id="my_decision"
             name="My Decision"
             namespace="http://example.com">

  <decision id="decision_1" name="My First Decision">
    <decisionTable id="table_1" hitPolicy="FIRST">
      <!-- Input columns -->
      <input id="input_1" label="Age">
        <inputExpression typeRef="number">
          <text>age</text>
        </inputExpression>
      </input>

      <!-- Output column -->
      <output id="output_1" label="Result" name="result" typeRef="string"/>

      <!-- Decision rules -->
      <rule id="rule_1">
        <inputEntry><text>&gt;= 18</text></inputEntry>
        <outputEntry><text>"adult"</text></outputEntry>
      </rule>

      <rule id="rule_2">
        <inputEntry><text>&lt; 18</text></inputEntry>
        <outputEntry><text>"minor"</text></outputEntry>
      </rule>
    </decisionTable>
  </decision>
</definitions>
```

### FEEL Expressions

FEEL (Friendly Enough Expression Language) is used in DMN for conditions and outputs:

**Comparisons:**
- `>= 18` - Greater than or equal to 18
- `< 100` - Less than 100
- `[50..100]` - Between 50 and 100 (inclusive)

**String Literals:**
- `"approved"` - String value (quotes required in DMN XML)

**Don't Care:**
- `-` - Match any value (don't care)

## Hit Policies

DMN decision tables support different hit policies:

- **FIRST**: Return the first matching rule (default in Phase 2A)
- **UNIQUE**: Exactly one rule must match (error if multiple match)
- **PRIORITY**: Return highest priority matching rule
- **ANY**: All matching rules must have same output
- **COLLECT**: Return all matching rules as a list

*Note: Phase 2A supports FIRST policy. Additional policies coming in Phase 2B.*

## Working with Real DMN Files

You can use DMN files created in other tools:

```ruby
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/evaluators/dmn_evaluator"

# Import from a file
importer = DecisionAgent::Dmn::Importer.new
result = importer.import("path/to/model.dmn", created_by: "user")

# Create evaluator
evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: result[:model],
  decision_id: "your_decision_id"
)

# Make decisions
evaluation = evaluator.evaluate(
  DecisionAgent::Context.new(your_input: "value")
)

puts evaluation.decision
```

## Next Steps

After exploring these examples:

1. Read the [DMN Guide](../../docs/DMN_GUIDE.md) for comprehensive documentation
2. Check the [DMN API Reference](../../docs/DMN_API.md) for detailed API information
3. Review the [FEEL Reference](../../docs/FEEL_REFERENCE.md) for expression syntax
4. Explore the test fixtures in `spec/fixtures/dmn/` for more examples

## Resources

- [DMN 1.3 Specification](https://www.omg.org/spec/DMN/1.3/)
- [DMN Tutorial](https://camunda.com/dmn/)
- [FEEL Language Guide](https://docs.camunda.org/manual/latest/reference/dmn/feel/)

## Phase 2A Limitations

The current Phase 2A implementation supports:
- ✅ DMN XML import/export
- ✅ Decision table execution
- ✅ Basic FEEL expressions (comparisons, literals, ranges)
- ✅ FIRST hit policy
- ✅ Integration with versioning system

Coming in Phase 2B:
- 🔄 Full FEEL 1.3 language support
- 🔄 All hit policies (UNIQUE, PRIORITY, ANY, COLLECT)
- 🔄 Decision trees and graphs
- 🔄 Visual DMN modeler
- 🔄 Multi-output support
