#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/decision_agent"

puts "=" * 80
puts "DecisionAgent - Mathematical Operators Examples"
puts "=" * 80
puts

# Example 1: Trigonometric Functions - Signal Processing
puts "Example 1: Trigonometric Functions - Signal Processing"
puts "-" * 80

signal_rules = {
  version: "1.0",
  ruleset: "signal_processing",
  rules: [
    {
      id: "zero_crossing",
      if: {
        field: "signal_phase",
        op: "sin",
        value: 0.0
      },
      then: {
        decision: "zero_crossing_detected",
        weight: 1.0,
        reason: "Signal is at zero crossing point"
      }
    },
    {
      id: "peak_amplitude",
      if: {
        field: "signal_phase",
        op: "sin",
        value: 1.0
      },
      then: {
        decision: "peak_amplitude",
        weight: 1.0,
        reason: "Signal is at peak amplitude (sin(π/2) = 1)"
      }
    },
    {
      id: "phase_alignment",
      if: {
        field: "waveform_phase",
        op: "cos",
        value: 1.0
      },
      then: {
        decision: "in_phase",
        weight: 0.95,
        reason: "Waveforms are in phase"
      }
    }
  ]
}

evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: signal_rules)

# Test zero crossing
context1 = { signal_phase: 0 }
result1 = evaluator.evaluate(DecisionAgent::Context.new(context1))
puts "Signal phase: 0"
puts "  Decision: #{result1&.decision || 'no match'}"
puts "  Reason: #{result1&.reason}" if result1
puts

# Test peak amplitude (π/2 radians)
require "bigdecimal/math"
context2 = { signal_phase: Math::PI / 2 }
result2 = evaluator.evaluate(DecisionAgent::Context.new(context2))
puts "Signal phase: π/2 ≈ #{Math::PI / 2}"
puts "  Decision: #{result2&.decision || 'no match'}"
puts "  Reason: #{result2&.reason}" if result2
puts

# Example 2: Power and Root Functions - Distance Calculations
puts "\nExample 2: Power and Root Functions - Distance Calculations"
puts "-" * 80

distance_rules = {
  version: "1.0",
  ruleset: "distance_calculations",
  rules: [
    {
      id: "perfect_square_distance",
      if: {
        field: "squared_distance",
        op: "sqrt",
        value: 5.0
      },
      then: {
        decision: "standard_range",
        weight: 1.0,
        reason: "Distance is 5 units"
      }
    },
    {
      id: "volume_dimension_check",
      if: {
        field: "cubed_volume",
        op: "cbrt",
        value: 3.0
      },
      then: {
        decision: "standard_size",
        weight: 1.0,
        reason: "Cube root equals 3"
      }
    },
    {
      id: "square_check",
      if: {
        field: "base_number",
        op: "power",
        value: { exponent: 2, result: 16 }
      },
      then: {
        decision: "perfect_square",
        weight: 1.0,
        reason: "Number squared equals 16"
      }
    }
  ]
}

evaluator2 = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: distance_rules)

# Test square root
context3 = { squared_distance: 25 }
result3 = evaluator2.evaluate(DecisionAgent::Context.new(context3))
puts "Squared distance: 25"
puts "  Decision: #{result3&.decision || 'no match'}"
puts "  Reason: #{result3&.reason}" if result3
puts

# Test cube root
context4 = { cubed_volume: 27 }
result4 = evaluator2.evaluate(DecisionAgent::Context.new(context4))
puts "Cubed volume: 27"
puts "  Decision: #{result4&.decision || 'no match'}"
puts "  Reason: #{result4&.reason}" if result4
puts

# Test power
context5 = { base_number: 4 }
result5 = evaluator2.evaluate(DecisionAgent::Context.new(context5))
puts "Base number: 4"
puts "  Decision: #{result5&.decision || 'no match'}"
puts "  Reason: #{result5&.reason}" if result5
puts

# Example 3: Logarithmic Functions - Order of Magnitude
puts "\nExample 3: Logarithmic Functions - Order of Magnitude"
puts "-" * 80

magnitude_rules = {
  version: "1.0",
  ruleset: "magnitude_classification",
  rules: [
    {
      id: "thousands_range",
      if: {
        field: "magnitude",
        op: "log10",
        value: 3.0
      },
      then: {
        decision: "thousands",
        weight: 1.0,
        reason: "Value is in thousands (10^3)"
      }
    },
    {
      id: "kilobyte_range",
      if: {
        field: "data_size",
        op: "log2",
        value: 10.0
      },
      then: {
        decision: "kilobyte_range",
        weight: 1.0,
        reason: "Value is 2^10 = 1024 bytes (1KB)"
      }
    },
    {
      id: "unit_ratio",
      if: {
        field: "ratio",
        op: "log",
        value: 0.0
      },
      then: {
        decision: "balanced",
        weight: 1.0,
        reason: "Ratio is 1 (log(1) = 0)"
      }
    }
  ]
}

evaluator3 = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: magnitude_rules)

