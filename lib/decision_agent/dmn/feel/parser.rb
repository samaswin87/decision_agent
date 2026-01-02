require "parslet"
require_relative "../errors"

module DecisionAgent
  module Dmn
    module Feel
      # Parslet-based FEEL 1.3 expression parser
      # Implements full FEEL grammar including:
      # - Literals (numbers, strings, booleans, null)
      # - Lists and contexts
      # - Arithmetic, comparison, and logical operators
      # - Function calls
      # - Property access and path expressions
      # - Quantified expressions (some/every)
      # - For expressions
      # - If/then/else conditionals
      # - Ranges and intervals
      class Parser < Parslet::Parser
        # Root rule - entry point for parsing
        rule(:expression) { boxed_expression }

        # Boxed expressions - top-level expression types
        rule(:boxed_expression) do
          if_expression |
            quantified_expression |
            for_expression |
            disjunction
        end

        # If-then-else conditional
        rule(:if_expression) do
          str("if") >> space >> expression.as(:condition) >>
            space >> str("then") >> space >> expression.as(:then_expr) >>
            space >> str("else") >> space >> expression.as(:else_expr)
        end

        # Quantified expressions: some/every
        rule(:quantified_expression) do
          quantifier.as(:quantifier) >> space >>
            identifier.as(:var) >> space >>
            str("in") >> space >>
            expression.as(:list) >> space >>
            str("satisfies") >> space >>
            expression.as(:condition)
        end

        rule(:quantifier) { str("some") | str("every") }

        # For expressions
        rule(:for_expression) do
          str("for") >> space >>
            identifier.as(:var) >> space >>
            str("in") >> space >>
            expression.as(:list) >> space >>
            str("return") >> space >>
            expression.as(:return_expr)
        end

        # Logical OR (disjunction)
        rule(:disjunction) do
          (conjunction.as(:left) >>
            (space >> str("or") >> space >>
             conjunction.as(:right)).repeat(1).as(:or_ops)).as(:or) |
            conjunction
        end

        # Logical AND (conjunction)
        rule(:conjunction) do
          (comparison.as(:left) >>
            (space >> str("and") >> space >>
             comparison.as(:right)).repeat(1).as(:and_ops)).as(:and) |
            comparison
        end

        # Comparison operators
        rule(:comparison) do
          (arithmetic.as(:left) >> space? >>
            comparison_op.as(:op) >> space? >>
            arithmetic.as(:right)).as(:comparison) |
            between_expression |
            in_expression |
            instance_of_expression |
            arithmetic
        end

        rule(:comparison_op) do
          str("!=") | str("<=") | str(">=") |
            str("=") | str("<") | str(">")
        end

        # Between expression
        rule(:between_expression) do
          (arithmetic.as(:value) >> space >>
            str("between") >> space >>
            arithmetic.as(:min) >> space >>
            str("and") >> space >>
            arithmetic.as(:max)).as(:between)
        end

        # In expression (list membership)
        rule(:in_expression) do
          (arithmetic.as(:value) >> space >>
            str("in") >> space >>
            (positive_unary_test | simple_positive_unary_tests).as(:list)).as(:in)
        end

        # Instance of type checking
        rule(:instance_of_expression) do
          (arithmetic.as(:value) >> space >>
            str("instance") >> space >> str("of") >> space >>
            type_name.as(:type)).as(:instance_of)
        end

        rule(:type_name) do
          str("number") | str("string") | str("boolean") |
            str("date") | str("time") | str("duration") |
            str("list") | str("context")
        end

        # Arithmetic expressions (addition, subtraction)
        rule(:arithmetic) do
          (term.as(:left) >> space? >>
            arithmetic_op.as(:op) >> space? >>
            arithmetic.as(:right)).as(:arithmetic) |
            term
        end

        rule(:arithmetic_op) { str("+") | str("-") }

        # Term (multiplication, division, modulo)
        rule(:term) do
          (exponentiation.as(:left) >> space? >>
            term_op.as(:op) >> space? >>
            term.as(:right)).as(:term) |
            exponentiation
        end

        rule(:term_op) { str("*") | str("/") | str("%") }

        # Exponentiation
        rule(:exponentiation) do
          (unary.as(:left) >> space? >>
            str("**").as(:op) >> space? >>
            exponentiation.as(:right)).as(:exponentiation) |
            unary
        end

        # Unary expressions (not, negation)
        rule(:unary) do
          (str("not").as(:op) >> space >> unary.as(:operand)).as(:unary) |
            (str("-").as(:op) >> unary.as(:operand)).as(:unary) |
            postfix
        end

        # Postfix expressions (property access, function calls, filtering)
        rule(:postfix) do
          (primary.as(:base) >>
            (property_access | function_call | filter_expression).repeat(1).as(:postfix_ops)).as(:postfix) |
            primary
        end

        # Property access: .property
        rule(:property_access) do
          (str(".") >> identifier.as(:property)).as(:property_access)
        end

        # Function call: (args...)
        rule(:function_call) do
          (str("(") >> space? >>
            arguments.maybe.as(:arguments) >>
            space? >> str(")")).as(:function_call)
        end

        # Filter expression: [condition]
        rule(:filter_expression) do
          (str("[") >> space? >>
            expression.as(:filter) >>
            space? >> str("]")).as(:filter)
        end

        # Function arguments
        rule(:arguments) do
          named_arguments | positional_arguments
        end

        rule(:positional_arguments) do
          expression.as(:arg) >>
            (space? >> str(",") >> space? >> expression.as(:arg)).repeat
        end

        rule(:named_arguments) do
          named_argument >>
            (space? >> str(",") >> space? >> named_argument).repeat
        end

        rule(:named_argument) do
          (identifier.as(:name) >> space? >>
            str(":") >> space? >>
            expression.as(:value)).as(:named_arg)
        end

        # Primary expressions
        rule(:primary) do
          null_literal |
            boolean_literal |
            number_literal |
            string_literal |
            list_literal |
            context_literal |
            range_literal |
            function_definition |
            identifier_or_function |
            parenthesized
        end

        # Null literal
        rule(:null_literal) { str("null").as(:null) }

        # Boolean literals
        rule(:boolean_literal) do
          (str("true") | str("false")).as(:boolean)
        end

        # Number literal
        rule(:number_literal) do
          (str("-").maybe >> match["\\d"] >> match["\\d"].repeat >>
            (str(".") >> match["\\d"].repeat(1)).maybe).as(:number)
        end

        # String literal
        rule(:string_literal) do
          str('"') >>
            (str('\\') >> any | str('"').absent? >> any).repeat.as(:string) >>
            str('"')
        end

        # List literal: [1, 2, 3]
        rule(:list_literal) do
          (str("[") >> space? >>
            (expression >> (space? >> str(",") >> space? >> expression).repeat).maybe.as(:list) >>
            space? >> str("]")).as(:list_literal)
        end

        # Context literal: {a: 1, b: 2}
        rule(:context_literal) do
          (str("{") >> space? >>
            context_entries.maybe.as(:context) >>
            space? >> str("}")).as(:context_literal)
        end

        rule(:context_entries) do
          context_entry >> (space? >> str(",") >> space? >> context_entry).repeat
        end

        rule(:context_entry) do
          (context_key.as(:key) >> space? >>
            str(":") >> space? >>
            expression.as(:value)).as(:entry)
        end

        rule(:context_key) do
          identifier | string_literal
        end

        # Range literal: [1..10], (1..10), etc.
        rule(:range_literal) do
          ((str("[") | str("(")).as(:start_bracket) >>
            space? >>
            expression.as(:start) >>
            space? >> str("..") >> space? >>
            expression.as(:end) >>
            space? >>
            (str("]") | str(")")).as(:end_bracket)).as(:range)
        end

        # Function definition: function(x, y) x + y
        rule(:function_definition) do
          (str("function") >> space? >>
            str("(") >> space? >>
            parameters.maybe.as(:params) >>
            space? >> str(")") >> space? >>
            (str("external") | expression.as(:body))).as(:function_def)
        end

        rule(:parameters) do
          identifier.as(:param) >>
            (space? >> str(",") >> space? >> identifier.as(:param)).repeat
        end

        # Identifier or function name
        rule(:identifier_or_function) do
          (identifier.as(:name) >>
            (str("(") >> space? >>
             arguments.maybe.as(:arguments) >>
             space? >> str(")")).maybe).as(:identifier_or_call)
        end

        # Identifier (variable/field name)
        rule(:identifier) do
          (match["a-zA-Z_"] >> match["a-zA-Z0-9_"].repeat).as(:identifier)
        end

        # Parenthesized expression
        rule(:parenthesized) do
          str("(") >> space? >> expression >> space? >> str(")")
        end

        # Unary tests (for DMN decision tables)
        rule(:simple_positive_unary_tests) do
          (positive_unary_test >>
            (space? >> str(",") >> space? >> positive_unary_test).repeat).as(:unary_tests)
        end

        rule(:positive_unary_test) do
          range_literal | comparison | expression
        end

        # Whitespace
        rule(:space) { match["\\s"].repeat(1) }
        rule(:space?) { match["\\s"].repeat }

        # Root parsing method
        root(:expression)

        # Parse with error handling
        def self.parse_expression(input)
          new.parse(input)
        rescue Parslet::ParseFailed => e
          raise FeelParseError.new(
            "Failed to parse FEEL expression: #{e.parse_failure_cause.ascii_tree}",
            expression: input,
            position: e.parse_failure_cause.pos.offset
          )
        end
      end
    end
  end
end
