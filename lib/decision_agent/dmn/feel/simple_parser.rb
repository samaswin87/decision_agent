require_relative "../errors"
require_relative "types"

module DecisionAgent
  module Dmn
    module Feel
      # Simple regex-based parser for common FEEL expressions
      # Handles arithmetic, logical operators, and simple comparisons
      # Uses operator precedence climbing for correct evaluation order
      class SimpleParser
        ARITHMETIC_OPS = %w[+ - * / ** %].freeze
        LOGICAL_OPS = %w[and or].freeze
        COMPARISON_OPS = %w[>= <= != > < =].freeze

        # Operator precedence (higher number = higher precedence)
        PRECEDENCE = {
          "or" => 1,
          "and" => 2,
          "=" => 3,
          "!=" => 3,
          "<" => 4,
          "<=" => 4,
          ">" => 4,
          ">=" => 4,
          "+" => 5,
          "-" => 5,
          "*" => 6,
          "/" => 6,
          "%" => 6,
          "**" => 7
        }.freeze

        def initialize
          @tokens = []
          @position = 0
        end

        # Check if expression can be handled by simple parser
        def self.can_parse?(expression)
          expr = expression.to_s.strip
          # Can't handle: lists, contexts, functions, quantifiers, for expressions
          return false if expr.match?(/[\[\{]/) # Lists or contexts
          return false if expr.match?(/\w+\s*\(/) # Function calls
          return false if expr.match?(/\b(some|every|for|if)\b/) # Complex constructs

          true
        end

        # Parse expression and return AST-like structure
        def parse(expression)
          expr = expression.to_s.strip
          raise FeelParseError.new("Empty expression", expression: expression) if expr.empty?

          @tokens = tokenize(expr)
          @position = 0

          parse_expression
        end

        private

        # Tokenize the expression
        def tokenize(expr)
          tokens = []
          i = 0

          while i < expr.length
            char = expr[i]

            # Skip whitespace
            if char.match?(/\s/)
              i += 1
              next
            end

            # Check for multi-character operators
            if i + 1 < expr.length
              two_char = expr[i, 2]
              if %w[>= <= != ** or].include?(two_char)
                tokens << { type: :operator, value: two_char }
                i += 2
                next
              elsif two_char == "an" && i + 2 < expr.length && expr[i, 3] == "and"
                tokens << { type: :operator, value: "and" }
                i += 3
                next
              end
            end

            # Single character operators
            if "+-*/%><()=".include?(char)
              type = %w[( )].include?(char) ? :paren : :operator
              tokens << { type: type, value: char }
              i += 1
              next
            end

            # Numbers (integer or float)
            if char.match?(/\d/) || (char == "-" && i + 1 < expr.length && expr[i + 1].match?(/\d/))
              num_str = ""
              num_str << char if char == "-"
              i += 1 if char == "-"

              while i < expr.length && expr[i].match?(/[\d.]/)
                num_str << expr[i]
                i += 1
              end

              value = num_str.include?(".") ? num_str.to_f : num_str.to_i
              tokens << { type: :number, value: value }
              next
            end

            # Quoted strings
            if char == '"'
              str = ""
              i += 1
              while i < expr.length && expr[i] != '"'
                str << expr[i]
                i += 1
              end
              i += 1 # Skip closing quote
              tokens << { type: :string, value: str }
              next
            end

            # Booleans and keywords
            if char.match?(/[a-zA-Z]/)
              word = ""
              while i < expr.length && expr[i].match?(/[a-zA-Z_]/)
                word << expr[i]
                i += 1
              end

              case word.downcase
              when "true"
                tokens << { type: :boolean, value: true }
              when "false"
                tokens << { type: :boolean, value: false }
              when "not"
                tokens << { type: :operator, value: "not" }
              when "and", "or"
                tokens << { type: :operator, value: word.downcase }
              else
                # Field reference
                tokens << { type: :field, value: word }
              end
              next
            end

            raise FeelParseError.new(
              "Unexpected character: #{char}",
              expression: expr,
              position: i
            )
          end

          tokens
        end

        # Parse expression with operator precedence
        def parse_expression(min_precedence = 0)
          left = parse_unary

          while @position < @tokens.length
            token = current_token
            break unless token && token[:type] == :operator

            op = token[:value]
            precedence = PRECEDENCE[op]
            break if precedence.nil? || precedence < min_precedence

            consume_token # Consume operator

            right = parse_expression(precedence + 1)

            left = {
              type: operator_type(op),
              operator: op,
              left: left,
              right: right
            }
          end

          left
        end

        # Parse unary expressions (not, -, +)
        def parse_unary
          token = current_token

          if token && token[:type] == :operator
            if token[:value] == "not"
              consume_token
              operand = parse_unary
              return {
                type: :logical,
                operator: "not",
                operand: operand
              }
            elsif token[:value] == "-"
              consume_token
              operand = parse_unary
              return {
                type: :arithmetic,
                operator: "negate",
                operand: operand
              }
            elsif token[:value] == "+"
              consume_token # Skip unary plus
              return parse_unary
            end
          end

          parse_primary
        end

        # Parse primary expressions (numbers, strings, booleans, fields, parentheses)
        def parse_primary
          token = current_token

          raise FeelParseError.new("Unexpected end of expression") unless token

          case token[:type]
          when :number
            consume_token
            { type: :literal, value: token[:value] }

          when :string
            consume_token
            { type: :literal, value: token[:value] }

          when :boolean
            consume_token
            { type: :literal, value: token[:value] }

          when :field
            consume_token
            { type: :field, name: token[:value] }

          when :paren
            if token[:value] == "("
              consume_token
              expr = parse_expression
              closing = current_token
              raise FeelParseError.new("Expected closing parenthesis") unless closing && closing[:value] == ")"

              consume_token
              expr
            else
              raise FeelParseError.new("Unexpected closing parenthesis")
            end

          else
            raise FeelParseError.new("Unexpected token: #{token.inspect}")
          end
        end

        def current_token
          @tokens[@position]
        end

        def consume_token
          @position += 1
        end

        def operator_type(op)
          return :arithmetic if ARITHMETIC_OPS.include?(op)
          return :logical if LOGICAL_OPS.include?(op) || op == "not"
          return :comparison if COMPARISON_OPS.include?(op)

          :unknown
        end
      end
    end
  end
end
