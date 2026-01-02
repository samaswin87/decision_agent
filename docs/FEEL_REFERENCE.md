# FEEL Expression Language Reference

Reference guide for FEEL (Friendly Enough Expression Language) as used in DecisionAgent's DMN support.

## Table of Contents

- [Introduction](#introduction)
- [Phase 2A Support](#phase-2a-support)
- [Data Types](#data-types)
- [Literals](#literals)
- [Comparison Operators](#comparison-operators)
- [Ranges](#ranges)
- [Special Values](#special-values)
- [Usage in DMN](#usage-in-dmn)
- [Examples](#examples)
- [Phase 2B Preview](#phase-2b-preview)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

## Introduction

FEEL (Friendly Enough Expression Language) is the expression language used in DMN for defining decision logic. It provides a business-friendly syntax for expressing conditions and calculations.

### What is FEEL?

FEEL is designed to be:
- **Readable**: Business users can understand expressions
- **Precise**: Formal semantics ensure consistent execution
- **Expressive**: Rich enough for complex decision logic
- **Safe**: No side effects or system access

### FEEL in DecisionAgent

DecisionAgent implements a subset of FEEL 1.3 in Phase 2A, focusing on the most commonly used expressions for decision tables. Full FEEL support is planned for Phase 2B.

## Phase 2A Support

DecisionAgent Phase 2A supports essential FEEL expressions for decision table conditions and outputs:

✅ **Supported:**
- Numeric and string literals
- Comparison operators (`>=`, `<=`, `>`, `<`, `=`)
- Ranges (`[min..max]`)
- Boolean values
- Don't care (`-`)

🔄 **Phase 2B (Coming Soon):**
- Arithmetic operators (`+`, `-`, `*`, `/`)
- Logical operators (`and`, `or`, `not`)
- Lists and contexts
- Built-in functions
- Date/time operations

## Data Types

### Numbers

FEEL supports integers and decimals:

```xml
<text>42</text>
<text>3.14159</text>
<text>-100</text>
<text>1.5e10</text>
```

In DecisionAgent Phase 2A:
- Parsed as Ruby Integer or Float
- Used in numeric comparisons
- Preserved in round-trip conversion

### Strings

Strings must be quoted in FEEL:

```xml
<!-- Correct: quoted string -->
<text>"approved"</text>
<text>"PENDING REVIEW"</text>
<text>"high-risk"</text>

<!-- Wrong: unquoted (treated as variable reference) -->
<text>approved</text>  <!-- This is a variable, not a string! -->
```

**Important**: In DMN XML, string literals in output entries **must** have quotes:

```xml
<outputEntry>
  <text>"approved"</text>  ✓ Correct
</outputEntry>

<outputEntry>
  <text>approved</text>  ✗ Wrong - will be treated as variable
</outputEntry>
```

### Booleans

Boolean values are unquoted:

```xml
<text>true</text>
<text>false</text>
```

## Literals

### Numeric Literals

```xml
<!-- Integer -->
<inputEntry><text>18</text></inputEntry>

<!-- Decimal -->
<inputEntry><text>3.5</text></inputEntry>

<!-- Negative -->
<inputEntry><text>-100</text></inputEntry>
```

**Usage**: Typically in comparisons:
```xml
<inputEntry><text>>= 18</text></inputEntry>
```

### String Literals

```xml
<!-- Always quote strings -->
<outputEntry><text>"approved"</text></outputEntry>
<outputEntry><text>"rejected"</text></outputEntry>
<outputEntry><text>"pending review"</text></outputEntry>
```

### Boolean Literals

```xml
<outputEntry><text>true</text></outputEntry>
<outputEntry><text>false</text></outputEntry>
```

## Comparison Operators

### Greater Than or Equal (>=)

```xml
<inputEntry>
  <text>>= 18</text>
</inputEntry>
```

Matches if input value is greater than or equal to 18.

**Maps to**: `op: "gte"` in JSON rules

### Less Than or Equal (<=)

```xml
<inputEntry>
  <text><= 100</text>
</inputEntry>
```

Matches if input value is less than or equal to 100.

**Maps to**: `op: "lte"` in JSON rules

### Greater Than (>)

```xml
<inputEntry>
  <text>> 0</text>
</inputEntry>
```

Matches if input value is strictly greater than 0.

**Maps to**: `op: "gt"` in JSON rules

### Less Than (<)

```xml
<inputEntry>
  <text>< 18</text>
</inputEntry>
```

Matches if input value is strictly less than 18.

**Maps to**: `op: "lt"` in JSON rules

### Equal (=)

In FEEL, equality uses single `=`:

```xml
<inputEntry>
  <text>= 42</text>
</inputEntry>

<!-- For strings, quote the value -->
<inputEntry>
  <text>= "active"</text>
</inputEntry>
```

**Note**: When the expression is just a value without operator, it implies equality:

```xml
<!-- These are equivalent -->
<inputEntry><text>= "active"</text></inputEntry>
<inputEntry><text>"active"</text></inputEntry>
```

**Maps to**: `op: "eq"` in JSON rules

### Not Equal (!=)

**Note**: Phase 2A has limited != support. Use with caution or wait for Phase 2B.

```xml
<inputEntry>
  <text>!= "inactive"</text>
</inputEntry>
```

**Maps to**: `op: "neq"` in JSON rules

## Ranges

FEEL supports range expressions with inclusive/exclusive bounds.

### Inclusive Range

```xml
<inputEntry>
  <text>[18..65]</text>
</inputEntry>
```

Matches values from 18 to 65 (inclusive on both ends).

**Maps to**: `op: "between", value: [18, 65]` in JSON rules

### Exclusive Range

```xml
<!-- Both ends exclusive -->
<inputEntry>
  <text>(0..100)</text>
</inputEntry>

<!-- Mixed: exclusive start, inclusive end -->
<inputEntry>
  <text>(0..100]</text>
</inputEntry>

<!-- Mixed: inclusive start, exclusive end -->
<inputEntry>
  <text>[0..100)</text>
</inputEntry>
```

**Note**: Phase 2A treats all ranges as inclusive. Full range support in Phase 2B.

## Special Values

### Don't Care (-)

The hyphen `-` means "match any value" - a wildcard for that input:

```xml
<rule id="default_rule">
  <inputEntry><text>-</text></inputEntry>  <!-- Matches any age -->
  <inputEntry><text>-</text></inputEntry>  <!-- Matches any status -->
  <outputEntry><text>"review"</text></outputEntry>
</rule>
```

**Usage**: Typically in catch-all/default rules where you don't care about certain inputs.

### Null

Phase 2A has limited null support. Use `-` (don't care) for optional values.

## Usage in DMN

### In Input Entries (Conditions)

Input entries contain FEEL expressions that are evaluated against input values:

```xml
<input id="input_age" label="Age">
  <inputExpression typeRef="number">
    <text>age</text>  <!-- References context variable 'age' -->
  </inputExpression>
</input>

<rule id="adult_rule">
  <inputEntry>
    <text>>= 18</text>  <!-- FEEL: "is age >= 18?" -->
  </inputEntry>
  <outputEntry>
    <text>"adult"</text>
  </outputEntry>
</rule>
```

When evaluated with `{age: 25}`:
1. Get value of `age` → 25
2. Evaluate `>= 18` with value 25 → true
3. Rule matches!

### In Output Entries (Results)

Output entries contain FEEL expressions for the result value:

```xml
<output id="output_decision" name="decision" typeRef="string"/>

<rule id="approve_rule">
  <inputEntry><text>>= 700</text></inputEntry>
  <outputEntry>
    <text>"approved"</text>  <!-- FEEL string literal -->
  </outputEntry>
</rule>
```

**Important**: Always quote string outputs!

### In Decision Logic

FEEL expressions define the decision logic:

```xml
<decisionTable>
  <!-- Input 1: Credit score -->
  <input id="score">
    <inputExpression><text>credit_score</text></inputExpression>
  </input>

  <!-- Input 2: Income -->
  <input id="income">
    <inputExpression><text>annual_income</text></inputExpression>
  </input>

  <!-- Output: Decision -->
  <output id="decision" name="approval"/>

  <!-- Rule 1: Excellent credit -->
  <rule>
    <inputEntry><text>>= 750</text></inputEntry>  <!-- score >= 750 -->
    <inputEntry><text>>= 75000</text></inputEntry> <!-- income >= 75k -->
    <outputEntry><text>"approved"</text></outputEntry>
  </rule>

  <!-- Rule 2: Good credit -->
  <rule>
    <inputEntry><text>[650..749]</text></inputEntry> <!-- score 650-749 -->
    <inputEntry><text>>= 50000</text></inputEntry>   <!-- income >= 50k -->
    <outputEntry><text>"conditional"</text></outputEntry>
  </rule>

  <!-- Rule 3: Default reject -->
  <rule>
    <inputEntry><text>-</text></inputEntry>  <!-- Any score -->
    <inputEntry><text>-</text></inputEntry>  <!-- Any income -->
    <outputEntry><text>"rejected"</text></outputEntry>
  </rule>
</decisionTable>
```

## Examples

### Example 1: Age Verification

```xml
<decisionTable id="age_verification" hitPolicy="FIRST">
  <input id="input_age">
    <inputExpression typeRef="number">
      <text>age</text>
    </inputExpression>
  </input>

  <output id="output_category" name="category" typeRef="string"/>

  <rule id="senior">
    <inputEntry><text>>= 65</text></inputEntry>
    <outputEntry><text>"senior"</text></outputEntry>
  </rule>

  <rule id="adult">
    <inputEntry><text>>= 18</text></inputEntry>
    <outputEntry><text>"adult"</text></outputEntry>
  </rule>

  <rule id="minor">
    <inputEntry><text>< 18</text></inputEntry>
    <outputEntry><text>"minor"</text></outputEntry>
  </rule>
</decisionTable>
```

Test cases:
- `{age: 70}` → "senior"
- `{age: 30}` → "adult"
- `{age: 15}` → "minor"

### Example 2: Shipping Cost

```xml
<decisionTable id="shipping_cost" hitPolicy="FIRST">
  <input id="weight">
    <inputExpression typeRef="number">
      <text>package_weight</text>
    </inputExpression>
  </input>

  <input id="distance">
    <inputExpression typeRef="number">
      <text>distance_miles</text>
    </inputExpression>
  </input>

  <output id="method" name="shipping_method" typeRef="string"/>

  <rule id="express_light_far">
    <inputEntry><text>< 20</text></inputEntry>
    <inputEntry><text>> 1000</text></inputEntry>
    <outputEntry><text>"express_air"</text></outputEntry>
  </rule>

  <rule id="standard_medium">
    <inputEntry><text>[20..50]</text></inputEntry>
    <inputEntry><text>-</text></inputEntry>
    <outputEntry><text>"standard_ground"</text></outputEntry>
  </rule>

  <rule id="freight_heavy">
    <inputEntry><text>> 50</text></inputEntry>
    <inputEntry><text>-</text></inputEntry>
    <outputEntry><text>"freight"</text></outputEntry>
  </rule>
</decisionTable>
```

### Example 3: Risk Assessment

```xml
<decisionTable id="risk_level" hitPolicy="FIRST">
  <input id="score">
    <inputExpression typeRef="number">
      <text>risk_score</text>
    </inputExpression>
  </input>

  <output id="level" name="risk_level" typeRef="string"/>

  <rule id="low_risk">
    <inputEntry><text>< 30</text></inputEntry>
    <outputEntry><text>"low"</text></outputEntry>
  </rule>

  <rule id="medium_risk">
    <inputEntry><text>[30..70]</text></inputEntry>
    <outputEntry><text>"medium"</text></outputEntry>
  </rule>

  <rule id="high_risk">
    <inputEntry><text>> 70</text></inputEntry>
    <outputEntry><text>"high"</text></outputEntry>
  </rule>
</decisionTable>
```

## Phase 2B Preview

Phase 2B will add full FEEL 1.3 support:

### Arithmetic

```xml
<text>salary * 1.1</text>  <!-- 10% increase -->
<text>price - discount</text>
<text>quantity * unit_price</text>
```

### Logical Operators

```xml
<text>age >= 18 and status = "active"</text>
<text>score > 700 or income > 100000</text>
<text>not is_blacklisted</text>
```

### Lists

```xml
<text>["pending", "approved", "rejected"]</text>
<text>[1, 2, 3, 4, 5]</text>
```

### Functions

```xml
<text>date("2024-01-01")</text>
<text>string length(name)</text>
<text>sum([10, 20, 30])</text>
```

### Contexts

```xml
<text>{name: "John", age: 30}</text>
```

## Common Patterns

### Pattern 1: Tiered Thresholds

```xml
<!-- Excellent -->
<rule><inputEntry><text>>= 90</text></inputEntry>...</rule>

<!-- Good -->
<rule><inputEntry><text>[70..89]</text></inputEntry>...</rule>

<!-- Fair -->
<rule><inputEntry><text>[50..69]</text></inputEntry>...</rule>

<!-- Poor -->
<rule><inputEntry><text>< 50</text></inputEntry>...</rule>
```

### Pattern 2: Category Matching

```xml
<!-- VIP tier -->
<rule><inputEntry><text>= "platinum"</text></inputEntry>...</rule>

<!-- Standard tier -->
<rule><inputEntry><text>= "gold"</text></inputEntry>...</rule>

<!-- Basic tier -->
<rule><inputEntry><text>-</text></inputEntry>...</rule>
```

### Pattern 3: Range with Don't Care

```xml
<!-- Young adults with any income -->
<rule>
  <inputEntry><text>[18..25]</text></inputEntry>
  <inputEntry><text>-</text></inputEntry>
  ...
</rule>

<!-- Any age with high income -->
<rule>
  <inputEntry><text>-</text></inputEntry>
  <inputEntry><text>> 100000</text></inputEntry>
  ...
</rule>
```

## Troubleshooting

### Problem: Empty decision after round-trip

**Symptom**: Decision value is empty string after export/import

**Cause**: Missing quotes on string output

**Solution**:
```xml
<!-- Wrong -->
<outputEntry><text>approved</text></outputEntry>

<!-- Correct -->
<outputEntry><text>"approved"</text></outputEntry>
```

### Problem: Input never matches

**Symptom**: Rules with valid conditions don't match

**Cause**: Input expression doesn't match context key

**Solution**:
```xml
<input>
  <inputExpression>
    <text>age</text>  <!-- Must match context key exactly -->
  </inputExpression>
</input>
```

```ruby
# Context must have matching key
context = DecisionAgent::Context.new(age: 25)  # ✓ Matches
context = DecisionAgent::Context.new(Age: 25)  # ✗ Won't match
```

### Problem: Range not working

**Symptom**: Range expressions don't match expected values

**Cause**: Phase 2A range support is basic

**Workaround**: Use explicit comparisons:
```xml
<!-- Instead of exclusive range -->
<inputEntry><text>(0..100)</text></inputEntry>

<!-- Use: -->
<inputEntry><text>> 0 and < 100</text></inputEntry>  <!-- Phase 2B -->

<!-- Or split into rules -->
<rule>
  <inputEntry><text>> 0</text></inputEntry>
  ...
</rule>
<rule>
  <inputEntry><text>< 100</text></inputEntry>
  ...
</rule>
```

### Problem: Special characters in XML

**Symptom**: `<` or `>` causes XML parsing errors

**Cause**: `<` and `>` must be escaped in XML

**Solution**:
```xml
<!-- Use XML entities -->
<inputEntry><text>&lt; 18</text></inputEntry>   <!-- < -->
<inputEntry><text>&gt;= 65</text></inputEntry>  <!-- >= -->
<inputEntry><text>&lt;= 100</text></inputEntry> <!-- <= -->

<!-- Or use CDATA (not recommended for FEEL) -->
<inputEntry><![CDATA[< 18]]></inputEntry>
```

## Resources

- [DMN 1.3 Specification - FEEL](https://www.omg.org/spec/DMN/1.3/)
- [FEEL Tutorial](https://docs.camunda.org/manual/latest/reference/dmn/feel/)
- [DMN Guide](DMN_GUIDE.md)
- [DMN API Reference](DMN_API.md)
- [Examples](../examples/dmn/)

## Quick Reference

| Expression | Meaning | Phase 2A | Example |
|------------|---------|----------|---------|
| `>= 18` | Greater or equal | ✅ | Age check |
| `<= 100` | Less or equal | ✅ | Max value |
| `> 0` | Greater than | ✅ | Positive |
| `< 18` | Less than | ✅ | Minor |
| `[18..65]` | Range (inclusive) | ✅ | Working age |
| `"approved"` | String literal | ✅ | Status |
| `42` | Number literal | ✅ | Age |
| `true` | Boolean | ✅ | Flag |
| `-` | Don't care | ✅ | Any value |
| `and`, `or` | Logic | 🔄 Phase 2B | Conditions |
| `+`, `-`, `*` | Arithmetic | 🔄 Phase 2B | Calculations |
| `date()` | Functions | 🔄 Phase 2B | Dates |
