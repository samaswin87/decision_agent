# Advanced Rule DSL Operators

This document describes the advanced operators available in the Decision Agent Rule DSL. These operators extend the basic comparison operators (`eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `in`, `present`, `blank`) with specialized functionality for strings, numbers, dates, collections, and geospatial data.

## Table of Contents

- [String Operators](#string-operators)
- [Numeric Operators](#numeric-operators)
- [Mathematical Operators](#mathematical-operators)
  - [Trigonometric Functions](#trigonometric-functions)
  - [Inverse Trigonometric Functions](#inverse-trigonometric-functions)
  - [Hyperbolic Functions](#hyperbolic-functions)
  - [Power and Root Functions](#power-and-root-functions)
  - [Logarithmic Functions](#logarithmic-functions)
  - [Rounding Functions](#rounding-functions)
  - [Advanced Mathematical Functions](#advanced-mathematical-functions)
- [Statistical Aggregations](#statistical-aggregations)
- [Date/Time Operators](#datetime-operators)
- [Collection Operators](#collection-operators)
- [Geospatial Operators](#geospatial-operators)
- [Examples](#examples)

---

## String Operators

### `contains`

Checks if a string contains a substring (case-sensitive).

**Syntax:**
```json
{
  "field": "message",
  "op": "contains",
  "value": "error"
}
```

**Example:**
```json
{
  "version": "1.0",
  "ruleset": "error_detection",
  "rules": [
    {
      "id": "error_alert",
      "if": {
        "field": "log_message",
        "op": "contains",
        "value": "ERROR"
      },
      "then": {
        "decision": "send_alert",
        "weight": 0.9,
        "reason": "Error detected in log message"
      }
    }
  ]
}
```

**Behavior:**
- Case-sensitive matching
- Both field and value must be strings
- Returns `false` if field is not a string

---

### `starts_with`

Checks if a string starts with a specified prefix (case-sensitive).

**Syntax:**
```json
{
  "field": "error_code",
  "op": "starts_with",
  "value": "ERR"
}
```

**Example:**
```json
{
  "field": "transaction_id",
  "op": "starts_with",
  "value": "TXN-"
}
```

**Behavior:**
- Case-sensitive matching
- Both field and value must be strings

---

### `ends_with`

Checks if a string ends with a specified suffix (case-sensitive).

**Syntax:**
```json
{
  "field": "filename",
  "op": "ends_with",
  "value": ".pdf"
}
```

**Example:**
```json
{
  "id": "pdf_processor",
  "if": {
    "field": "document.filename",
    "op": "ends_with",
    "value": ".pdf"
  },
  "then": {
    "decision": "route_to_pdf_processor",
    "weight": 1.0
  }
}
```

**Behavior:**
- Case-sensitive matching
- Both field and value must be strings

---

### `matches`

Matches a string against a regular expression pattern.

**Syntax:**
```json
{
  "field": "email",
  "op": "matches",
  "value": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
}
```

**Example:**
```json
{
  "id": "validate_email",
  "if": {
    "field": "user.email",
    "op": "matches",
    "value": "^[a-z0-9._%+-]+@company\\.com$"
  },
  "then": {
    "decision": "employee_email",
    "weight": 1.0,
    "reason": "Email is from company domain"
  }
}
```

**Behavior:**
- Value can be a regex string or Regexp object
- Invalid regex patterns return `false` (fail-safe)
- Field must be a string

**Common Patterns:**
- Email: `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$`
- Phone (US): `^\\(\\d{3}\\)\\s?\\d{3}-\\d{4}$`
- UUID: `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`
- IP Address: `^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$`

---

## Numeric Operators

### `between`

Checks if a numeric value is between a minimum and maximum value (inclusive).

**Syntax (Array Format):**
```json
{
  "field": "age",
  "op": "between",
  "value": [18, 65]
}
```

**Syntax (Hash Format):**
```json
{
  "field": "score",
  "op": "between",
  "value": { "min": 0, "max": 100 }
}
```

**Example:**
```json
{
  "id": "age_verification",
  "if": {
    "field": "applicant.age",
    "op": "between",
    "value": [21, 70]
  },
  "then": {
    "decision": "eligible",
    "weight": 0.9,
    "reason": "Applicant age is within acceptable range"
  }
}
```

**Behavior:**
- Boundary values are included (closed interval)
- Field must be numeric
- Supports both integer and floating-point numbers

---

### `modulo`

Checks if a value modulo a divisor equals a specified remainder.

**Syntax (Array Format):**
```json
{
  "field": "order_id",
  "op": "modulo",
  "value": [2, 0]
}
```

**Syntax (Hash Format):**
```json
{
  "field": "customer_id",
  "op": "modulo",
  "value": { "divisor": 10, "remainder": 5 }
}
```

**Example - Even Numbers:**
```json
{
  "id": "even_id_routing",
  "if": {
    "field": "user_id",
    "op": "modulo",
    "value": [2, 0]
  },
  "then": {
    "decision": "route_to_server_a",
    "weight": 1.0,
    "reason": "Route even user IDs to server A"
  }
}
```

**Example - A/B Testing:**
```json
{
  "id": "ab_test_variant_b",
  "if": {
    "field": "session_id",
    "op": "modulo",
    "value": { "divisor": 3, "remainder": 1 }
  },
  "then": {
    "decision": "show_variant_b",
    "weight": 1.0
  }
}
```

**Use Cases:**
- A/B testing distribution
- Load balancing
- Sharding logic
- Identifying patterns (even/odd numbers)

---

## Mathematical Operators

DecisionAgent provides a comprehensive set of mathematical operators for advanced calculations including trigonometric, logarithmic, power, and rounding functions.

### Trigonometric Functions

#### `sin`

Calculates the sine of a value (in radians).

**Syntax:**
```json
{
  "field": "angle",
  "op": "sin",
  "value": 0.0
}
```

**Example:**
```json
{
  "id": "zero_crossing",
  "if": {
    "field": "signal_phase",
    "op": "sin",
    "value": 0.0
  },
  "then": {
    "decision": "zero_crossing_detected",
    "weight": 1.0,
    "reason": "Sine value is zero (crossing point)"
  }
}
```

**Behavior:**
- Field value is interpreted as radians
- Uses epsilon comparison for floating-point precision
- Returns `false` if field is not numeric

**Mathematical Properties:**
- `sin(0) = 0.0`
- `sin(π/2) = 1.0`
- `sin(π) = 0.0`
- Range: [-1, 1]

---

#### `cos`

Calculates the cosine of a value (in radians).

**Syntax:**
```json
{
  "field": "angle",
  "op": "cos",
  "value": 1.0
}
```

**Example:**
```json
{
  "id": "phase_alignment",
  "if": {
    "field": "waveform_phase",
    "op": "cos",
    "value": 1.0
  },
  "then": {
    "decision": "in_phase",
    "weight": 0.95
  }
}
```

**Mathematical Properties:**
- `cos(0) = 1.0`
- `cos(π/2) = 0.0`
- `cos(π) = -1.0`
- Range: [-1, 1]

---

#### `tan`

Calculates the tangent of a value (in radians).

**Syntax:**
```json
{
  "field": "angle",
  "op": "tan",
  "value": 0.0
}
```

**Example:**
```json
{
  "id": "horizontal_slope",
  "if": {
    "field": "line_angle",
    "op": "tan",
    "value": 0.0
  },
  "then": {
    "decision": "horizontal_line",
    "weight": 1.0
  }
}
```

**Mathematical Properties:**
- `tan(0) = 0.0`
- `tan(π/4) = 1.0`
- Undefined at `π/2 + nπ` (where n is an integer)

---

### Inverse Trigonometric Functions

#### `asin`

Calculates the arcsine (inverse sine) of a value. Returns result in radians.

**Syntax:**
```json
{
  "field": "value",
  "op": "asin",
  "value": 1.5707963267948966
}
```

**Example:**
```json
{
  "id": "angle_from_sine",
  "if": {
    "field": "sine_value",
    "op": "asin",
    "value": 1.5707963267948966
  },
  "then": {
    "decision": "right_angle",
    "weight": 1.0,
    "reason": "Angle is π/2 radians (90 degrees)"
  }
}
```

**Behavior:**
- Input must be in range [-1, 1]
- Returns `false` if input is outside valid domain
- Output range: [-π/2, π/2]

**Mathematical Properties:**
- `asin(1) = π/2 ≈ 1.571`
- `asin(0) = 0`
- `asin(-1) = -π/2`

---

#### `acos`

Calculates the arccosine (inverse cosine) of a value. Returns result in radians.

**Syntax:**
```json
{
  "field": "value",
  "op": "acos",
  "value": 0.0
}
```

**Example:**
```json
{
  "id": "angle_from_cosine",
  "if": {
    "field": "cosine_value",
    "op": "acos",
    "value": 0.0
  },
  "then": {
    "decision": "right_angle",
    "weight": 1.0
  }
}
```

**Behavior:**
- Input must be in range [-1, 1]
- Returns `false` if input is outside valid domain
- Output range: [0, π]

**Mathematical Properties:**
- `acos(1) = 0`
- `acos(0) = π/2 ≈ 1.571`
- `acos(-1) = π ≈ 3.142`

---

#### `atan`

Calculates the arctangent (inverse tangent) of a value. Returns result in radians.

**Syntax:**
```json
{
  "field": "value",
  "op": "atan",
  "value": 0.7853981633974483
}
```

**Example:**
```json
{
  "id": "angle_from_slope",
  "if": {
    "field": "slope",
    "op": "atan",
    "value": 0.7853981633974483
  },
  "then": {
    "decision": "diagonal_line",
    "weight": 1.0,
    "reason": "Angle is π/4 radians (45 degrees)"
  }
}
```

**Mathematical Properties:**
- `atan(0) = 0`
- `atan(1) = π/4 ≈ 0.785`
- `atan(-1) = -π/4`
- Output range: [-π/2, π/2]

---

#### `atan2`

Calculates the arctangent of y/x. Returns result in radians, handling all quadrants correctly.

**Syntax (Hash Format):**
```json
{
  "field": "x",
  "op": "atan2",
  "value": {
    "y": 1,
    "result": 0.7853981633974483
  }
}
```

**Syntax (Array Format):**
```json
{
  "field": "x",
  "op": "atan2",
  "value": [1, 0.7853981633974483]
}
```

**Example:**
```json
{
  "id": "angle_from_coordinates",
  "if": {
    "field": "point_x",
    "op": "atan2",
    "value": {
      "y": 1,
      "result": 0.7853981633974483
    }
  },
  "then": {
    "decision": "diagonal_quadrant",
    "weight": 1.0
  }
}
```

**Behavior:**
- Calculates `atan2(field_value, y)`
- Handles all four quadrants correctly (unlike `atan`)
- Output range: [-π, π]

**Use Cases:**
- Converting Cartesian coordinates to polar coordinates
- Determining angle between points
- Robot navigation and path planning

---

### Hyperbolic Functions

#### `sinh`

Calculates the hyperbolic sine of a value.

**Syntax:**
```json
{
  "field": "value",
  "op": "sinh",
  "value": 0.0
}
```

**Example:**
```json
{
  "id": "hyperbolic_zero",
  "if": {
    "field": "hyperbolic_parameter",
    "op": "sinh",
    "value": 0.0
  },
  "then": {
    "decision": "symmetric_point",
    "weight": 1.0
  }
}
```

**Mathematical Properties:**
- `sinh(0) = 0.0`
- `sinh(1) ≈ 1.175`
- Odd function: `sinh(-x) = -sinh(x)`

---

#### `cosh`

Calculates the hyperbolic cosine of a value.

**Syntax:**
```json
{
  "field": "value",
  "op": "cosh",
  "value": 1.0
}
```

**Example:**
```json
{
  "id": "hyperbolic_base",
  "if": {
    "field": "hyperbolic_parameter",
    "op": "cosh",
    "value": 1.0
  },
  "then": {
    "decision": "base_case",
    "weight": 1.0
  }
}
```

**Mathematical Properties:**
- `cosh(0) = 1.0`
- `cosh(1) ≈ 1.543`
- Even function: `cosh(-x) = cosh(x)`
- Always ≥ 1.0

---

#### `tanh`

Calculates the hyperbolic tangent of a value.

**Syntax:**
```json
{
  "field": "value",
  "op": "tanh",
  "value": 0.0
}
```

**Example:**
```json
{
  "id": "sigmoid_center",
  "if": {
    "field": "activation_value",
    "op": "tanh",
    "value": 0.0
  },
  "then": {
    "decision": "neutral_activation",
    "weight": 0.9
  }
}
```

**Mathematical Properties:**
- `tanh(0) = 0.0`
- `tanh(1) ≈ 0.762`
- Range: (-1, 1)
- Used in machine learning as activation function

---

### Power and Root Functions

#### `sqrt`

Calculates the square root of a value.

**Syntax:**
```json
{
  "field": "number",
  "op": "sqrt",
  "value": 3.0
}
```

**Example:**
```json
{
  "id": "distance_calculation",
  "if": {
    "field": "squared_distance",
    "op": "sqrt",
    "value": 5.0
  },
  "then": {
    "decision": "within_range",
    "weight": 0.9,
    "reason": "Distance is 5 units"
  }
}
```

**Behavior:**
- Returns `false` if field is negative
- Uses epsilon comparison for floating-point precision

**Mathematical Properties:**
- `sqrt(0) = 0.0`
- `sqrt(1) = 1.0`
- `sqrt(4) = 2.0`
- `sqrt(9) = 3.0`

---

#### `cbrt`

Calculates the cube root of a value.

**Syntax:**
```json
{
  "field": "number",
  "op": "cbrt",
  "value": 2.0
}
```

**Example:**
```json
{
  "id": "volume_dimension",
  "if": {
    "field": "cubed_volume",
    "op": "cbrt",
    "value": 3.0
  },
  "then": {
    "decision": "standard_size",
    "weight": 1.0
  }
}
```

**Behavior:**
- Works with both positive and negative values
- `cbrt(-8) = -2.0`
- `cbrt(8) = 2.0`

**Mathematical Properties:**
- `cbrt(0) = 0.0`
- `cbrt(1) = 1.0`
- `cbrt(8) = 2.0`
- `cbrt(27) = 3.0`

---

#### `power`

Raises a value to a specified exponent.

**Syntax (Hash Format):**
```json
{
  "field": "base",
  "op": "power",
  "value": {
    "exponent": 2,
    "result": 4
  }
}
```

**Syntax (Array Format):**
```json
{
  "field": "base",
  "op": "power",
  "value": [2, 4]
}
```

**Example:**
```json
{
  "id": "square_check",
  "if": {
    "field": "number",
    "op": "power",
    "value": {
      "exponent": 2,
      "result": 16
    }
  },
  "then": {
    "decision": "perfect_square",
    "weight": 1.0,
    "reason": "Number squared equals 16"
  }
}
```

**Mathematical Properties:**
- Checks if `field^exponent == result`
- Uses epsilon comparison for floating-point precision
- Works with fractional exponents: `8^(1/3) = 2.0`

**Use Cases:**
- Checking perfect squares/cubes
- Validating exponential relationships
- Scientific calculations

---

#### `exp`

Calculates e raised to the power of a value (exponential function).

**Syntax:**
```json
{
  "field": "exponent",
  "op": "exp",
  "value": 2.718281828459045
}
```

**Example:**
```json
{
  "id": "e_power_check",
  "if": {
    "field": "growth_rate",
    "op": "exp",
    "value": 2.718281828459045
  },
  "then": {
    "decision": "natural_growth",
    "weight": 1.0,
    "reason": "Value is e^1 (natural exponential)"
  }
}
```

**Mathematical Properties:**
- `exp(0) = 1.0`
- `exp(1) = e ≈ 2.718`
- `exp(2) ≈ 7.389`
- Always positive: `exp(x) > 0` for all x

**Use Cases:**
- Exponential growth/decay models
- Compound interest calculations
- Probability distributions

---

### Logarithmic Functions

#### `log`

Calculates the natural logarithm (base e) of a value.

**Syntax:**
```json
{
  "field": "number",
  "op": "log",
  "value": 0.0
}
```

**Example:**
```json
{
  "id": "logarithmic_check",
  "if": {
    "field": "ratio",
    "op": "log",
    "value": 0.0
  },
  "then": {
    "decision": "unit_ratio",
    "weight": 1.0,
    "reason": "log(1) = 0"
  }
}
```

**Behavior:**
- Returns `false` if field ≤ 0
- Natural logarithm uses base e

**Mathematical Properties:**
- `log(1) = 0.0`
- `log(e) = 1.0`
- `log(10) ≈ 2.303`
- Domain: (0, ∞)

---

#### `log10`

Calculates the base-10 logarithm of a value.

**Syntax:**
```json
{
  "field": "number",
  "op": "log10",
  "value": 2.0
}
```

**Example:**
```json
{
  "id": "order_of_magnitude",
  "if": {
    "field": "magnitude",
    "op": "log10",
    "value": 3.0
  },
  "then": {
    "decision": "thousands",
    "weight": 1.0,
    "reason": "Value is in thousands (10^3)"
  }
}
```

**Mathematical Properties:**
- `log10(1) = 0.0`
- `log10(10) = 1.0`
- `log10(100) = 2.0`
- `log10(1000) = 3.0`

**Use Cases:**
- Order of magnitude calculations
- Decibel (dB) calculations
- Scientific notation

---

#### `log2`

Calculates the base-2 logarithm of a value.

**Syntax:**
```json
{
  "field": "number",
  "op": "log2",
  "value": 3.0
}
```

**Example:**
```json
{
  "id": "binary_power",
  "if": {
    "field": "data_size",
    "op": "log2",
    "value": 10.0
  },
  "then": {
    "decision": "kilobyte_range",
    "weight": 1.0,
    "reason": "Value is 2^10 = 1024 bytes (1KB)"
  }
}
```

**Mathematical Properties:**
- `log2(1) = 0.0`
- `log2(2) = 1.0`
- `log2(4) = 2.0`
- `log2(8) = 3.0`
- `log2(16) = 4.0`

**Use Cases:**
- Binary tree depth calculations
- Information theory (entropy, bits)
- Computer science algorithms

---

### Rounding Functions

#### `round`

Rounds a value to the nearest integer.

**Syntax:**
```json
{
  "field": "value",
  "op": "round",
  "value": 3
}
```

**Example:**
```json
{
  "id": "rounded_value",
  "if": {
    "field": "calculated_score",
    "op": "round",
    "value": 85
  },
  "then": {
    "decision": "high_score",
    "weight": 0.9
  }
}
```

**Behavior:**
- Rounds to nearest integer
- `round(3.4) = 3`
- `round(3.6) = 4`
- Uses standard rounding rules (round half up)

---

#### `floor`

Rounds a value down to the nearest integer.

**Syntax:**
```json
{
  "field": "value",
  "op": "floor",
  "value": 3
}
```

**Example:**
```json
{
  "id": "whole_units",
  "if": {
    "field": "fractional_count",
    "op": "floor",
    "value": 10
  },
  "then": {
    "decision": "minimum_quantity",
    "weight": 1.0
  }
}
```

**Behavior:**
- Always rounds down
- `floor(3.9) = 3`
- `floor(-3.1) = -4`
- Returns largest integer ≤ value

**Use Cases:**
- Pricing calculations
- Quantity calculations
- Time-based discounts

---

#### `ceil`

Rounds a value up to the nearest integer.

**Syntax:**
```json
{
  "field": "value",
  "op": "ceil",
  "value": 4
}
```

**Example:**
```json
{
  "id": "capacity_check",
  "if": {
    "field": "required_capacity",
    "op": "ceil",
    "value": 5
  },
  "then": {
    "decision": "sufficient_capacity",
    "weight": 1.0
  }
}
```

**Behavior:**
- Always rounds up
- `ceil(3.1) = 4`
- `ceil(-3.9) = -3`
- Returns smallest integer ≥ value

**Use Cases:**
- Resource allocation
- Container sizing
- Buffer calculations

---

#### `truncate`

Truncates (removes decimal part) of a value.

**Syntax:**
```json
{
  "field": "value",
  "op": "truncate",
  "value": 3
}
```

**Example:**
```json
{
  "id": "integer_part",
  "if": {
    "field": "measurement",
    "op": "truncate",
    "value": 5
  },
  "then": {
    "decision": "whole_number",
    "weight": 1.0
  }
}
```

**Behavior:**
- Removes decimal part without rounding
- `truncate(3.9) = 3`
- `truncate(-3.9) = -3`
- Moves toward zero

**Use Cases:**
- Integer extraction
- Precision control
- Data type conversion

---

#### `abs`

Calculates the absolute value of a number.

**Syntax:**
```json
{
  "field": "value",
  "op": "abs",
  "value": 5
}
```

**Example:**
```json
{
  "id": "absolute_deviation",
  "if": {
    "field": "deviation",
    "op": "abs",
    "value": 10
  },
  "then": {
    "decision": "within_tolerance",
    "weight": 0.9,
    "reason": "Absolute deviation is within 10"
  }
}
```

**Behavior:**
- Always returns non-negative value
- `abs(5) = 5`
- `abs(-5) = 5`
- `abs(0) = 0`

**Use Cases:**
- Error calculations
- Distance calculations
- Magnitude comparisons

---

### Advanced Mathematical Functions

#### `factorial`

Calculates the factorial of a non-negative integer.

**Syntax:**
```json
{
  "field": "number",
  "op": "factorial",
  "value": 120
}
```

**Example:**
```json
{
  "id": "permutation_check",
  "if": {
    "field": "items_count",
    "op": "factorial",
    "value": 24
  },
  "then": {
    "decision": "four_items",
    "weight": 1.0,
    "reason": "4! = 24 permutations possible"
  }
}
```

**Behavior:**
- Field must be a non-negative integer
- Returns `false` if field is negative or not an integer
- `factorial(0) = 1`
- `factorial(5) = 120`

**Mathematical Properties:**
- `factorial(0) = 1`
- `factorial(1) = 1`
- `factorial(5) = 120`
- `factorial(6) = 720`

**Use Cases:**
- Combinatorics
- Permutation calculations
- Probability calculations

---

#### `gcd`

Calculates the Greatest Common Divisor (GCD) of two integers.

**Syntax (Hash Format):**
```json
{
  "field": "a",
  "op": "gcd",
  "value": {
    "other": 12,
    "result": 6
  }
}
```

**Syntax (Array Format):**
```json
{
  "field": "a",
  "op": "gcd",
  "value": [12, 6]
}
```

**Example:**
```json
{
  "id": "common_divisor",
  "if": {
    "field": "number_a",
    "op": "gcd",
    "value": {
      "other": 24,
      "result": 12
    }
  },
  "then": {
    "decision": "has_common_factor",
    "weight": 1.0,
    "reason": "GCD of 36 and 24 is 12"
  }
}
```

**Behavior:**
- Both field and `other` must be integers
- Calculates `gcd(field, other)`
- Uses Euclidean algorithm

**Mathematical Properties:**
- `gcd(18, 12) = 6`
- `gcd(17, 13) = 1` (coprime)
- `gcd(a, 0) = |a|`
- `gcd(a, a) = |a|`

**Use Cases:**
- Fraction simplification
- Cryptography
- Algorithm design

---

#### `lcm`

Calculates the Least Common Multiple (LCM) of two integers.

**Syntax (Hash Format):**
```json
{
  "field": "a",
  "op": "lcm",
  "value": {
    "other": 12,
    "result": 36
  }
}
```

**Syntax (Array Format):**
```json
{
  "field": "a",
  "op": "lcm",
  "value": [12, 36]
}
```

**Example:**
```json
{
  "id": "synchronization_point",
  "if": {
    "field": "cycle_a",
    "op": "lcm",
    "value": {
      "other": 12,
      "result": 36
    }
  },
  "then": {
    "decision": "aligned_cycles",
    "weight": 1.0,
    "reason": "Cycles align every 36 units"
  }
}
```

**Behavior:**
- Both field and `other` must be integers
- Calculates `lcm(field, other)`
- Relationship: `lcm(a, b) = |a * b| / gcd(a, b)`

**Mathematical Properties:**
- `lcm(9, 12) = 36`
- `lcm(4, 6) = 12`
- `lcm(a, 0) = 0`
- `lcm(a, a) = |a|`

**Use Cases:**
- Periodic event synchronization
- Fraction addition
- Recurring schedule calculations

---

### Precision and Error Handling

All mathematical operators use **epsilon comparison** for floating-point values to handle precision issues:

- Default epsilon: `1e-10`
- Prevents false negatives due to floating-point representation
- Ensures accurate comparisons for trigonometric, logarithmic, and exponential functions

**Example of Epsilon Comparison:**
```ruby
# Instead of: Math.sin(0) == 0.0  (might fail due to precision)
# Uses: epsilon_equal?(Math.sin(0), 0.0)  (handles floating-point precision)
```

---

### Common Mathematical Patterns

**Pythagorean Theorem Check:**
```json
{
  "all": [
    { "field": "a_squared", "op": "sqrt", "value": 3.0 },
    { "field": "b_squared", "op": "sqrt", "value": 4.0 },
    { "field": "c_squared", "op": "sqrt", "value": 5.0 }
  ]
}
```

**Exponential Growth Model:**
```json
{
  "field": "time",
  "op": "exp",
  "value": { "lt": 1000.0 }
}
```

**Logarithmic Scale Check:**
```json
{
  "field": "magnitude",
  "op": "log10",
  "value": { "gte": 2.0, "lte": 4.0 }
}
```

**Angle Validation:**
```json
{
  "all": [
    { "field": "angle_radians", "op": "sin", "value": { "gte": -1.0, "lte": 1.0 } },
    { "field": "angle_radians", "op": "cos", "value": { "gte": -1.0, "lte": 1.0 } }
  ]
}
```

---

## Statistical Aggregations

### `sum`

Calculates the sum of numeric array elements.

**Syntax:**
```json
{
  "field": "transaction.amounts",
  "op": "sum",
  "value": 1000
}
```

**Syntax (with comparison):**
```json
{
  "field": "prices",
  "op": "sum",
  "value": { "min": 50, "max": 150 }
}
```

**Example:**
```json
{
  "id": "total_amount_check",
  "if": {
    "field": "order.items.prices",
    "op": "sum",
    "value": { "gte": 100 }
  },
  "then": {
    "decision": "free_shipping",
    "weight": 1.0,
    "reason": "Order total exceeds $100"
  }
}
```

**Behavior:**
- Field must be an array
- Only numeric values are included in calculation
- Returns `false` if array is empty or contains no numeric values
- Supports direct comparison or hash with comparison operators (`min`, `max`, `gt`, `lt`, `gte`, `lte`, `eq`)

---

### `average` / `mean`

Calculates the average (mean) of numeric array elements.

**Syntax:**
```json
{
  "field": "response_times",
  "op": "average",
  "value": 150
}
```

**Example:**
```json
{
  "id": "latency_check",
  "if": {
    "field": "api.response_times",
    "op": "average",
    "value": { "lt": 200 }
  },
  "then": {
    "decision": "acceptable_latency",
    "weight": 0.9
  }
}
```

---

### `median`

Calculates the median value of a numeric array.

**Syntax:**
```json
{
  "field": "scores",
  "op": "median",
  "value": 75
}
```

**Example:**
```json
{
  "id": "median_score_check",
  "if": {
    "field": "test.scores",
    "op": "median",
    "value": { "gte": 70 }
  },
  "then": {
    "decision": "passing_grade",
    "weight": 0.8
  }
}
```

---

### `stddev` / `standard_deviation`

Calculates the standard deviation of a numeric array.

**Syntax:**
```json
{
  "field": "latencies",
  "op": "stddev",
  "value": { "lt": 50 }
}
```

**Example:**
```json
{
  "id": "consistency_check",
  "if": {
    "field": "performance.metrics",
    "op": "stddev",
    "value": { "lt": 25 }
  },
  "then": {
    "decision": "stable_performance",
    "weight": 0.9
  }
}
```

**Behavior:**
- Requires at least 2 numeric values
- Returns `false` if array has fewer than 2 numeric elements

---

### `variance`

Calculates the variance of a numeric array.

**Syntax:**
```json
{
  "field": "scores",
  "op": "variance",
  "value": { "lt": 100 }
}
```

---

### `percentile`

Calculates the Nth percentile of a numeric array.

**Syntax:**
```json
{
  "field": "response_times",
  "op": "percentile",
  "value": { "percentile": 95, "threshold": 200 }
}
```

**Example:**
```json
{
  "id": "p95_latency_alert",
  "if": {
    "field": "api.response_times",
    "op": "percentile",
    "value": { "percentile": 95, "gt": 500 }
  },
  "then": {
    "decision": "high_latency_alert",
    "weight": 0.95
  }
}
```

**Supported Parameters:**
- `percentile`: Number between 0-100 (required)
- `threshold`: Direct comparison value
- `gt`, `lt`, `gte`, `lte`, `eq`: Comparison operators

---

### `count`

Counts the number of elements in an array.

**Syntax:**
```json
{
  "field": "errors",
  "op": "count",
  "value": { "gte": 10 }
}
```

**Example:**
```json
{
  "id": "error_threshold",
  "if": {
    "field": "recent_errors",
    "op": "count",
    "value": { "gte": 5 }
  },
  "then": {
    "decision": "alert_required",
    "weight": 1.0
  }
}
```

---

## Date/Time Operators

All date/time operators accept dates in multiple formats:
- ISO 8601 strings: `"2025-12-31"` or `"2025-12-31T23:59:59Z"`
- Ruby Time objects
- Ruby Date objects
- Ruby DateTime objects

### `before_date`

Checks if a date is before a specified date.

**Syntax:**
```json
{
  "field": "expires_at",
  "op": "before_date",
  "value": "2026-01-01"
}
```

**Example:**
```json
{
  "id": "check_expiration",
  "if": {
    "field": "license.expires_at",
    "op": "before_date",
    "value": "2025-12-31"
  },
  "then": {
    "decision": "license_valid",
    "weight": 0.8,
    "reason": "License has not expired"
  }
}
```

---

### `after_date`

Checks if a date is after a specified date.

**Syntax:**
```json
{
  "field": "created_at",
  "op": "after_date",
  "value": "2024-01-01"
}
```

**Example:**
```json
{
  "id": "recent_account",
  "if": {
    "field": "account.created_at",
    "op": "after_date",
    "value": "2024-06-01"
  },
  "then": {
    "decision": "new_user_promotion",
    "weight": 0.9,
    "reason": "Account created recently"
  }
}
```

---

### `within_days`

Checks if a date is within N days from the current time (past or future).

**Syntax:**
```json
{
  "field": "event_date",
  "op": "within_days",
  "value": 7
}
```

**Example:**
```json
{
  "id": "upcoming_event_reminder",
  "if": {
    "field": "appointment.scheduled_at",
    "op": "within_days",
    "value": 3
  },
  "then": {
    "decision": "send_reminder",
    "weight": 1.0,
    "reason": "Appointment is within 3 days"
  }
}
```

**Behavior:**
- Calculates absolute difference (works for both past and future dates)
- Value is the number of days
- Uses current time as reference point

---

### `day_of_week`

Checks if a date falls on a specified day of the week.

**Syntax (String Format):**
```json
{
  "field": "delivery_date",
  "op": "day_of_week",
  "value": "monday"
}
```

**Syntax (Numeric Format):**
```json
{
  "field": "delivery_date",
  "op": "day_of_week",
  "value": 1
}
```

**Example:**
```json
{
  "id": "weekend_pricing",
  "if": {
    "any": [
      { "field": "booking_date", "op": "day_of_week", "value": "saturday" },
      { "field": "booking_date", "op": "day_of_week", "value": "sunday" }
    ]
  },
  "then": {
    "decision": "apply_weekend_discount",
    "weight": 1.0,
    "reason": "Weekend booking discount"
  }
}
```

**Supported Values:**
- **Strings:** `"sunday"`, `"monday"`, `"tuesday"`, `"wednesday"`, `"thursday"`, `"friday"`, `"saturday"`
- **Abbreviations:** `"sun"`, `"mon"`, `"tue"`, `"wed"`, `"thu"`, `"fri"`, `"sat"`
- **Numbers:** `0` (Sunday) through `6` (Saturday)

---

## Duration Calculations

### `duration_seconds`

Calculates the duration between two dates in seconds.

**Syntax:**
```json
{
  "field": "session.start_time",
  "op": "duration_seconds",
  "value": { "end": "now", "max": 3600 }
}
```

**Example:**
```json
{
  "id": "session_timeout",
  "if": {
    "field": "session.last_activity",
    "op": "duration_seconds",
    "value": { "end": "now", "gt": 1800 }
  },
  "then": {
    "decision": "session_expired",
    "weight": 1.0
  }
}
```

**Parameters:**
- `end`: `"now"` or a field path (e.g., `"session.end_time"`)
- `min`, `max`, `gt`, `lt`, `gte`, `lte`: Comparison operators

---

### `duration_minutes`, `duration_hours`, `duration_days`

Similar to `duration_seconds` but returns duration in minutes, hours, or days respectively.

**Example:**
```json
{
  "field": "order.created_at",
  "op": "duration_hours",
  "value": { "end": "now", "gte": 24 }
}
```

---

## Date Arithmetic

### `add_days`

Adds days to a date and compares the result.

**Syntax:**
```json
{
  "field": "order.created_at",
  "op": "add_days",
  "value": { "days": 7, "compare": "lt", "target": "now" }
}
```

**Example:**
```json
{
  "id": "trial_expiring_soon",
  "if": {
    "field": "trial.started_at",
    "op": "add_days",
    "value": { "days": 7, "compare": "lte", "target": "now" }
  },
  "then": {
    "decision": "trial_expiring",
    "weight": 0.9
  }
}
```

**Parameters:**
- `days`: Number of days to add
- `target`: `"now"` or a field path
- `compare`: Comparison operator (`"eq"`, `"gt"`, `"lt"`, `"gte"`, `"lte"`)
- Or use direct operators: `eq`, `gt`, `lt`, `gte`, `lte`

---

### `subtract_days`, `add_hours`, `subtract_hours`, `add_minutes`, `subtract_minutes`

Similar to `add_days` but for subtracting days or adding/subtracting hours/minutes.

**Example:**
```json
{
  "field": "deadline",
  "op": "subtract_hours",
  "value": { "hours": 1, "compare": "gt", "target": "now" }
}
```

---

## Time Component Extraction

### `hour_of_day`

Extracts the hour of day (0-23) from a date.

**Syntax:**
```json
{
  "field": "event.timestamp",
  "op": "hour_of_day",
  "value": { "min": 9, "max": 17 }
}
```

**Example:**
```json
{
  "id": "business_hours",
  "if": {
    "field": "request.timestamp",
    "op": "hour_of_day",
    "value": { "gte": 9, "lte": 17 }
  },
  "then": {
    "decision": "within_business_hours",
    "weight": 1.0
  }
}
```

---

### `day_of_month`, `month`, `year`, `week_of_year`

Similar to `hour_of_day` but extracts day of month (1-31), month (1-12), year, or week of year (1-52).

**Example:**
```json
{
  "field": "event.date",
  "op": "month",
  "value": 12
}
```

---

## Rate Calculations

### `rate_per_second`

Calculates the rate per second from an array of timestamps.

**Syntax:**
```json
{
  "field": "request_timestamps",
  "op": "rate_per_second",
  "value": { "max": 10 }
}
```

**Example:**
```json
{
  "id": "rate_limit_check",
  "if": {
    "field": "user.recent_request_timestamps",
    "op": "rate_per_second",
    "value": { "max": 10 }
  },
  "then": {
    "decision": "rate_limit_exceeded",
    "weight": 1.0
  }
}
```

**Behavior:**
- Field must be an array of timestamps
- Requires at least 2 timestamps
- Calculates rate as: `count / time_span_in_seconds`

---

### `rate_per_minute`, `rate_per_hour`

Similar to `rate_per_second` but calculates rate per minute or per hour.

---

## Moving Window Calculations

### `moving_average`

Calculates the moving average over a specified window.

**Syntax:**
```json
{
  "field": "metrics.values",
  "op": "moving_average",
  "value": { "window": 5, "threshold": 100 }
}
```

**Example:**
```json
{
  "id": "trend_analysis",
  "if": {
    "field": "performance.metrics",
    "op": "moving_average",
    "value": { "window": 10, "gt": 50 }
  },
  "then": {
    "decision": "increasing_trend",
    "weight": 0.8
  }
}
```

**Parameters:**
- `window`: Number of elements to include (required)
- `threshold`, `gt`, `lt`, `gte`, `lte`, `eq`: Comparison operators

---

### `moving_sum`, `moving_max`, `moving_min`

Similar to `moving_average` but calculates moving sum, max, or min over the window.

---

## Financial Calculations

### `compound_interest`

Calculates compound interest: `A = P(1 + r/n)^(nt)`

**Syntax:**
```json
{
  "field": "principal",
  "op": "compound_interest",
  "value": { "rate": 0.05, "periods": 12, "result": 1050 }
}
```

**Example:**
```json
{
  "id": "investment_check",
  "if": {
    "field": "investment.principal",
    "op": "compound_interest",
    "value": { "rate": 0.05, "periods": 12, "gt": 1000 }
  },
  "then": {
    "decision": "profitable_investment",
    "weight": 0.9
  }
}
```

**Parameters:**
- `rate`: Interest rate (e.g., 0.05 for 5%)
- `periods`: Number of compounding periods
- `result`: Expected result (optional, for exact match)
- `gt`, `lt`, `threshold`: Comparison operators

---

### `present_value`

Calculates present value: `PV = FV / (1 + r)^n`

**Syntax:**
```json
{
  "field": "future_value",
  "op": "present_value",
  "value": { "rate": 0.05, "periods": 10, "result": 613.91 }
}
```

---

### `future_value`

Calculates future value: `FV = PV * (1 + r)^n`

**Syntax:**
```json
{
  "field": "present_value",
  "op": "future_value",
  "value": { "rate": 0.05, "periods": 10, "result": 1628.89 }
}
```

---

### `payment`

Calculates loan payment (PMT): `PMT = P * [r(1+r)^n] / [(1+r)^n - 1]`

**Syntax:**
```json
{
  "field": "loan.principal",
  "op": "payment",
  "value": { "rate": 0.05, "periods": 12, "result": 100 }
}
```

---

## String Aggregations

### `join`

Joins an array of strings with a separator.

**Syntax:**
```json
{
  "field": "tags",
  "op": "join",
  "value": { "separator": ",", "result": "tag1,tag2,tag3" }
}
```

**Example:**
```json
{
  "id": "tag_formatting",
  "if": {
    "field": "article.tags",
    "op": "join",
    "value": { "separator": ",", "contains": "important" }
  },
  "then": {
    "decision": "has_important_tag",
    "weight": 0.8
  }
}
```

**Parameters:**
- `separator`: String to join with (default: `","`)
- `result`: Expected joined string (for exact match)
- `contains`: Substring to check for in joined string

---

### `length`

Gets the length of a string or array.

**Syntax:**
```json
{
  "field": "description",
  "op": "length",
  "value": { "max": 500 }
}
```

**Example:**
```json
{
  "id": "description_length",
  "if": {
    "field": "product.description",
    "op": "length",
    "value": { "min": 10, "max": 500 }
  },
  "then": {
    "decision": "valid_description",
    "weight": 1.0
  }
}
```

---

## Collection Operators

### `contains_all`

Checks if an array contains all of the specified elements.

**Syntax:**
```json
{
  "field": "permissions",
  "op": "contains_all",
  "value": ["read", "write"]
}
```

**Example:**
```json
{
  "id": "admin_access",
  "if": {
    "field": "user.permissions",
    "op": "contains_all",
    "value": ["read", "write", "delete"]
  },
  "then": {
    "decision": "grant_admin_access",
    "weight": 1.0,
    "reason": "User has all required permissions"
  }
}
```

**Behavior:**
- Both field and value must be arrays
- Order doesn't matter
- Field can contain additional elements

---

### `contains_any`

Checks if an array contains any of the specified elements.

**Syntax:**
```json
{
  "field": "tags",
  "op": "contains_any",
  "value": ["urgent", "critical", "emergency"]
}
```

**Example:**
```json
{
  "id": "priority_escalation",
  "if": {
    "field": "ticket.tags",
    "op": "contains_any",
    "value": ["urgent", "critical"]
  },
  "then": {
    "decision": "escalate_to_manager",
    "weight": 0.95,
    "reason": "Ticket has priority tag"
  }
}
```

**Behavior:**
- Both field and value must be arrays
- Returns `true` if at least one element matches

---

### `intersects`

Checks if two arrays have any common elements (set intersection).

**Syntax:**
```json
{
  "field": "user_roles",
  "op": "intersects",
  "value": ["admin", "moderator", "super_user"]
}
```

**Example:**
```json
{
  "id": "elevated_role_check",
  "if": {
    "field": "account.roles",
    "op": "intersects",
    "value": ["admin", "moderator"]
  },
  "then": {
    "decision": "allow_moderation_features",
    "weight": 1.0
  }
}
```

**Behavior:**
- Equivalent to `contains_any` but semantically indicates set comparison
- Returns `true` if intersection is non-empty

---

### `subset_of`

Checks if an array is a subset of another array (all elements are contained).

**Syntax:**
```json
{
  "field": "selected_options",
  "op": "subset_of",
  "value": ["option_a", "option_b", "option_c", "option_d"]
}
```

**Example:**
```json
{
  "id": "validate_selection",
  "if": {
    "field": "form.selected_features",
    "op": "subset_of",
    "value": ["feature_a", "feature_b", "feature_c"]
  },
  "then": {
    "decision": "valid_selection",
    "weight": 1.0,
    "reason": "All selected features are valid options"
  }
}
```

**Behavior:**
- Returns `true` if all elements in the field array exist in the value array
- Empty array is a subset of any array

---

## Geospatial Operators

### `within_radius`

Checks if a geographic point is within a specified radius of a center point.

**Syntax:**
```json
{
  "field": "location",
  "op": "within_radius",
  "value": {
    "center": { "lat": 40.7128, "lon": -74.0060 },
    "radius": 10
  }
}
```

**Coordinate Formats:**

**Hash Format:**
```json
{ "lat": 40.7128, "lon": -74.0060 }
{ "latitude": 40.7128, "longitude": -74.0060 }
{ "lat": 40.7128, "lng": -74.0060 }
```

**Array Format:**
```json
[40.7128, -74.0060]  // [latitude, longitude]
```

**Example:**
```json
{
  "id": "local_delivery",
  "if": {
    "field": "delivery.address.coordinates",
    "op": "within_radius",
    "value": {
      "center": { "lat": 37.7749, "lon": -122.4194 },
      "radius": 25
    }
  },
  "then": {
    "decision": "offer_same_day_delivery",
    "weight": 0.9,
    "reason": "Within 25km of distribution center"
  }
}
```

**Behavior:**
- Distance calculated using Haversine formula
- Radius is in kilometers
- Returns `false` if coordinates are invalid or missing

**Use Cases:**
- Delivery zone validation
- Store locator
- Geofencing
- Proximity-based routing

---

### `in_polygon`

Checks if a geographic point is inside a polygon using the ray casting algorithm.

**Syntax:**
```json
{
  "field": "location",
  "op": "in_polygon",
  "value": [
    { "lat": 40.0, "lon": -74.0 },
    { "lat": 41.0, "lon": -74.0 },
    { "lat": 41.0, "lon": -73.0 },
    { "lat": 40.0, "lon": -73.0 }
  ]
}
```

**Example - Service Area:**
```json
{
  "id": "service_area_check",
  "if": {
    "field": "customer.location",
    "op": "in_polygon",
    "value": [
      { "lat": 40.5, "lon": -74.5 },
      { "lat": 41.5, "lon": -74.5 },
      { "lat": 41.5, "lon": -73.0 },
      { "lat": 40.5, "lon": -73.0 }
    ]
  },
  "then": {
    "decision": "within_service_area",
    "weight": 1.0,
    "reason": "Customer is within our service area"
  }
}
```

**Example - Complex Boundary:**
```json
{
  "field": "store.location",
  "op": "in_polygon",
  "value": [
    [37.7749, -122.4194],
    [37.7849, -122.4094],
    [37.7949, -122.4194],
    [37.7849, -122.4294]
  ]
}
```

**Behavior:**
- Polygon must have at least 3 vertices
- Works with both hash and array coordinate formats
- Polygon is automatically closed (last point connects to first)
- Uses ray casting algorithm for point-in-polygon test

**Use Cases:**
- Service area boundaries
- Zoning validation
- Regulatory compliance zones
- Custom geographic regions

---

## Examples

### Complex Multi-Operator Rule

```json
{
  "version": "1.0",
  "ruleset": "fraud_detection",
  "rules": [
    {
      "id": "high_risk_transaction",
      "if": {
        "all": [
          {
            "field": "transaction.amount",
            "op": "between",
            "value": [1000, 10000]
          },
          {
            "field": "user.email",
            "op": "matches",
            "value": "^[a-z0-9._-]+@(gmail|yahoo|hotmail)\\.(com|net)$"
          },
          {
            "field": "user.account_age_days",
            "op": "lt",
            "value": 30
          },
          {
            "any": [
              {
                "field": "transaction.location",
                "op": "within_radius",
                "value": {
                  "center": { "lat": 40.7128, "lon": -74.0060 },
                  "radius": 100
                }
              },
              {
                "field": "user.risk_flags",
                "op": "contains_any",
                "value": ["vpn", "proxy", "tor"]
              }
            ]
          }
        ]
      },
      "then": {
        "decision": "require_additional_verification",
        "weight": 0.95,
        "reason": "High-risk transaction pattern detected"
      }
    }
  ]
}
```

### Email Domain Validation

```json
{
  "id": "corporate_email",
  "if": {
    "any": [
      { "field": "email", "op": "ends_with", "value": "@company.com" },
      { "field": "email", "op": "ends_with", "value": "@subsidiary.com" },
      { "field": "email", "op": "matches", "value": "^[a-z.]+@partner\\.(com|net)$" }
    ]
  },
  "then": {
    "decision": "grant_internal_access",
    "weight": 1.0
  }
}
```

### Scheduled Maintenance Window

```json
{
  "id": "maintenance_window",
  "if": {
    "all": [
      {
        "any": [
          { "field": "scheduled_time", "op": "day_of_week", "value": "saturday" },
          { "field": "scheduled_time", "op": "day_of_week", "value": "sunday" }
        ]
      },
      {
        "field": "scheduled_time",
        "op": "within_days",
        "value": 7
      }
    ]
  },
  "then": {
    "decision": "approve_maintenance",
    "weight": 0.9,
    "reason": "Scheduled during weekend maintenance window"
  }
}
```

### Delivery Zone Routing

```json
{
  "version": "1.0",
  "ruleset": "delivery_routing",
  "rules": [
    {
      "id": "zone_a_local",
      "if": {
        "field": "delivery_address.coordinates",
        "op": "in_polygon",
        "value": [
          { "lat": 40.7, "lon": -74.1 },
          { "lat": 40.8, "lon": -74.1 },
          { "lat": 40.8, "lon": -73.9 },
          { "lat": 40.7, "lon": -73.9 }
        ]
      },
      "then": {
        "decision": "route_to_zone_a",
        "weight": 1.0,
        "reason": "Address is in Zone A delivery polygon"
      }
    },
    {
      "id": "zone_b_radius",
      "if": {
        "field": "delivery_address.coordinates",
        "op": "within_radius",
        "value": {
          "center": { "lat": 40.75, "lon": -73.95 },
          "radius": 5
        }
      },
      "then": {
        "decision": "route_to_zone_b",
        "weight": 0.9,
        "reason": "Within 5km of Zone B distribution center"
      }
    }
  ]
}
```

### Permission-Based Access Control

```json
{
  "id": "feature_access",
  "if": {
    "all": [
      {
        "field": "user.permissions",
        "op": "contains_all",
        "value": ["feature_a_read", "feature_a_write"]
      },
      {
        "field": "user.roles",
        "op": "intersects",
        "value": ["power_user", "admin", "developer"]
      },
      {
        "field": "user.subscription_tier",
        "op": "in",
        "value": ["premium", "enterprise"]
      }
    ]
  },
  "then": {
    "decision": "grant_feature_a_access",
    "weight": 1.0,
    "reason": "User has required permissions and role"
  }
}
```

---

## Best Practices

### Performance Considerations

1. **String Operations**: `contains`, `starts_with`, and `ends_with` are faster than `matches`
2. **Geospatial**: Prefer `within_radius` for circular areas, `in_polygon` for irregular shapes
3. **Collections**: Use `contains_any` instead of multiple `eq` conditions in an `any` block

### Performance Benchmarks

**Last Updated: December 19, 2024**

Performance results from running `examples/advanced_operators_performance.rb` with 10,000 iterations:

| Operator Type | Throughput | Latency | Performance vs Basic |
|--------------|------------|---------|----------------------|
| Basic Operators (gt, eq, lt) | 7,904/sec | 0.127ms | Baseline |
| String Operators | 9,111/sec | 0.110ms | **+15.27% faster** |
| Numeric Operators | 6,994/sec | 0.143ms | -11.51% slower |
| Collection Operators | 5,810/sec | 0.172ms | -26.5% slower |
| Date Operators | 9,054/sec | 0.110ms | **+14.54% faster** |
| Geospatial Operators | 7,891/sec | 0.127ms | -0.17% (negligible) |
| Complex (all combined) | 4,516/sec | 0.221ms | -42.86% slower |

**Key Findings:**
- String operators perform **15.27% faster** than basic operators (likely due to early exit optimizations)
- Date operators perform **14.54% faster** than basic operators (fast-path parsing and caching)
- Geospatial operators show negligible performance difference (-0.17%)
- Collection operators improved from -72.2% to -26.5% (45.7% improvement) using Set-based lookups
- Numeric operators use epsilon comparison for more accurate floating-point math
- Complex rules combining many operators show expected slowdown (~43%)

**Optimizations Implemented:**
- ✅ Fast-path date parsing for ISO8601 formats (YYYY-MM-DD, YYYY-MM-DDTHH:MM:SS)
- ✅ Fast-path date comparison when values are already Time/Date objects (no parsing needed)
- ✅ Parameter parsing caching (range, modulo, etc.)
- ✅ Geospatial calculation caching with coordinate precision rounding
- ✅ Single-pass array aggregations (sum, average)
- ✅ **Set-based collection operators** (contains_all, contains_any, intersects, subset_of) for O(1) lookups instead of O(n)
- ✅ **Epsilon comparison** for numeric operators (sin, cos, tan, sqrt, exp, log, power) instead of round(10)
- ✅ Thread-safe caching for regex, dates, paths, and parameters

**Performance Notes:**
- Regex matching uses caching for repeated patterns
- Date parsing uses fast-path for ISO8601 and caching for all formats
- Geospatial calculations (Haversine) are cached with coordinate precision
- Statistical aggregations iterate over arrays (inherently more expensive)
- Complex mathematical functions use native Ruby Math library

### Error Handling

All operators are designed to fail safely:
- Invalid regex patterns return `false`
- Type mismatches return `false`
- Missing or nil values return `false`
- Malformed coordinates return `false`

### Validation

The schema validator ensures:
- All operators are recognized before evaluation
- Required fields are present
- Value types are appropriate for the operator

---

## Migration from Basic Operators

### Before (Multiple Rules):
```json
{
  "any": [
    { "field": "status", "op": "eq", "value": "urgent" },
    { "field": "status", "op": "eq", "value": "critical" },
    { "field": "status", "op": "eq", "value": "emergency" }
  ]
}
```

### After (Single Rule):
```json
{
  "field": "status",
  "op": "in",
  "value": ["urgent", "critical", "emergency"]
}
```

### Or Even Better (with tags array):
```json
{
  "field": "tags",
  "op": "contains_any",
  "value": ["urgent", "critical", "emergency"]
}
```

---

## Web UI Support

All advanced operators are fully supported in the DecisionAgent Web UI:

- **Visual Builder** - All operators available in dropdown menus, organized by category
- **Smart Placeholders** - Context-aware placeholders guide you on the expected value format
- **Helpful Hints** - Hover over value fields to see format examples
- **Example Rules** - Load example rules showcasing the new operators

Launch the Web UI:
```bash
decision_agent web
```

Or mount in your Rails app:
```ruby
mount DecisionAgent::Web::Server, at: '/decision_agent'
```

## See Also

- [API Contract](API_CONTRACT.md) - Core API documentation
- [Thread Safety](THREAD_SAFETY.md) - Concurrency considerations
- [Performance](PERFORMANCE_AND_THREAD_SAFETY.md) - Performance optimization
- [Web UI](WEB_UI.md) - Visual rule builder documentation