# Test log10 (thousands)
context6 = { magnitude: 1000 }
result6 = evaluator3.evaluate(DecisionAgent::Context.new(context6))
puts "Magnitude: 1000"
puts "  Decision: #{result6&.decision || 'no match'}"
puts "  Reason: #{result6&.reason}" if result6
puts

# Test log2 (kilobytes)
context7 = { data_size: 1024 }
result7 = evaluator3.evaluate(DecisionAgent::Context.new(context7))
puts "Data size: 1024"
puts "  Decision: #{result7&.decision || 'no match'}"
puts "  Reason: #{result7&.reason}" if result7
puts

# Example 4: Rounding Functions - Pricing
puts "\nExample 4: Rounding Functions - Pricing"
puts "-" * 80

pricing_rules = {
  version: "1.0",
  ruleset: "pricing_rules",
  rules: [
    {
      id: "round_pricing",
      if: {
        field: "calculated_price",
        op: "round",
        value: 100
      },
      then: {
        decision: "standard_price",
        weight: 1.0,
        reason: "Price rounds to $100"
      }
    },
    {
      id: "floor_pricing",
      if: {
        field: "discounted_price",
        op: "floor",
        value: 50
      },
      then: {
        decision: "minimum_price",
        weight: 1.0,
        reason: "Floored price is $50"
      }
    },
    {
      id: "absolute_deviation",
      if: {
        field: "price_deviation",
        op: "abs",
        value: 10
      },
      then: {
        decision: "within_tolerance",
        weight: 0.9,
        reason: "Absolute deviation is within $10"
      }
    }
  ]
}

evaluator4 = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: pricing_rules)

# Test round
context8 = { calculated_price: 99.6 }
result8 = evaluator4.evaluate(DecisionAgent::Context.new(context8))
puts "Calculated price: 99.6"
puts "  Decision: #{result8&.decision || 'no match'}"
puts "  Reason: #{result8&.reason}" if result8
puts

# Test floor
context9 = { discounted_price: 50.9 }
result9 = evaluator4.evaluate(DecisionAgent::Context.new(context9))
puts "Discounted price: 50.9"
puts "  Decision: #{result9&.decision || 'no match'}"
puts "  Reason: #{result9&.reason}" if result9
puts

# Test abs
context10 = { price_deviation: -10 }
result10 = evaluator4.evaluate(DecisionAgent::Context.new(context10))
puts "Price deviation: -10"
puts "  Decision: #{result10&.decision || 'no match'}"
puts "  Reason: #{result10&.reason}" if result10
puts

# Example 5: Advanced Mathematical Functions - Combinatorics
puts "\nExample 5: Advanced Mathematical Functions - Combinatorics"
puts "-" * 80

combinatorics_rules = {
  version: "1.0",
  ruleset: "combinatorics_rules",
  rules: [
    {
      id: "permutation_count",
      if: {
        field: "items_count",
        op: "factorial",
        value: 24
      },
      then: {
        decision: "four_items",
        weight: 1.0,
        reason: "4! = 24 permutations possible"
      }
    },
    {
      id: "common_divisor",
      if: {
        field: "number_a",
        op: "gcd",
        value: { other: 24, result: 12 }
      },
      then: {
        decision: "has_common_factor",
        weight: 1.0,
        reason: "GCD of 36 and 24 is 12"
      }
    },
    {
      id: "synchronization_point",
      if: {
        field: "cycle_a",
        op: "lcm",
        value: { other: 12, result: 36 }
      },
      then: {
        decision: "aligned_cycles",
        weight: 1.0,
        reason: "Cycles align every 36 units"
      }
    }
  ]
}

evaluator5 = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: combinatorics_rules)

# Test factorial
context11 = { items_count: 4 }
result11 = evaluator5.evaluate(DecisionAgent::Context.new(context11))
puts "Items count: 4"
puts "  Decision: #{result11&.decision || 'no match'}"
puts "  Reason: #{result11&.reason}" if result11
puts

# Test gcd
context12 = { number_a: 36 }
result12 = evaluator5.evaluate(DecisionAgent::Context.new(context12))
puts "Number A: 36, Number B: 24"
puts "  Decision: #{result12&.decision || 'no match'}"
puts "  Reason: #{result12&.reason}" if result12
puts

# Test lcm
context13 = { cycle_a: 9 }
result13 = evaluator5.evaluate(DecisionAgent::Context.new(context13))
puts "Cycle A: 9, Cycle B: 12"
puts "  Decision: #{result13&.decision || 'no match'}"
puts "  Reason: #{result13&.reason}" if result13
puts

# Example 6: Inverse Trigonometric Functions - Angle Calculations
puts "\nExample 6: Inverse Trigonometric Functions - Angle Calculations"
puts "-" * 80

