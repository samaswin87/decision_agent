require "spec_helper"
require "decision_agent/dmn/feel/simple_parser"

RSpec.describe DecisionAgent::Dmn::Feel::SimpleParser do
  let(:parser) { described_class.new }

  describe ".can_parse?" do
    it "returns true for simple arithmetic" do
      expect(described_class.can_parse?("age + 5")).to be true
      expect(described_class.can_parse?("price * 1.1")).to be true
    end

    it "returns true for logical expressions" do
      expect(described_class.can_parse?("age >= 18 and status = active")).to be true
    end

    it "returns false for lists" do
      expect(described_class.can_parse?("[1, 2, 3]")).to be false
    end

    it "returns false for contexts" do
      expect(described_class.can_parse?("{x: 10}")).to be false
    end

    it "returns false for functions" do
      expect(described_class.can_parse?("sum(scores)")).to be false
    end

    it "returns false for quantified expressions" do
      expect(described_class.can_parse?("some x in list satisfies x > 5")).to be false
    end
  end

  describe "#parse" do
    describe "literals" do
      it "parses integer" do
        result = parser.parse("42")
        expect(result[:type]).to eq(:literal)
        expect(result[:value]).to eq(42)
      end

      it "parses float" do
        result = parser.parse("3.14")
        expect(result[:type]).to eq(:literal)
        expect(result[:value]).to eq(3.14)
      end

      it "parses negative number" do
        result = parser.parse("-10")
        expect(result[:type]).to eq(:literal)
        expect(result[:value]).to eq(-10)
      end

      it "parses string" do
        result = parser.parse('"hello"')
        expect(result[:type]).to eq(:literal)
        expect(result[:value]).to eq("hello")
      end

      it "parses boolean true" do
        result = parser.parse("true")
        expect(result[:type]).to eq(:boolean)
        expect(result[:value]).to be true
      end

      it "parses boolean false" do
        result = parser.parse("false")
        expect(result[:type]).to eq(:boolean)
        expect(result[:value]).to be false
      end
    end

    describe "field references" do
      it "parses field name" do
        result = parser.parse("age")
        expect(result[:type]).to eq(:field)
        expect(result[:name]).to eq("age")
      end
    end

    describe "arithmetic operators" do
      it "parses addition" do
        result = parser.parse("5 + 3")
        expect(result[:type]).to eq(:arithmetic)
        expect(result[:operator]).to eq("+")
        expect(result[:left][:value]).to eq(5)
        expect(result[:right][:value]).to eq(3)
      end

      it "parses subtraction" do
        result = parser.parse("10 - 3")
        expect(result[:type]).to eq(:arithmetic)
        expect(result[:operator]).to eq("-")
      end

      it "parses multiplication" do
        result = parser.parse("4 * 5")
        expect(result[:type]).to eq(:arithmetic)
        expect(result[:operator]).to eq("*")
      end

      it "parses division" do
        result = parser.parse("20 / 4")
        expect(result[:type]).to eq(:arithmetic)
        expect(result[:operator]).to eq("/")
      end

      it "parses exponentiation" do
        result = parser.parse("2 ** 3")
        expect(result[:type]).to eq(:arithmetic)
        expect(result[:operator]).to eq("**")
      end

      it "parses modulo" do
        result = parser.parse("10 % 3")
        expect(result[:type]).to eq(:arithmetic)
        expect(result[:operator]).to eq("%")
      end
    end

    describe "operator precedence" do
      it "respects multiplication before addition" do
        result = parser.parse("2 + 3 * 4")
        # Should be: 2 + (3 * 4)
        expect(result[:operator]).to eq("+")
        expect(result[:left][:value]).to eq(2)
        expect(result[:right][:operator]).to eq("*")
      end

      it "respects exponentiation before multiplication" do
        result = parser.parse("2 * 3 ** 2")
        # Should be: 2 * (3 ** 2)
        expect(result[:operator]).to eq("*")
        expect(result[:right][:operator]).to eq("**")
      end

      it "handles parentheses" do
        result = parser.parse("(2 + 3) * 4")
        # Should be: (2 + 3) * 4
        expect(result[:operator]).to eq("*")
        expect(result[:left][:operator]).to eq("+")
      end
    end

    describe "comparison operators" do
      it "parses greater than or equal" do
        result = parser.parse("age >= 18")
        expect(result[:type]).to eq(:comparison)
        expect(result[:operator]).to eq(">=")
        expect(result[:left][:name]).to eq("age")
        expect(result[:right][:value]).to eq(18)
      end

      it "parses less than or equal" do
        result = parser.parse("score <= 100")
        expect(result[:type]).to eq(:comparison)
        expect(result[:operator]).to eq("<=")
      end

      it "parses greater than" do
        result = parser.parse("price > 0")
        expect(result[:type]).to eq(:comparison)
        expect(result[:operator]).to eq(">")
      end

      it "parses less than" do
        result = parser.parse("age < 65")
        expect(result[:type]).to eq(:comparison)
        expect(result[:operator]).to eq("<")
      end

      it "parses not equal" do
        result = parser.parse("status != pending")
        expect(result[:type]).to eq(:comparison)
        expect(result[:operator]).to eq("!=")
      end

      it "parses equal" do
        result = parser.parse("status = active")
        expect(result[:type]).to eq(:comparison)
        expect(result[:operator]).to eq("=")
      end
    end

    describe "logical operators" do
      it "parses AND" do
        result = parser.parse("age >= 18 and score > 700")
        expect(result[:type]).to eq(:logical)
        expect(result[:operator]).to eq("and")
        expect(result[:left][:type]).to eq(:comparison)
        expect(result[:right][:type]).to eq(:comparison)
      end

      it "parses OR" do
        result = parser.parse("status = active or status = pending")
        expect(result[:type]).to eq(:logical)
        expect(result[:operator]).to eq("or")
      end

      it "parses NOT" do
        result = parser.parse("not active")
        expect(result[:type]).to eq(:logical)
        expect(result[:operator]).to eq("not")
        expect(result[:operand][:name]).to eq("active")
      end

      it "respects AND precedence over OR" do
        result = parser.parse("a or b and c")
        # Should be: a or (b and c)
        expect(result[:operator]).to eq("or")
        expect(result[:right][:operator]).to eq("and")
      end
    end

    describe "unary operators" do
      it "parses unary minus" do
        result = parser.parse("-5")
        expect(result[:type]).to eq(:literal)
        expect(result[:value]).to eq(-5)
      end

      it "parses unary minus with field" do
        result = parser.parse("-age")
        expect(result[:type]).to eq(:arithmetic)
        expect(result[:operator]).to eq("negate")
        expect(result[:operand][:name]).to eq("age")
      end

      it "parses unary plus (ignored)" do
        result = parser.parse("+5")
        expect(result[:value]).to eq(5)
      end
    end

    describe "complex expressions" do
      it "parses arithmetic with comparison" do
        result = parser.parse("age + 5 >= 18")
        expect(result[:type]).to eq(:comparison)
        expect(result[:left][:type]).to eq(:arithmetic)
      end

      it "parses multiple logical operations" do
        result = parser.parse("age >= 18 and age <= 65 and status = active")
        expect(result[:type]).to eq(:logical)
        expect(result[:operator]).to eq("and")
      end

      it "parses nested parentheses" do
        result = parser.parse("((age + 5) * 2) >= 40")
        expect(result[:type]).to eq(:comparison)
      end
    end

    describe "error handling" do
      it "raises error for empty expression" do
        expect do
          parser.parse("")
        end.to raise_error(DecisionAgent::Dmn::Feel::FeelParseError, /Empty expression/)
      end

      it "raises error for unbalanced parentheses" do
        expect do
          parser.parse("(age + 5")
        end.to raise_error(DecisionAgent::Dmn::Feel::FeelParseError)
      end

      it "raises error for unexpected character" do
        expect do
          parser.parse("age @ 5")
        end.to raise_error(DecisionAgent::Dmn::Feel::FeelParseError, /Unexpected character/)
      end
    end
  end
end
