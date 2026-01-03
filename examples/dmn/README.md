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

## Hit Policy Examples

### 4. hit_policy_unique.rb

Demonstrates the UNIQUE hit policy:
- Exactly one rule must match
- Error handling when no rules match or multiple rules match
- Use cases: tax brackets, mutually exclusive categories

**Run:**
```bash
ruby examples/dmn/hit_policy_unique.rb
```

**Key Concepts:**
- UNIQUE hit policy behavior
- Mutually exclusive rule design
- Error handling for rule coverage gaps

### 5. hit_policy_priority.rb

Demonstrates the PRIORITY hit policy:
- Returns the first matching rule (top-to-bottom order)
- Multiple rules can match, but highest priority wins
- Use cases: tiered discounts, priority-based routing

**Run:**
```bash
ruby examples/dmn/hit_policy_priority.rb
```

**Key Concepts:**
- PRIORITY hit policy behavior
- Rule ordering and precedence
- Tiered decision logic

### 6. hit_policy_any.rb

Demonstrates the ANY hit policy:
- All matching rules must have the same output
- Error when matching rules conflict
- Use cases: validation rules, consistency checks

**Run:**
```bash
ruby examples/dmn/hit_policy_any.rb
```

**Key Concepts:**
- ANY hit policy behavior
- Consistency validation
- Error handling for conflicting rules

### 7. hit_policy_collect.rb

Demonstrates the COLLECT hit policy:
- Returns all matching rules
- First match is primary decision, metadata includes all matches
- Use cases: product recommendations, multi-select scenarios

**Run:**
```bash
ruby examples/dmn/hit_policy_collect.rb
```

**Key Concepts:**
- COLLECT hit policy behavior
- Accessing all matching rules via metadata
- Multi-result decision scenarios

## Advanced Examples

### 8. advanced_feel_expressions.rb

Demonstrates advanced FEEL expression features:
- Range expressions: `[min..max]`, `[min..max)`, `(min..max)`
- Don't care wildcards: `-`
- Complex comparisons and multiple conditions
- Real-world insurance premium calculation

**Run:**
```bash
ruby examples/dmn/advanced_feel_expressions.rb
```

**Key Concepts:**
- Range expressions (inclusive, exclusive, half-open)
- Wildcard usage patterns
- Complex multi-input conditions

### 9. real_world_pricing.rb

Real-world e-commerce pricing scenario:
- Customer segment-based pricing (VIP, Premium, Standard)
- Product category discounts
- Volume-based pricing tiers
- Promotional code overrides

**Run:**
```bash
ruby examples/dmn/real_world_pricing.rb
```

**Key Concepts:**
- Business rule modeling
- Complex pricing logic
- Priority-based rule selection

### 10. real_world_routing.rb

Real-world request routing scenario:
- Priority-based routing (critical, high, standard)
- Request type routing (API, batch, web)
- Geographic routing (EU for GDPR compliance)
- Service tier routing (enterprise, standard)

**Run:**
```bash
ruby examples/dmn/real_world_routing.rb
```

**Key Concepts:**
- Routing decision logic
- Compliance considerations
- Multi-factor routing decisions

### 11. error_handling_patterns.rb

Demonstrates error handling with different hit policies:
- UNIQUE: Handling no-match and multiple-match errors
- ANY: Handling conflicting output errors
- Best practices for error recovery

**Run:**
```bash
ruby examples/dmn/error_handling_patterns.rb
```

**Key Concepts:**
- Error handling patterns
- Rule validation through errors
- Debugging rule definition issues

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

- **FIRST**: Return the first matching rule (most common)
- **UNIQUE**: Exactly one rule must match (error if zero or multiple match)
- **PRIORITY**: Return highest priority matching rule (first in table)
- **ANY**: All matching rules must have same output (error if conflicting)
- **COLLECT**: Return all matching rules (first match + metadata for all)

*All hit policies are fully supported. See examples 4-7 for detailed demonstrations.*

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

## Supported Features

The current implementation supports:
- ✅ DMN XML import/export
- ✅ Decision table execution
- ✅ FEEL expressions (comparisons, literals, ranges, wildcards)
- ✅ All hit policies (UNIQUE, FIRST, PRIORITY, ANY, COLLECT)
- ✅ Multiple outputs per decision table
- ✅ Integration with versioning system
- ✅ Round-trip conversion (import → export → import)

Coming in future releases:
- 🔄 Full FEEL 1.3 language support (arithmetic, logical operators, functions)
- 🔄 Decision trees and graphs
- 🔄 Visual DMN modeler
