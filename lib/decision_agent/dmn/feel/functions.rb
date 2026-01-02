require_relative "../errors"
require_relative "types"

module DecisionAgent
  module Dmn
    module Feel
      # Built-in FEEL functions registry
      # Functions either map to ConditionEvaluator operators or provide custom evaluation
      module Functions
        # Function registry
        REGISTRY = {}

        # Base class for all functions
        class Base
          class << self
            # Register function with one or more names
            def register(*names)
              names.each { |name| REGISTRY[name.to_s] = self }
            end

            # Execute function with arguments and context
            # Returns either a value or a ConditionEvaluator condition structure
            def call(args, context = {})
              raise NotImplementedError, "Subclasses must implement call"
            end

            # Validate argument count
            def validate_arg_count(args, expected)
              actual = args.length
              if expected.is_a?(Range)
                return if expected.cover?(actual)

                raise FeelFunctionError.new(
                  "Wrong number of arguments (got #{actual}, expected #{expected})",
                  function_name: name,
                  arguments: args
                )
              else
                return if actual == expected

                raise FeelFunctionError.new(
                  "Wrong number of arguments (got #{actual}, expected #{expected})",
                  function_name: name,
                  arguments: args
                )
              end
            end
          end
        end

        #
        # STRING FUNCTIONS
        #

        class Substring < Base
          register "substring", "substr"

          def self.call(args, context = {})
            validate_arg_count(args, 2..3)
            str = args[0].to_s
            start_pos = args[1].to_i - 1 # FEEL is 1-indexed
            length = args[2]&.to_i

            return str[start_pos..] if length.nil?

            str[start_pos, length] || ""
          end
        end

        class StringLength < Base
          register "string length", "length"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            args[0].to_s.length
          end
        end

        class UpperCase < Base
          register "upper case", "upper"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            args[0].to_s.upcase
          end
        end

        class LowerCase < Base
          register "lower case", "lower"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            args[0].to_s.downcase
          end
        end

        class Contains < Base
          register "contains"

          def self.call(args, context = {})
            validate_arg_count(args, 2)
            args[0].to_s.include?(args[1].to_s)
          end
        end

        class StartsWith < Base
          register "starts with"

          def self.call(args, context = {})
            validate_arg_count(args, 2)
            args[0].to_s.start_with?(args[1].to_s)
          end
        end

        class EndsWith < Base
          register "ends with"

          def self.call(args, context = {})
            validate_arg_count(args, 2)
            args[0].to_s.end_with?(args[1].to_s)
          end
        end

        class SubstringBefore < Base
          register "substring before"

          def self.call(args, context = {})
            validate_arg_count(args, 2)
            str = args[0].to_s
            match = args[1].to_s
            idx = str.index(match)
            idx ? str[0...idx] : ""
          end
        end

        class SubstringAfter < Base
          register "substring after"

          def self.call(args, context = {})
            validate_arg_count(args, 2)
            str = args[0].to_s
            match = args[1].to_s
            idx = str.index(match)
            idx ? str[(idx + match.length)..] : ""
          end
        end

        class Replace < Base
          register "replace"

          def self.call(args, context = {})
            validate_arg_count(args, 3)
            args[0].to_s.gsub(args[1].to_s, args[2].to_s)
          end
        end

        #
        # NUMERIC FUNCTIONS
        #

        class Abs < Base
          register "abs", "absolute"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            args[0].to_f.abs
          end
        end

        class Floor < Base
          register "floor"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            args[0].to_f.floor
          end
        end

        class Ceiling < Base
          register "ceiling", "ceil"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            args[0].to_f.ceil
          end
        end

        class Round < Base
          register "round"

          def self.call(args, context = {})
            validate_arg_count(args, 1..2)
            value = args[0].to_f
            precision = args[1]&.to_i || 0
            value.round(precision)
          end
        end

        class Sqrt < Base
          register "sqrt", "square root"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            Math.sqrt(args[0].to_f)
          end
        end

        class Modulo < Base
          register "modulo", "mod"

          def self.call(args, context = {})
            validate_arg_count(args, 2)
            args[0].to_f % args[1].to_f
          end
        end

        class Odd < Base
          register "odd"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            args[0].to_i.odd?
          end
        end

        class Even < Base
          register "even"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            args[0].to_i.even?
          end
        end

        #
        # LIST FUNCTIONS
        #

        class Count < Base
          register "count"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            list = args[0]
            return 0 unless list.is_a?(Array) || list.is_a?(Types::List)

            list.length
          end
        end

        class Sum < Base
          register "sum"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            list = args[0]
            return 0 unless list.is_a?(Array) || list.is_a?(Types::List)

            list.map(&:to_f).sum
          end
        end

        class Mean < Base
          register "mean", "average"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            list = args[0]
            return 0 unless list.is_a?(Array) || list.is_a?(Types::List)
            return 0 if list.empty?

            list.map(&:to_f).sum / list.length.to_f
          end
        end

        class Min < Base
          register "min", "minimum"

          def self.call(args, context = {})
            # Can accept multiple args or a single list
            values = args.length == 1 && (args[0].is_a?(Array) || args[0].is_a?(Types::List)) ? args[0] : args
            return nil if values.empty?

            values.map(&:to_f).min
          end
        end

        class Max < Base
          register "max", "maximum"

          def self.call(args, context = {})
            # Can accept multiple args or a single list
            values = args.length == 1 && (args[0].is_a?(Array) || args[0].is_a?(Types::List)) ? args[0] : args
            return nil if values.empty?

            values.map(&:to_f).max
          end
        end

        class Append < Base
          register "append"

          def self.call(args, context = {})
            validate_arg_count(args, 2..)
            list = Array(args[0])
            items = args[1..]
            list + items
          end
        end

        class Reverse < Base
          register "reverse"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            Array(args[0]).reverse
          end
        end

        class IndexOf < Base
          register "index of"

          def self.call(args, context = {})
            validate_arg_count(args, 2)
            list = Array(args[0])
            match = args[1]
            # FEEL is 1-indexed, Ruby is 0-indexed
            idx = list.index(match)
            idx ? idx + 1 : -1
          end
        end

        class DistinctValues < Base
          register "distinct values", "unique"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            Array(args[0]).uniq
          end
        end

        #
        # BOOLEAN FUNCTIONS
        #

        class Not < Base
          register "not"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            !args[0]
          end
        end

        class All < Base
          register "all"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            list = Array(args[0])
            list.all? { |item| item == true || item == "true" }
          end
        end

        class Any < Base
          register "any"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            list = Array(args[0])
            list.any? { |item| item == true || item == "true" }
          end
        end

        #
        # DATE/TIME FUNCTIONS (Basic implementations)
        #

        class DateFunction < Base
          register "date"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            Types::Date.new(args[0])
          end
        end

        class TimeFunction < Base
          register "time"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            Types::Time.new(args[0])
          end
        end

        class DurationFunction < Base
          register "duration"

          def self.call(args, context = {})
            validate_arg_count(args, 1)
            Types::Duration.parse(args[0])
          end
        end

        # Lookup function by name
        def self.get(name)
          REGISTRY[name.to_s]
        end

        # Execute a function
        def self.execute(name, args, context = {})
          func = get(name)
          raise FeelFunctionError.new(
            "Unknown function: #{name}",
            function_name: name
          ) unless func

          func.call(args, context)
        end

        # List all registered functions
        def self.list
          REGISTRY.keys.sort
        end
      end
    end
  end
end
