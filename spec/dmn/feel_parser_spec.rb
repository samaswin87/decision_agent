require "spec_helper"
require "decision_agent/dmn/feel/parser"
require "decision_agent/dmn/feel/transformer"
require "decision_agent/dmn/feel/evaluator"

RSpec.describe "FEEL Parser and Evaluator" do
  let(:parser) { DecisionAgent::Dmn::Feel::Parser.new }
  let(:transformer) { DecisionAgent::Dmn::Feel::Transformer.new }
  let(:evaluator) { DecisionAgent::Dmn::Feel::Evaluator.new }

  describe "Literals" do
    it "parses numbers" do
      result = parser.parse("42")
      ast = transformer.apply(result)
      expect(ast[:type]).to eq(:number)
      expect(ast[:value]).to eq(42)
    end

    it "parses negative numbers" do
      result = parser.parse("-42")
      ast = transformer.apply(result)
      expect(ast[:type]).to eq(:number)
      expect(ast[:value]).to eq(-42)
    end

    it "parses floats" do
      result = parser.parse("3.14")
      ast = transformer.apply(result)
      expect(ast[:type]).to eq(:number)
      expect(ast[:value]).to eq(3.14)
    end

    it "parses strings" do
      result = parser.parse('"hello world"')
      ast = transformer.apply(result)
      expect(ast[:type]).to eq(:string)
      expect(ast[:value]).to eq("hello world")
    end

    it "parses booleans" do
      true_result = parser.parse("true")
      true_ast = transformer.apply(true_result)
      expect(true_ast[:type]).to eq(:boolean)
      expect(true_ast[:value]).to eq(true)

      false_result = parser.parse("false")
      false_ast = transformer.apply(false_result)
      expect(false_ast[:type]).to eq(:boolean)
      expect(false_ast[:value]).to eq(false)
    end

    it "parses null" do
      result = parser.parse("null")
      ast = transformer.apply(result)
      expect(ast[:type]).to eq(:null)
      expect(ast[:value]).to be_nil
    end
  end

  describe "Arithmetic Operations" do
    let(:context) { {} }

    it "evaluates addition" do
      result = evaluator.evaluate("5 + 3", "result", context)
      expect(result).to eq(8)
    end

    it "evaluates subtraction" do
      result = evaluator.evaluate("10 - 4", "result", context)
      expect(result).to eq(6)
    end

    it "evaluates multiplication" do
      result = evaluator.evaluate("6 * 7", "result", context)
      expect(result).to eq(42)
    end

    it "evaluates division" do
      result = evaluator.evaluate("20 / 4", "result", context)
      expect(result).to eq(5.0)
    end

    it "evaluates exponentiation" do
      result = evaluator.evaluate("2 ** 3", "result", context)
      expect(result).to eq(8)
    end

    it "evaluates modulo" do
      result = evaluator.evaluate("10 % 3", "result", context)
      expect(result).to eq(1)
    end

    it "respects operator precedence" do
      result = evaluator.evaluate("2 + 3 * 4", "result", context)
      expect(result).to eq(14)
    end

    it "evaluates parentheses" do
      result = evaluator.evaluate("(2 + 3) * 4", "result", context)
      expect(result).to eq(20)
    end
  end

  describe "Comparison Operations" do
    let(:context) { {} }

    it "evaluates equality" do
      expect(evaluator.evaluate("5 = 5", "result", context)).to eq(true)
      expect(evaluator.evaluate("5 = 3", "result", context)).to eq(false)
    end

    it "evaluates inequality" do
      expect(evaluator.evaluate("5 != 3", "result", context)).to eq(true)
      expect(evaluator.evaluate("5 != 5", "result", context)).to eq(false)
    end

    it "evaluates less than" do
      expect(evaluator.evaluate("3 < 5", "result", context)).to eq(true)
      expect(evaluator.evaluate("5 < 3", "result", context)).to eq(false)
    end

    it "evaluates greater than" do
      expect(evaluator.evaluate("5 > 3", "result", context)).to eq(true)
      expect(evaluator.evaluate("3 > 5", "result", context)).to eq(false)
    end

    it "evaluates less than or equal" do
      expect(evaluator.evaluate("3 <= 5", "result", context)).to eq(true)
      expect(evaluator.evaluate("5 <= 5", "result", context)).to eq(true)
      expect(evaluator.evaluate("7 <= 5", "result", context)).to eq(false)
    end

    it "evaluates greater than or equal" do
      expect(evaluator.evaluate("5 >= 3", "result", context)).to eq(true)
      expect(evaluator.evaluate("5 >= 5", "result", context)).to eq(true)
      expect(evaluator.evaluate("3 >= 5", "result", context)).to eq(false)
    end
  end

  describe "Logical Operations" do
    let(:context) { {} }

    it "evaluates AND" do
      expect(evaluator.evaluate("true and true", "result", context)).to eq(true)
      expect(evaluator.evaluate("true and false", "result", context)).to eq(false)
      expect(evaluator.evaluate("false and false", "result", context)).to eq(false)
    end

    it "evaluates OR" do
      expect(evaluator.evaluate("true or false", "result", context)).to eq(true)
      expect(evaluator.evaluate("false or true", "result", context)).to eq(true)
      expect(evaluator.evaluate("false or false", "result", context)).to eq(false)
    end

    it "evaluates NOT" do
      expect(evaluator.evaluate("not true", "result", context)).to eq(false)
      expect(evaluator.evaluate("not false", "result", context)).to eq(true)
    end

    it "evaluates complex logical expressions" do
      result = evaluator.evaluate("(5 > 3) and (10 < 20)", "result", context)
      expect(result).to eq(true)
    end
  end

  describe "Field References" do
    it "evaluates field references" do
      context = { age: 25 }
      result = evaluator.evaluate("age", "result", context)
      expect(result).to eq(25)
    end

    it "evaluates field references in comparisons" do
      context = { age: 25 }
      result = evaluator.evaluate("age >= 18", "age", context)
      expect(result).to eq(true)
    end

    it "evaluates field references in arithmetic" do
      context = { price: 100, quantity: 5 }
      result = evaluator.evaluate("price * quantity", "total", context)
      expect(result).to eq(500)
    end
  end

  describe "List Literals" do
    it "parses empty lists" do
      result = parser.parse("[]")
      ast = transformer.apply(result)
      expect(ast[:type]).to eq(:list_literal)
    end

    it "parses lists with elements" do
      result = parser.parse("[1, 2, 3]")
      ast = transformer.apply(result)
      expect(ast[:type]).to eq(:list_literal)
    end

    it "evaluates list literals" do
      context = {}
      result = evaluator.evaluate("[1, 2, 3]", "list", context)
      expect(result).to eq([1, 2, 3])
    end
  end

  describe "Context Literals" do
    it "parses empty contexts" do
      result = parser.parse("{}")
      ast = transformer.apply(result)
      expect(ast[:type]).to eq(:context_literal)
    end

    it "parses contexts with entries" do
      result = parser.parse('{ name: "John", age: 30 }')
      ast = transformer.apply(result)
      expect(ast[:type]).to eq(:context_literal)
    end

    it "evaluates context literals" do
      context = {}
      result = evaluator.evaluate('{ a: 1, b: 2 }', "ctx", context)
      expect(result).to eq({ a: 1, b: 2 })
    end
  end

  describe "Function Calls" do
    let(:context) { {} }

    it "evaluates string length function" do
      result = evaluator.evaluate('length("hello")', "result", context)
      expect(result).to eq(5)
    end

    it "evaluates substring function" do
      result = evaluator.evaluate('substring("hello", 2, 3)', "result", context)
      expect(result).to eq("ell")
    end

    it "evaluates upper case function" do
      result = evaluator.evaluate('upper("hello")', "result", context)
      expect(result).to eq("HELLO")
    end

    it "evaluates sum function" do
      result = evaluator.evaluate("sum([1, 2, 3, 4])", "result", context)
      expect(result).to eq(10.0)
    end

    it "evaluates mean function" do
      result = evaluator.evaluate("mean([10, 20, 30])", "result", context)
      expect(result).to eq(20.0)
    end

    it "evaluates min function" do
      result = evaluator.evaluate("min([5, 2, 8, 1])", "result", context)
      expect(result).to eq(1.0)
    end

    it "evaluates max function" do
      result = evaluator.evaluate("max([5, 2, 8, 1])", "result", context)
      expect(result).to eq(8.0)
    end
  end

  describe "If-Then-Else Conditionals" do
    let(:context) { {} }

    it "evaluates true condition" do
      result = evaluator.evaluate('if 5 > 3 then "big" else "small"', "result", context)
      expect(result).to eq("big")
    end

    it "evaluates false condition" do
      result = evaluator.evaluate('if 3 > 5 then "big" else "small"', "result", context)
      expect(result).to eq("small")
    end

    it "evaluates with field references" do
      context = { age: 25 }
      result = evaluator.evaluate('if age >= 18 then "adult" else "minor"', "status", context)
      expect(result).to eq("adult")
    end

    it "evaluates nested conditionals" do
      context = { score: 85 }
      result = evaluator.evaluate(
        'if score >= 90 then "A" else if score >= 80 then "B" else "C"',
        "grade",
        context
      )
      expect(result).to eq("B")
    end
  end

  describe "Quantified Expressions" do
    it "evaluates 'some' expression - true case" do
      context = {}
      result = evaluator.evaluate("some x in [1, 5, 10] satisfies x > 8", "result", context)
      expect(result).to eq(true)
    end

    it "evaluates 'some' expression - false case" do
      context = {}
      result = evaluator.evaluate("some x in [1, 2, 3] satisfies x > 10", "result", context)
      expect(result).to eq(false)
    end

    it "evaluates 'every' expression - true case" do
      context = {}
      result = evaluator.evaluate("every x in [5, 10, 15] satisfies x > 0", "result", context)
      expect(result).to eq(true)
    end

    it "evaluates 'every' expression - false case" do
      context = {}
      result = evaluator.evaluate("every x in [1, 5, 10] satisfies x > 5", "result", context)
      expect(result).to eq(false)
    end
  end

  describe "For Expressions" do
    it "evaluates for expression with arithmetic" do
      context = {}
      result = evaluator.evaluate("for x in [1, 2, 3] return x * 2", "result", context)
      expect(result).to eq([2, 4, 6])
    end

    it "evaluates for expression with addition" do
      context = {}
      result = evaluator.evaluate("for x in [10, 20, 30] return x + 5", "result", context)
      expect(result).to eq([15, 25, 35])
    end
  end

  describe "Between Expressions" do
    it "evaluates between - true case" do
      context = {}
      result = evaluator.evaluate("5 between 1 and 10", "result", context)
      expect(result).to eq(true)
    end

    it "evaluates between - false case" do
      context = {}
      result = evaluator.evaluate("15 between 1 and 10", "result", context)
      expect(result).to eq(false)
    end

    it "evaluates between with field reference" do
      context = { age: 25 }
      result = evaluator.evaluate("age between 18 and 65", "working_age", context)
      expect(result).to eq(true)
    end
  end

  describe "Range Literals" do
    it "parses inclusive range" do
      result = parser.parse("[1..10]")
      ast = transformer.apply(result)
      expect(ast[:type]).to eq(:range)
      expect(ast[:start_inclusive]).to eq(true)
      expect(ast[:end_inclusive]).to eq(true)
    end

    it "parses exclusive start range" do
      result = parser.parse("(1..10]")
      ast = transformer.apply(result)
      expect(ast[:type]).to eq(:range)
      expect(ast[:start_inclusive]).to eq(false)
      expect(ast[:end_inclusive]).to eq(true)
    end

    it "parses exclusive end range" do
      result = parser.parse("[1..10)")
      ast = transformer.apply(result)
      expect(ast[:type]).to eq(:range)
      expect(ast[:start_inclusive]).to eq(true)
      expect(ast[:end_inclusive]).to eq(false)
    end

    it "parses fully exclusive range" do
      result = parser.parse("(1..10)")
      ast = transformer.apply(result)
      expect(ast[:type]).to eq(:range)
      expect(ast[:start_inclusive]).to eq(false)
      expect(ast[:end_inclusive]).to eq(false)
    end
  end

  describe "In Expressions" do
    it "evaluates in with list - true case" do
      context = {}
      result = evaluator.evaluate("5 in [1, 3, 5, 7]", "result", context)
      expect(result).to eq(true)
    end

    it "evaluates in with list - false case" do
      context = {}
      result = evaluator.evaluate("4 in [1, 3, 5, 7]", "result", context)
      expect(result).to eq(false)
    end
  end

  describe "Instance Of Expressions" do
    it "checks number type" do
      context = {}
      expect(evaluator.evaluate("42 instance of number", "result", context)).to eq(true)
      expect(evaluator.evaluate('"hello" instance of number', "result", context)).to eq(false)
    end

    it "checks string type" do
      context = {}
      expect(evaluator.evaluate('"hello" instance of string', "result", context)).to eq(true)
      expect(evaluator.evaluate("42 instance of string", "result", context)).to eq(false)
    end

    it "checks boolean type" do
      context = {}
      expect(evaluator.evaluate("true instance of boolean", "result", context)).to eq(true)
      expect(evaluator.evaluate("42 instance of boolean", "result", context)).to eq(false)
    end

    it "checks list type" do
      context = {}
      expect(evaluator.evaluate("[1, 2, 3] instance of list", "result", context)).to eq(true)
      expect(evaluator.evaluate("42 instance of list", "result", context)).to eq(false)
    end

    it "checks context type" do
      context = {}
      expect(evaluator.evaluate("{a: 1} instance of context", "result", context)).to eq(true)
      expect(evaluator.evaluate("42 instance of context", "result", context)).to eq(false)
    end
  end

  describe "Complex Expressions" do
    it "evaluates complex business rule" do
      context = {
        age: 25,
        income: 50000,
        credit_score: 720
      }

      expr = "if age >= 18 and income >= 30000 and credit_score >= 650 then \"approved\" else \"denied\""
      result = evaluator.evaluate(expr, "loan_status", context)
      expect(result).to eq("approved")
    end

    it "evaluates nested arithmetic with comparisons" do
      context = {
        price: 100,
        quantity: 5,
        discount: 10
      }

      expr = "(price * quantity) - discount > 400"
      result = evaluator.evaluate(expr, "qualifies", context)
      expect(result).to eq(true)
    end

    it "combines lists and functions" do
      context = {}
      expr = "sum([1, 2, 3]) + max([4, 5, 6])"
      result = evaluator.evaluate(expr, "result", context)
      expect(result).to eq(12.0)
    end

    it "evaluates filter-like expression with quantifier" do
      context = {}
      expr = "some x in [10, 20, 30] satisfies x > 15"
      result = evaluator.evaluate(expr, "has_large", context)
      expect(result).to eq(true)
    end
  end

  describe "Error Handling" do
    it "raises error for invalid syntax" do
      expect do
        parser.parse("5 +")
      end.to raise_error(DecisionAgent::Dmn::FeelParseError)
    end

    it "falls back gracefully for unsupported expressions" do
      context = {}
      # Should fall back to literal equality
      result = evaluator.evaluate("unknown_syntax", "field", context)
      expect(result).to be_a(Hash) # Returns condition structure
    end
  end
end
