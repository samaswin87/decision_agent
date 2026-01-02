require "time"
require "date"
require "bigdecimal"
require_relative "../errors"

module DecisionAgent
  module Dmn
    module Feel
      # Type system for FEEL values
      # Provides thin wrappers around Ruby types to maintain FEEL semantics
      module Types
        # Wrapper for numbers with precision tracking
        class Number
          attr_reader :value, :scale

          def initialize(value, scale: nil)
            @value = case value
                     when BigDecimal then value
                     when String then BigDecimal(value)
                     when Integer, Float then value
                     else
                       raise FeelTypeError.new(
                         "Cannot convert to Number",
                         expected_type: "Numeric",
                         actual_type: value.class,
                         value: value
                       )
                     end
            @scale = scale
          end

          def to_ruby
            @value
          end

          def to_i
            @value.to_i
          end

          def to_f
            @value.to_f
          end

          def ==(other)
            return @value == other.value if other.is_a?(Number)

            @value == other
          end

          def inspect
            "#<Feel::Number #{@value}#{@scale ? " (scale: #{@scale})" : ''}>"
          end
        end

        # Wrapper for dates (ISO 8601)
        class Date
          attr_reader :value

          def initialize(value)
            @value = case value
                     when ::Time, ::Date, ::DateTime then value
                     when String then parse_date(value)
                     else
                       raise FeelTypeError.new(
                         "Cannot convert to Date",
                         expected_type: "Date",
                         actual_type: value.class,
                         value: value
                       )
                     end
          end

          def to_ruby
            @value
          end

          def ==(other)
            return @value == other.value if other.is_a?(Date)

            @value == other
          end

          def inspect
            "#<Feel::Date #{@value}>"
          end

          private

          def parse_date(str)
            # Try ISO 8601 formats
            ::Time.iso8601(str)
          rescue ArgumentError
            # Try Ruby Date parsing
            ::Date.parse(str).to_time
          rescue ArgumentError => e
            raise FeelTypeError.new(
              "Invalid date format: #{e.message}",
              expected_type: "ISO 8601 date",
              value: str
            )
          end
        end

        # Wrapper for time values
        class Time
          attr_reader :value

          def initialize(value)
            @value = case value
                     when ::Time then value
                     when String then parse_time(value)
                     else
                       raise FeelTypeError.new(
                         "Cannot convert to Time",
                         expected_type: "Time",
                         actual_type: value.class,
                         value: value
                       )
                     end
          end

          def to_ruby
            @value
          end

          def ==(other)
            return @value == other.value if other.is_a?(Time)

            @value == other
          end

          def inspect
            "#<Feel::Time #{@value}>"
          end

          private

          def parse_time(str)
            # Try ISO 8601 time parsing
            ::Time.iso8601(str)
          rescue ArgumentError => e
            raise FeelTypeError.new(
              "Invalid time format: #{e.message}",
              expected_type: "ISO 8601 time",
              value: str
            )
          end
        end

        # Wrapper for durations (ISO 8601: P1Y2M3DT4H5M6S)
        class Duration
          attr_reader :years, :months, :days, :hours, :minutes, :seconds

          def initialize(years: 0, months: 0, days: 0, hours: 0, minutes: 0, seconds: 0)
            @years = years
            @months = months
            @days = days
            @hours = hours
            @minutes = minutes
            @seconds = seconds
          end

          # Parse ISO 8601 duration string
          # Examples: P1Y, P1M, P1D, PT1H, PT1M, PT1S, P1Y2M3DT4H5M6S
          def self.parse(iso_string)
            raise FeelTypeError.new(
              "Duration must be a string",
              expected_type: "String",
              actual_type: iso_string.class
            ) unless iso_string.is_a?(String)

            raise FeelTypeError.new(
              "Invalid duration format: must start with 'P'",
              value: iso_string
            ) unless iso_string.start_with?("P")

            # Split on 'T' to separate date and time parts
            parts = iso_string[1..].split("T")
            date_part = parts[0] || ""
            time_part = parts[1] || ""

            duration_attrs = {}

            # Parse date part (Y, M, D)
            duration_attrs[:years] = extract_unit(date_part, "Y")
            duration_attrs[:months] = extract_unit(date_part, "M")
            duration_attrs[:days] = extract_unit(date_part, "D")

            # Parse time part (H, M, S)
            duration_attrs[:hours] = extract_unit(time_part, "H")
            duration_attrs[:minutes] = extract_unit(time_part, "M")
            duration_attrs[:seconds] = extract_unit(time_part, "S")

            new(**duration_attrs)
          end

          # Convert to total seconds (approximation for date parts)
          def to_seconds
            total = @seconds
            total += @minutes * 60
            total += @hours * 3600
            total += @days * 86_400
            total += @months * 2_592_000 # 30 days average
            total += @years * 31_536_000 # 365 days
            total
          end

          def to_ruby
            to_seconds
          end

          def ==(other)
            return false unless other.is_a?(Duration)

            @years == other.years &&
              @months == other.months &&
              @days == other.days &&
              @hours == other.hours &&
              @minutes == other.minutes &&
              @seconds == other.seconds
          end

          def inspect
            "#<Feel::Duration P#{@years}Y#{@months}M#{@days}DT#{@hours}H#{@minutes}M#{@seconds}S>"
          end

          private

          def self.extract_unit(str, unit)
            match = str.match(/(\d+(?:\.\d+)?)#{unit}/)
            match ? match[1].to_f.to_i : 0
          end
        end

        # Wrapper for lists (adds FEEL semantics to Ruby Array)
        class List < Array
          def initialize(array = [])
            super(array)
          end

          def to_ruby
            to_a
          end

          def inspect
            "#<Feel::List #{to_a.inspect}>"
          end
        end

        # Wrapper for contexts (FEEL key-value maps)
        class Context < Hash
          def initialize(hash = {})
            super()
            hash.each { |k, v| self[k.to_sym] = v }
          end

          def to_ruby
            to_h
          end

          def inspect
            "#<Feel::Context #{to_h.inspect}>"
          end
        end

        # Type conversion utilities
        module Converter
          def self.to_feel_type(value)
            case value
            when Integer, Float, BigDecimal
              Number.new(value)
            when ::Time, ::DateTime
              Time.new(value)
            when ::Date
              Date.new(value)
            when Array
              List.new(value)
            when Hash
              Context.new(value)
            else
              value # Return as-is for strings, booleans, etc.
            end
          end

          def self.to_ruby(value)
            return value.to_ruby if value.respond_to?(:to_ruby)

            value
          end
        end
      end
    end
  end
end
