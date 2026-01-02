require "spec_helper"
require "decision_agent/dmn/feel/functions"

RSpec.describe DecisionAgent::Dmn::Feel::Functions do
  describe "String Functions" do
    describe "substring" do
      it "extracts substring with start and length" do
        result = described_class.execute("substring", ["hello world", 1, 5])
        expect(result).to eq("hello")
      end

      it "extracts substring from start to end" do
        result = described_class.execute("substring", ["hello world", 7])
        expect(result).to eq("world")
      end

      it "handles 1-based indexing" do
        result = described_class.execute("substring", ["abc", 2, 1])
        expect(result).to eq("b")
      end
    end

    describe "string length" do
      it "returns length of string" do
        result = described_class.execute("string length", ["hello"])
        expect(result).to eq(5)
      end

      it "returns 0 for empty string" do
        result = described_class.execute("string length", [""])
        expect(result).to eq(0)
      end
    end

    describe "upper case" do
      it "converts to uppercase" do
        result = described_class.execute("upper case", ["hello"])
        expect(result).to eq("HELLO")
      end
    end

    describe "lower case" do
      it "converts to lowercase" do
        result = described_class.execute("lower case", ["HELLO"])
        expect(result).to eq("hello")
      end
    end

    describe "contains" do
      it "returns true when substring is found" do
        result = described_class.execute("contains", ["hello world", "world"])
        expect(result).to be true
      end

      it "returns false when substring is not found" do
        result = described_class.execute("contains", ["hello world", "xyz"])
        expect(result).to be false
      end
    end

    describe "starts with" do
      it "returns true when string starts with prefix" do
        result = described_class.execute("starts with", ["hello world", "hello"])
        expect(result).to be true
      end

      it "returns false when string does not start with prefix" do
        result = described_class.execute("starts with", ["hello world", "world"])
        expect(result).to be false
      end
    end

    describe "ends with" do
      it "returns true when string ends with suffix" do
        result = described_class.execute("ends with", ["hello world", "world"])
        expect(result).to be true
      end

      it "returns false when string does not end with suffix" do
        result = described_class.execute("ends with", ["hello world", "hello"])
        expect(result).to be false
      end
    end

    describe "substring before" do
      it "returns substring before match" do
        result = described_class.execute("substring before", ["hello world", " "])
        expect(result).to eq("hello")
      end

      it "returns empty string when match not found" do
        result = described_class.execute("substring before", ["hello", "x"])
        expect(result).to eq("")
      end
    end

    describe "substring after" do
      it "returns substring after match" do
        result = described_class.execute("substring after", ["hello world", " "])
        expect(result).to eq("world")
      end

      it "returns empty string when match not found" do
        result = described_class.execute("substring after", ["hello", "x"])
        expect(result).to eq("")
      end
    end

    describe "replace" do
      it "replaces all occurrences" do
        result = described_class.execute("replace", ["hello world", "l", "L"])
        expect(result).to eq("heLLo worLd")
      end
    end
  end

  describe "Numeric Functions" do
    describe "abs" do
      it "returns absolute value of positive number" do
        result = described_class.execute("abs", [5])
        expect(result).to eq(5.0)
      end

      it "returns absolute value of negative number" do
        result = described_class.execute("abs", [-5])
        expect(result).to eq(5.0)
      end
    end

    describe "floor" do
      it "rounds down to integer" do
        result = described_class.execute("floor", [3.7])
        expect(result).to eq(3)
      end

      it "handles negative numbers" do
        result = described_class.execute("floor", [-3.2])
        expect(result).to eq(-4)
      end
    end

    describe "ceiling" do
      it "rounds up to integer" do
        result = described_class.execute("ceiling", [3.2])
        expect(result).to eq(4)
      end

      it "handles negative numbers" do
        result = described_class.execute("ceiling", [-3.7])
        expect(result).to eq(-3)
      end
    end

    describe "round" do
      it "rounds to nearest integer" do
        result = described_class.execute("round", [3.7])
        expect(result).to eq(4)
      end

      it "rounds to specified precision" do
        result = described_class.execute("round", [3.14159, 2])
        expect(result).to be_within(0.001).of(3.14)
      end
    end

    describe "sqrt" do
      it "calculates square root" do
        result = described_class.execute("sqrt", [16])
        expect(result).to eq(4.0)
      end
    end

    describe "modulo" do
      it "calculates remainder" do
        result = described_class.execute("modulo", [10, 3])
        expect(result).to eq(1.0)
      end
    end

    describe "odd" do
      it "returns true for odd numbers" do
        result = described_class.execute("odd", [5])
        expect(result).to be true
      end

      it "returns false for even numbers" do
        result = described_class.execute("odd", [4])
        expect(result).to be false
      end
    end

    describe "even" do
      it "returns true for even numbers" do
        result = described_class.execute("even", [4])
        expect(result).to be true
      end

      it "returns false for odd numbers" do
        result = described_class.execute("even", [5])
        expect(result).to be false
      end
    end
  end

  describe "List Functions" do
    describe "count" do
      it "returns length of list" do
        result = described_class.execute("count", [[1, 2, 3, 4, 5]])
        expect(result).to eq(5)
      end

      it "returns 0 for empty list" do
        result = described_class.execute("count", [[]])
        expect(result).to eq(0)
      end

      it "returns 0 for non-array" do
        result = described_class.execute("count", [42])
        expect(result).to eq(0)
      end
    end

    describe "sum" do
      it "calculates sum of list" do
        result = described_class.execute("sum", [[1, 2, 3, 4, 5]])
        expect(result).to eq(15.0)
      end

      it "returns 0 for empty list" do
        result = described_class.execute("sum", [[]])
        expect(result).to eq(0)
      end
    end

    describe "mean" do
      it "calculates average of list" do
        result = described_class.execute("mean", [[1, 2, 3, 4, 5]])
        expect(result).to eq(3.0)
      end

      it "returns 0 for empty list" do
        result = described_class.execute("mean", [[]])
        expect(result).to eq(0)
      end
    end

    describe "min" do
      it "returns minimum value from list" do
        result = described_class.execute("min", [[5, 2, 8, 1, 9]])
        expect(result).to eq(1.0)
      end

      it "returns minimum from multiple arguments" do
        result = described_class.execute("min", [5, 2, 8, 1, 9])
        expect(result).to eq(1.0)
      end

      it "returns nil for empty list" do
        result = described_class.execute("min", [[]])
        expect(result).to be_nil
      end
    end

    describe "max" do
      it "returns maximum value from list" do
        result = described_class.execute("max", [[5, 2, 8, 1, 9]])
        expect(result).to eq(9.0)
      end

      it "returns maximum from multiple arguments" do
        result = described_class.execute("max", [5, 2, 8, 1, 9])
        expect(result).to eq(9.0)
      end
    end

    describe "append" do
      it "appends items to list" do
        result = described_class.execute("append", [[1, 2], 3, 4])
        expect(result).to eq([1, 2, 3, 4])
      end
    end

    describe "reverse" do
      it "reverses list" do
        result = described_class.execute("reverse", [[1, 2, 3, 4, 5]])
        expect(result).to eq([5, 4, 3, 2, 1])
      end
    end

    describe "index of" do
      it "returns 1-based index of element" do
        result = described_class.execute("index of", [[10, 20, 30], 20])
        expect(result).to eq(2)
      end

      it "returns -1 when element not found" do
        result = described_class.execute("index of", [[10, 20, 30], 40])
        expect(result).to eq(-1)
      end
    end

    describe "distinct values" do
      it "removes duplicates" do
        result = described_class.execute("distinct values", [[1, 2, 2, 3, 3, 3]])
        expect(result).to eq([1, 2, 3])
      end
    end
  end

  describe "Boolean Functions" do
    describe "not" do
      it "negates true" do
        result = described_class.execute("not", [true])
        expect(result).to be false
      end

      it "negates false" do
        result = described_class.execute("not", [false])
        expect(result).to be true
      end
    end

    describe "all" do
      it "returns true when all items are true" do
        result = described_class.execute("all", [[true, true, true]])
        expect(result).to be true
      end

      it "returns false when any item is false" do
        result = described_class.execute("all", [[true, false, true]])
        expect(result).to be false
      end
    end

    describe "any" do
      it "returns true when any item is true" do
        result = described_class.execute("any", [[false, true, false]])
        expect(result).to be true
      end

      it "returns false when all items are false" do
        result = described_class.execute("any", [[false, false, false]])
        expect(result).to be false
      end
    end
  end

  describe "Date/Time Functions" do
    describe "date" do
      it "parses ISO 8601 date string" do
        result = described_class.execute("date", ["2024-01-15T10:30:00Z"])
        expect(result).to be_a(DecisionAgent::Dmn::Feel::Types::Date)
      end
    end

    describe "time" do
      it "parses ISO 8601 time string" do
        result = described_class.execute("time", ["2024-01-15T10:30:00Z"])
        expect(result).to be_a(DecisionAgent::Dmn::Feel::Types::Time)
      end
    end

    describe "duration" do
      it "parses ISO 8601 duration" do
        result = described_class.execute("duration", ["P1Y2M3DT4H5M6S"])
        expect(result).to be_a(DecisionAgent::Dmn::Feel::Types::Duration)
        expect(result.years).to eq(1)
        expect(result.months).to eq(2)
      end
    end
  end

  describe "Function Registry" do
    it "lists all registered functions" do
      functions = described_class.list
      expect(functions).to include("substring")
      expect(functions).to include("sum")
      expect(functions).to include("abs")
    end

    it "gets function by name" do
      func = described_class.get("substring")
      expect(func).not_to be_nil
    end

    it "raises error for unknown function" do
      expect do
        described_class.execute("unknown_func", [])
      end.to raise_error(DecisionAgent::Dmn::Feel::FeelFunctionError, /Unknown function/)
    end
  end

  describe "Argument Validation" do
    it "raises error for wrong argument count" do
      expect do
        described_class.execute("substring", ["hello"])
      end.to raise_error(DecisionAgent::Dmn::Feel::FeelFunctionError, /Wrong number of arguments/)
    end
  end
end
