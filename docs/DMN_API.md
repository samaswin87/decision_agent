# DMN API Reference

Complete API reference for DecisionAgent's DMN support.

## Table of Contents

- [Module: DecisionAgent::Dmn](#module-decisionagentdmn)
- [Class: Importer](#class-importer)
- [Class: Exporter](#class-exporter)
- [Class: Parser](#class-parser)
- [Class: Validator](#class-validator)
- [Class: Adapter](#class-adapter)
- [Class: Model](#class-model)
- [Class: Decision](#class-decision)
- [Class: DecisionTable](#class-decisiontable)
- [Class: DmnEvaluator](#class-dmnevaluator)
- [Module: Feel](#module-feel)
- [Error Classes](#error-classes)

---

## Module: DecisionAgent::Dmn

Main namespace for DMN functionality.

```ruby
require "decision_agent/dmn/importer"
require "decision_agent/dmn/exporter"
require "decision_agent/evaluators/dmn_evaluator"
```

---

## Class: Importer

**Path**: `decision_agent/dmn/importer.rb`

Imports DMN XML files into DecisionAgent.

### Constructor

```ruby
DecisionAgent::Dmn::Importer.new(version_manager: nil)
```

**Parameters**:
- `version_manager` (VersionManager, optional): Version manager for storing imported models. Defaults to new instance.

**Example**:
```ruby
importer = DecisionAgent::Dmn::Importer.new
```

### Instance Methods

#### #import

Imports a DMN file from disk.

```ruby
import(file_path, ruleset_name: nil, created_by: "system") → Hash
```

**Parameters**:
- `file_path` (String): Path to DMN XML file
- `ruleset_name` (String, optional): Custom name for the ruleset. Defaults to decision ID.
- `created_by` (String): User who performed the import. Default: "system"

**Returns**: Hash with:
- `:model` (Model): Parsed DMN model
- `:rules` (Array): Converted JSON rules for each decision
- `:versions` (Array): Version records created
- `:decisions_imported` (Integer): Count of decisions imported

**Raises**:
- `InvalidDmnXmlError`: If XML is malformed
- `InvalidDmnModelError`: If DMN structure is invalid

**Example**:
```ruby
result = importer.import(
  "loan_approval.dmn",
  ruleset_name: "loan_rules_v1",
  created_by: "analyst"
)

puts "Imported #{result[:decisions_imported]} decisions"
model = result[:model]
```

#### #import_from_xml

Imports DMN from an XML string.

```ruby
import_from_xml(xml_content, ruleset_name: nil, created_by: "system") → Hash
```

**Parameters**:
- `xml_content` (String): DMN XML content
- `ruleset_name` (String, optional): Custom name for the ruleset
- `created_by` (String): User who performed the import

**Returns**: Same as `#import`

**Example**:
```ruby
xml = File.read("model.dmn")
result = importer.import_from_xml(xml, created_by: "user")
```

---

## Class: Exporter

**Path**: `decision_agent/dmn/exporter.rb`

Exports DecisionAgent rules to DMN XML format.

### Constructor

```ruby
DecisionAgent::Dmn::Exporter.new(version_manager: nil)
```

**Parameters**:
- `version_manager` (VersionManager, optional): Version manager for retrieving rules. Defaults to new instance.

### Instance Methods

#### #export

Exports a ruleset to DMN XML.

```ruby
export(rule_id, output_path: nil) → String
```

**Parameters**:
- `rule_id` (String): ID of the ruleset to export
- `output_path` (String, optional): If provided, writes XML to this file path

**Returns**: String containing DMN XML

**Raises**:
- `InvalidDmnModelError`: If no active version found for rule_id

**Example**:
```ruby
exporter = DecisionAgent::Dmn::Exporter.new(version_manager: vm)

# Export to string
xml = exporter.export("loan_rules")

# Export to file
exporter.export("loan_rules", output_path: "exported.dmn")
```

---

## Class: Parser

**Path**: `decision_agent/dmn/parser.rb`

Parses DMN 1.3 XML into Ruby model objects.

### Constructor

```ruby
DecisionAgent::Dmn::Parser.new(xml_content)
```

**Parameters**:
- `xml_content` (String): DMN XML content to parse

### Instance Methods

#### #parse

Parses the XML and returns a Model object.

```ruby
parse() → Model
```

**Returns**: `DecisionAgent::Dmn::Model` instance

**Raises**:
- `InvalidDmnXmlError`: If XML is malformed or missing required elements

**Example**:
```ruby
xml = File.read("model.dmn")
parser = DecisionAgent::Dmn::Parser.new(xml)
model = parser.parse

puts "Model: #{model.name}"
puts "Decisions: #{model.decisions.size}"
```

---

## Class: Validator

**Path**: `decision_agent/dmn/validator.rb`

Validates DMN model structure.

### Constructor

```ruby
DecisionAgent::Dmn::Validator.new(model)
```

**Parameters**:
- `model` (Model): DMN model to validate

### Instance Methods

#### #validate!

Validates the model and raises an error if invalid.

```ruby
validate!() → true
```

**Returns**: `true` if valid

**Raises**:
- `InvalidDmnModelError`: If model structure is invalid

**Example**:
```ruby
validator = DecisionAgent::Dmn::Validator.new(model)
validator.validate!  # Raises if invalid
```

---

## Class: Adapter

**Path**: `decision_agent/dmn/adapter.rb`

Converts DMN decision tables to DecisionAgent JSON rule format.

### Constructor

```ruby
DecisionAgent::Dmn::Adapter.new(decision_table)
```

**Parameters**:
- `decision_table` (DecisionTable): DMN decision table to convert

### Instance Methods

#### #to_json_rules

Converts the decision table to JSON rules format.

```ruby
to_json_rules() → Hash
```

**Returns**: Hash with JSON rules structure:
```ruby
{
  "version" => "1.0",
  "ruleset" => "table_id",
  "description" => "Converted from DMN decision table",
  "rules" => [...]
}
```

**Example**:
```ruby
adapter = DecisionAgent::Dmn::Adapter.new(decision_table)
json_rules = adapter.to_json_rules
```

---

## Class: Model

**Path**: `decision_agent/dmn/model.rb`

Represents a DMN model (definitions element).

### Constructor

```ruby
DecisionAgent::Dmn::Model.new(id:, name:, namespace:)
```

**Parameters**:
- `id` (String): Model identifier
- `name` (String): Human-readable model name
- `namespace` (String): XML namespace

### Attributes (Read-only)

- `id` (String): Model ID
- `name` (String): Model name
- `namespace` (String): Model namespace
- `decisions` (Array<Decision>): List of decisions in the model

### Instance Methods

#### #add_decision

Adds a decision to the model.

```ruby
add_decision(decision) → Decision
```

**Parameters**:
- `decision` (Decision): Decision to add

**Returns**: The added decision

#### #find_decision

Finds a decision by ID.

```ruby
find_decision(decision_id) → Decision | nil
```

**Parameters**:
- `decision_id` (String): ID of decision to find

**Returns**: Decision object or nil if not found

**Example**:
```ruby
model = Model.new(
  id: "my_model",
  name: "My Decision Model",
  namespace: "http://example.com"
)

decision = model.find_decision("loan_approval")
```

---

## Class: Decision

**Path**: `decision_agent/dmn/model.rb`

Represents a DMN decision.

### Constructor

```ruby
DecisionAgent::Dmn::Decision.new(id:, name:, description: nil)
```

**Parameters**:
- `id` (String): Decision ID
- `name` (String): Decision name
- `description` (String, optional): Decision description

### Attributes (Read-only)

- `id` (String): Decision ID
- `name` (String): Decision name
- `description` (String | nil): Description
- `decision_table` (DecisionTable | nil): Associated decision table

### Attributes (Writable)

- `decision_table=` (DecisionTable): Set the decision table

**Example**:
```ruby
decision = Decision.new(
  id: "credit_check",
  name: "Credit Worthiness Check",
  description: "Determines if applicant meets credit requirements"
)

decision.decision_table = my_table
```

---

## Class: DecisionTable

**Path**: `decision_agent/dmn/model.rb`

Represents a DMN decision table.

### Constructor

```ruby
DecisionAgent::Dmn::DecisionTable.new(id:, hit_policy: "UNIQUE")
```

**Parameters**:
- `id` (String): Table ID
- `hit_policy` (String): Hit policy. Default: "UNIQUE". Phase 2A supports "FIRST".

### Attributes (Read-only)

- `id` (String): Table ID
- `hit_policy` (String): Hit policy
- `inputs` (Array<Input>): Input clauses
- `outputs` (Array<Output>): Output clauses
- `rules` (Array<Rule>): Decision rules

### Instance Methods

#### #add_input

Adds an input clause.

```ruby
add_input(input) → Input
```

#### #add_output

Adds an output clause.

```ruby
add_output(output) → Output
```

#### #add_rule

Adds a rule.

```ruby
add_rule(rule) → Rule
```

**Example**:
```ruby
table = DecisionTable.new(
  id: "loan_table",
  hit_policy: "FIRST"
)

table.add_input(credit_score_input)
table.add_output(decision_output)
table.add_rule(approval_rule)
```

---

### Class: Input

Represents a decision table input clause.

#### Constructor

```ruby
DecisionAgent::Dmn::Input.new(id:, label:, type_ref: nil, expression: nil)
```

**Parameters**:
- `id` (String): Input ID
- `label` (String): Input label
- `type_ref` (String, optional): Data type (e.g., "string", "number")
- `expression` (String, optional): Input expression

---

### Class: Output

Represents a decision table output clause.

#### Constructor

```ruby
DecisionAgent::Dmn::Output.new(id:, label:, name:, type_ref: nil)
```

**Parameters**:
- `id` (String): Output ID
- `label` (String): Output label
- `name` (String): Output variable name
- `type_ref` (String, optional): Data type

---

### Class: Rule

Represents a decision table rule.

#### Constructor

```ruby
DecisionAgent::Dmn::Rule.new(id:, description: nil)
```

**Parameters**:
- `id` (String): Rule ID
- `description` (String, optional): Rule description

### Attributes

- `input_entries` (Array<String>): FEEL expressions for inputs
- `output_entries` (Array<String>): FEEL expressions for outputs

### Instance Methods

#### #add_input_entry

Adds an input entry (condition).

```ruby
add_input_entry(feel_expression) → String
```

#### #add_output_entry

Adds an output entry (result).

```ruby
add_output_entry(feel_expression) → String
```

---

## Class: DmnEvaluator

**Path**: `decision_agent/evaluators/dmn_evaluator.rb`

Evaluates DMN decision models.

### Constructor

```ruby
DecisionAgent::Evaluators::DmnEvaluator.new(model:, decision_id:, name: nil)
```

**Parameters**:
- `model` (Model): DMN model
- `decision_id` (String | Symbol): ID of decision to evaluate
- `name` (String, optional): Evaluator name for logging

**Raises**:
- `InvalidDmnModelError`: If decision not found or has no decision table

**Example**:
```ruby
evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: dmn_model,
  decision_id: "loan_approval",
  name: "LoanApprovalEvaluator"
)
```

### Instance Methods

#### #evaluate

Evaluates the decision for given context.

```ruby
evaluate(context, feedback: {}) → Evaluation
```

**Parameters**:
- `context` (Context): Input context with decision variables
- `feedback` (Hash, optional): Feedback data (for future use)

**Returns**: `DecisionAgent::Evaluation` with:
- `decision`: The decision value
- `confidence`: Confidence score (0.0 to 1.0)
- `explanations`: Array of explanation objects
- `evaluator_name`: Name of this evaluator

**Example**:
```ruby
context = DecisionAgent::Context.new(
  credit_score: 720,
  income: 65000
)

evaluation = evaluator.evaluate(context)

puts evaluation.decision        # => "approved"
puts evaluation.confidence      # => 1.0
puts evaluation.explanations.first.reason
```

### Attributes (Read-only)

- `model` (Model): The DMN model
- `decision_id` (String): The decision ID being evaluated

---

## Module: Feel

**Path**: `decision_agent/dmn/feel/`

FEEL (Friendly Enough Expression Language) support.

### Class: Feel::Evaluator

Evaluates FEEL expressions (Phase 2A subset).

#### Constructor

```ruby
DecisionAgent::Dmn::Feel::Evaluator.new
```

#### Instance Methods

##### #parse_expression

Parses a FEEL expression into operator and value.

```ruby
parse_expression(feel_string) → Hash
```

**Parameters**:
- `feel_string` (String): FEEL expression (e.g., ">= 18")

**Returns**: Hash with `:operator` and `:value`

**Example**:
```ruby
evaluator = DecisionAgent::Dmn::Feel::Evaluator.new
result = evaluator.parse_expression(">= 18")
# => {operator: "gte", value: 18}
```

**Supported Expressions (Phase 2A)**:
- `>= value`: Greater than or equal
- `<= value`: Less than or equal
- `> value`: Greater than
- `< value`: Less than
- `= value`: Equal
- `!= value`: Not equal
- `[min..max]`: Range (inclusive)
- `"string"`: String literal
- `number`: Numeric literal
- `-`: Don't care (match any)

---

## Error Classes

### InvalidDmnXmlError

Raised when DMN XML is malformed or cannot be parsed.

```ruby
raise DecisionAgent::Dmn::InvalidDmnXmlError, "XML parsing failed"
```

### InvalidDmnModelError

Raised when DMN model structure is invalid.

```ruby
raise DecisionAgent::Dmn::InvalidDmnModelError, "Decision not found"
```

### FeelExpressionError

Raised when a FEEL expression cannot be parsed.

```ruby
raise DecisionAgent::Dmn::FeelExpressionError, "Invalid expression"
```

---

## Complete Example

```ruby
require "decision_agent"
require "decision_agent/dmn/importer"
require "decision_agent/dmn/exporter"
require "decision_agent/evaluators/dmn_evaluator"

# Import
importer = DecisionAgent::Dmn::Importer.new
result = importer.import("model.dmn", created_by: "analyst")

# Create evaluator
evaluator = DecisionAgent::Evaluators::DmnEvaluator.new(
  model: result[:model],
  decision_id: "my_decision"
)

# Evaluate
context = DecisionAgent::Context.new(age: 25, status: "active")
evaluation = evaluator.evaluate(context)

puts "Decision: #{evaluation.decision}"
puts "Confidence: #{evaluation.confidence}"

# Export
exporter = DecisionAgent::Dmn::Exporter.new
xml = exporter.export("my_decision")
File.write("exported.dmn", xml)
```

---

## See Also

- [DMN Guide](DMN_GUIDE.md) - User guide and tutorials
- [FEEL Reference](FEEL_REFERENCE.md) - FEEL expression syntax
- [Examples](../examples/dmn/) - Practical examples
