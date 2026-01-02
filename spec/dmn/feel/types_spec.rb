require "spec_helper"
require "decision_agent/dmn/feel/types"

RSpec.describe DecisionAgent::Dmn::Feel::Types do
  describe DecisionAgent::Dmn::Feel::Types::Number do
    it "creates from integer" do
      num = DecisionAgent::Dmn::Feel::Types::Number.new(42)
      expect(num.to_ruby).to eq(42)
      expect(num.to_i).to eq(42)
    end

    it "creates from float" do
      num = DecisionAgent::Dmn::Feel::Types::Number.new(3.14)
      expect(num.to_ruby).to eq(3.14)
      expect(num.to_f).to be_within(0.001).of(3.14)
    end

    it "creates from string" do
      num = DecisionAgent::Dmn::Feel::Types::Number.new("42.5")
      expect(num.to_f).to be_within(0.001).of(42.5)
    end

    it "supports scale tracking" do
      num = DecisionAgent::Dmn::Feel::Types::Number.new(42, scale: 2)
      expect(num.scale).to eq(2)
    end

    it "raises error for invalid type" do
      expect do
        DecisionAgent::Dmn::Feel::Types::Number.new([])
      end.to raise_error(DecisionAgent::Dmn::Feel::FeelTypeError)
    end
  end

  describe DecisionAgent::Dmn::Feel::Types::Date do
    it "creates from Time object" do
      time = Time.new(2024, 1, 15)
      date = DecisionAgent::Dmn::Feel::Types::Date.new(time)
      expect(date.to_ruby).to eq(time)
    end

    it "creates from ISO 8601 string" do
      date = DecisionAgent::Dmn::Feel::Types::Date.new("2024-01-15T10:30:00Z")
      expect(date.to_ruby).to be_a(Time)
    end

    it "creates from date string" do
      date = DecisionAgent::Dmn::Feel::Types::Date.new("2024-01-15")
      expect(date.to_ruby).to be_a(Time)
    end

    it "raises error for invalid format" do
      expect do
        DecisionAgent::Dmn::Feel::Types::Date.new("invalid")
      end.to raise_error(DecisionAgent::Dmn::Feel::FeelTypeError)
    end
  end

  describe DecisionAgent::Dmn::Feel::Types::Time do
    it "creates from Time object" do
      time = Time.new(2024, 1, 15, 10, 30, 0)
      feel_time = DecisionAgent::Dmn::Feel::Types::Time.new(time)
      expect(feel_time.to_ruby).to eq(time)
    end

    it "creates from ISO 8601 string" do
      feel_time = DecisionAgent::Dmn::Feel::Types::Time.new("2024-01-15T10:30:00Z")
      expect(feel_time.to_ruby).to be_a(Time)
    end
  end

  describe DecisionAgent::Dmn::Feel::Types::Duration do
    it "parses ISO 8601 duration with years" do
      duration = DecisionAgent::Dmn::Feel::Types::Duration.parse("P1Y")
      expect(duration.years).to eq(1)
      expect(duration.months).to eq(0)
    end

    it "parses ISO 8601 duration with months" do
      duration = DecisionAgent::Dmn::Feel::Types::Duration.parse("P3M")
      expect(duration.months).to eq(3)
    end

    it "parses ISO 8601 duration with days" do
      duration = DecisionAgent::Dmn::Feel::Types::Duration.parse("P10D")
      expect(duration.days).to eq(10)
    end

    it "parses ISO 8601 duration with time components" do
      duration = DecisionAgent::Dmn::Feel::Types::Duration.parse("PT5H30M15S")
      expect(duration.hours).to eq(5)
      expect(duration.minutes).to eq(30)
      expect(duration.seconds).to eq(15)
    end

    it "parses complete ISO 8601 duration" do
      duration = DecisionAgent::Dmn::Feel::Types::Duration.parse("P1Y2M3DT4H5M6S")
      expect(duration.years).to eq(1)
      expect(duration.months).to eq(2)
      expect(duration.days).to eq(3)
      expect(duration.hours).to eq(4)
      expect(duration.minutes).to eq(5)
      expect(duration.seconds).to eq(6)
    end

    it "converts to seconds" do
      duration = DecisionAgent::Dmn::Feel::Types::Duration.parse("PT1H30M")
      expect(duration.to_seconds).to eq(5400) # 90 minutes
    end

    it "raises error for invalid format" do
      expect do
        DecisionAgent::Dmn::Feel::Types::Duration.parse("invalid")
      end.to raise_error(DecisionAgent::Dmn::Feel::FeelTypeError)
    end

    it "raises error for non-P prefix" do
      expect do
        DecisionAgent::Dmn::Feel::Types::Duration.parse("1Y2M")
      end.to raise_error(DecisionAgent::Dmn::Feel::FeelTypeError, /must start with 'P'/)
    end
  end

  describe DecisionAgent::Dmn::Feel::Types::List do
    it "wraps array" do
      list = DecisionAgent::Dmn::Feel::Types::List.new([1, 2, 3])
      expect(list.to_ruby).to eq([1, 2, 3])
      expect(list[0]).to eq(1)
      expect(list.length).to eq(3)
    end
  end

  describe DecisionAgent::Dmn::Feel::Types::Context do
    it "wraps hash with symbol keys" do
      ctx = DecisionAgent::Dmn::Feel::Types::Context.new({ "name" => "John", "age" => 30 })
      expect(ctx[:name]).to eq("John")
      expect(ctx[:age]).to eq(30)
    end

    it "converts string keys to symbols" do
      ctx = DecisionAgent::Dmn::Feel::Types::Context.new({ "x" => 10, "y" => 20 })
      expect(ctx.to_ruby).to eq({ x: 10, y: 20 })
    end
  end

  describe DecisionAgent::Dmn::Feel::Types::Converter do
    it "converts integer to Number" do
      result = DecisionAgent::Dmn::Feel::Types::Converter.to_feel_type(42)
      expect(result).to be_a(DecisionAgent::Dmn::Feel::Types::Number)
      expect(result.to_ruby).to eq(42)
    end

    it "converts array to List" do
      result = DecisionAgent::Dmn::Feel::Types::Converter.to_feel_type([1, 2, 3])
      expect(result).to be_a(DecisionAgent::Dmn::Feel::Types::List)
      expect(result.to_ruby).to eq([1, 2, 3])
    end

    it "converts hash to Context" do
      result = DecisionAgent::Dmn::Feel::Types::Converter.to_feel_type({ x: 10 })
      expect(result).to be_a(DecisionAgent::Dmn::Feel::Types::Context)
      expect(result.to_ruby).to eq({ x: 10 })
    end

    it "converts FEEL types to Ruby" do
      num = DecisionAgent::Dmn::Feel::Types::Number.new(42)
      result = DecisionAgent::Dmn::Feel::Types::Converter.to_ruby(num)
      expect(result).to eq(42)
    end

    it "returns non-FEEL types as-is" do
      result = DecisionAgent::Dmn::Feel::Types::Converter.to_ruby("hello")
      expect(result).to eq("hello")
    end
  end
end