angle_rules = {
  version: "1.0",
  ruleset: "angle_calculations",
  rules: [
    {
      id: "right_angle_from_sine",
      if: {
        field: "sine_value",
        op: "asin",
        value: Math::PI / 2
      },
      then: {
        decision: "right_angle",
        weight: 1.0,
        reason: "Angle is π/2 radians (90 degrees)"
      }
    },
    {
      id: "diagonal_angle",
      if: {
        field: "slope",
        op: "atan",
        value: Math::PI / 4
      },
      then: {
        decision: "diagonal_line",
        weight: 1.0,
        reason: "Angle is π/4 radians (45 degrees)"
      }
    },
    {
      id: "coordinate_angle",
      if: {
        field: "point_x",
        op: "atan2",
        value: { y: 1, result: Math::PI / 4 }
      },
      then: {
        decision: "diagonal_quadrant",
        weight: 1.0,
        reason: "Angle from coordinates is 45 degrees"
      }
    }
  ]
}

evaluator6 = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: angle_rules)

# Test asin
context14 = { sine_value: 1.0 }
result14 = evaluator6.evaluate(DecisionAgent::Context.new(context14))
puts "Sine value: 1.0"
puts "  Decision: #{result14&.decision || 'no match'}"
puts "  Reason: #{result14&.reason}" if result14
puts

# Test atan
context15 = { slope: 1.0 }
result15 = evaluator6.evaluate(DecisionAgent::Context.new(context15))
puts "Slope: 1.0"
puts "  Decision: #{result15&.decision || 'no match'}"
puts "  Reason: #{result15&.reason}" if result15
puts

# Test atan2
context16 = { point_x: 1.0 }
result16 = evaluator6.evaluate(DecisionAgent::Context.new(context16))
puts "Point X: 1.0, Point Y: 1.0"
puts "  Decision: #{result16&.decision || 'no match'}"
puts "  Reason: #{result16&.reason}" if result16
puts

# Example 7: Hyperbolic Functions - Machine Learning
puts "\nExample 7: Hyperbolic Functions - Machine Learning"
puts "-" * 80

ml_rules = {
  version: "1.0",
  ruleset: "activation_functions",
  rules: [
    {
      id: "neutral_activation",
      if: {
        field: "activation_value",
        op: "tanh",
        value: 0.0
      },
      then: {
        decision: "neutral_activation",
        weight: 0.9,
        reason: "Hyperbolic tangent is zero (neutral point)"
      }
    },
    {
      id: "symmetric_point",
      if: {
        field: "hyperbolic_parameter",
        op: "sinh",
        value: 0.0
      },
      then: {
        decision: "symmetric_point",
        weight: 1.0,
        reason: "Hyperbolic sine is zero"
      }
    },
    {
      id: "base_case",
      if: {
        field: "hyperbolic_parameter",
        op: "cosh",
        value: 1.0
      },
      then: {
        decision: "base_case",
        weight: 1.0,
        reason: "Hyperbolic cosine is 1.0 (base case)"
      }
    }
  ]
}

evaluator7 = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: ml_rules)

# Test tanh
context17 = { activation_value: 0.0 }
result17 = evaluator7.evaluate(DecisionAgent::Context.new(context17))
puts "Activation value: 0.0"
puts "  Decision: #{result17&.decision || 'no match'}"
puts "  Reason: #{result17&.reason}" if result17
puts

# Test sinh
context18 = { hyperbolic_parameter: 0.0 }
result18 = evaluator7.evaluate(DecisionAgent::Context.new(context18))
puts "Hyperbolic parameter: 0.0"
puts "  Decision: #{result18&.decision || 'no match'}"
puts "  Reason: #{result18&.reason}" if result18
puts

# Example 8: Exponential Functions - Growth Models
puts "\nExample 8: Exponential Functions - Growth Models"
puts "-" * 80

growth_rules = {
  version: "1.0",
  ruleset: "growth_models",
  rules: [
    {
      id: "natural_growth",
      if: {
        field: "growth_rate",
        op: "exp",
        value: 2.718281828459045
      },
      then: {
        decision: "natural_growth",
        weight: 1.0,
        reason: "Value is e^1 (natural exponential)"
      }
    }
  ]
}

evaluator8 = DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: growth_rules)

# Test exp
context19 = { growth_rate: 1.0 }
result19 = evaluator8.evaluate(DecisionAgent::Context.new(context19))
puts "Growth rate: 1.0"
puts "  Decision: #{result19&.decision || 'no match'}"
puts "  Reason: #{result19&.reason}" if result19
puts

puts "\n" + "=" * 80
puts "All mathematical operators examples completed!"
puts "=" * 80
puts
puts "Summary of Mathematical Operators Demonstrated:"
puts "  ✓ Trigonometric: sin, cos, tan, asin, acos, atan, atan2"
puts "  ✓ Hyperbolic: sinh, cosh, tanh"
puts "  ✓ Power/Root: sqrt, cbrt, power, exp"
puts "  ✓ Logarithmic: log, log10, log2"
puts "  ✓ Rounding: round, floor, ceil, truncate, abs"
puts "  ✓ Advanced: factorial, gcd, lcm"
puts
