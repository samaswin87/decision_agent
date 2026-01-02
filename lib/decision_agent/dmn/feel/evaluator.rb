require_relative "../errors"
require_relative "simple_parser"
require_relative "parser"
require_relative "transformer"
require_relative "functions"
require_relative "types"
require_relative "../../dsl/condition_evaluator"

module DecisionAgent
  module Dmn
    module Feel
      # FEEL expression evaluator with hybrid parsing strategy
      # Phase 2A: Basic comparisons, ranges, list membership (regex-based)
      # Phase 2B: Arithmetic, logical operators, functions (enhanced parser)
      # Maps FEEL expressions to DecisionAgent ConditionEvaluator
      class Evaluator
        def initialize
          @simple_parser = SimpleParser.new
          @parslet_parser = Parser.new
          @transformer = Transformer.new
          @cache = {}
          @use_parslet = true # Enable full Parslet parser
        end

        # Evaluate a FEEL expression against a context
        # @param expression [String] FEEL expression (e.g., ">= 18", "in [1,2,3]", "age + 5")
        # @param field_name [String] The field name being evaluated
        # @param context [Hash] Evaluation context
        # @return [Boolean] Evaluation result
        def evaluate(expression, field_name, context)
          return true if expression == "-" # DMN "don't care" marker

          # Try Parslet parser first (Phase 2B)
          if @use_parslet
            begin
              parse_tree = @parslet_parser.parse(expression.to_s.strip)
              ast = @transformer.apply(parse_tree)
              return evaluate_ast_node(ast, context)
            rescue Parslet::ParseFailed, FeelTransformError => e
              # Fall back to Phase 2A approach
              warn "Parslet parse failed: #{e.message}, falling back" if ENV["DEBUG_FEEL"]
            end
          end

          # Phase 2A approach: use condition structures
          # Check cache first
          cache_key = "#{expression}::#{field_name}"
          if @cache.key?(cache_key)
            condition = @cache[cache_key]
            return Dsl::ConditionEvaluator.evaluate(condition, context)
          end

          # Parse and translate expression to condition structure
          condition = parse_expression_to_condition(expression, field_name, context)
          @cache[cache_key] = condition

          # Delegate to existing ConditionEvaluator
          Dsl::ConditionEvaluator.evaluate(condition, context)
        end

        # Parse FEEL expression into operator and value (for internal use by Adapter)
        # This maintains backward compatibility with Phase 2A
        def parse_expression(expr)
          expr = expr.to_s.strip

          # Handle literal values (quoted strings, numbers, booleans)
          return parse_literal(expr) if literal?(expr)

          # Handle comparison operators
          return parse_comparison(expr) if comparison_expression?(expr)

          # Handle list membership
          return parse_list_membership(expr) if list_expression?(expr)

          # Handle range expressions
          return parse_range(expr) if range_expression?(expr)

          # Check if it's a simple parsable expression (arithmetic/logical)
          if SimpleParser.can_parse?(expr)
            begin
              ast = @simple_parser.parse(expr)
              return translate_ast(ast, nil)
            rescue FeelParseError
              # Fall back to literal equality
            end
          end

          # Default: equality
          { operator: "eq", value: parse_value(expr) }
        end

        private

        def literal?(expr)
          # Quoted string
          return true if expr.start_with?('"') && expr.end_with?('"')
          # Number
          return true if expr.match?(/^-?\d+(\.\d+)?$/)
          # Boolean
          return true if %w[true false].include?(expr.downcase)

          false
        end

        def parse_literal(expr)
          if expr.start_with?('"') && expr.end_with?('"')
            # String literal
            { operator: "eq", value: expr[1..-2] }
          elsif expr.match?(/^-?\d+\.\d+$/)
            # Float
            { operator: "eq", value: expr.to_f }
          elsif expr.match?(/^-?\d+$/)
            # Integer
            { operator: "eq", value: expr.to_i }
          elsif expr.downcase == "true"
            { operator: "eq", value: true }
          elsif expr.downcase == "false"
            { operator: "eq", value: false }
          else
            { operator: "eq", value: expr }
          end
        end

        def comparison_expression?(expr)
          expr.match?(/^(>=|<=|>|<|!=|=)/)
        end

        def parse_comparison(expr)
          # Extract operator
          operator_match = expr.match(/^(>=|<=|>|<|!=|=)\s*(.+)/)
          return { operator: "eq", value: expr } unless operator_match

          feel_op = operator_match[1]
          value_str = operator_match[2]

          # Map FEEL operator to ConditionEvaluator operator
          condition_op = case feel_op
                         when ">=" then "gte"
                         when "<=" then "lte"
                         when ">" then "gt"
                         when "<" then "lt"
                         when "!=" then "neq"
                         when "=" then "eq"
                         else "eq"
                         end

          { operator: condition_op, value: parse_value(value_str) }
        end

        def list_expression?(expr)
          expr.match?(/\[.+\]/)
        end

        def parse_list_membership(expr)
          # Handle "in [1, 2, 3]" or just "[1, 2, 3]"
          list_match = expr.match(/(?:in\s+)?\[(.+)\]/)
          return { operator: "eq", value: expr } unless list_match

          items_str = list_match[1]
          items = items_str.split(",").map { |item| parse_value(item.strip) }

          { operator: "in", value: items }
        end

        def range_expression?(expr)
          # FEEL ranges like "[10..20]", "(10..20)", etc.
          expr.match?(/[\[\(]\d+(\.\d+)?\.\.\d+(\.\d+)?[\]\)]/)
        end

        def parse_range(expr)
          # Parse FEEL range syntax: [min..max], (min..max), [min..max), (min..max]
          range_match = expr.match(/([\[\(])(\d+(?:\.\d+)?)\.\.(\d+(?:\.\d+)?)([\]\)])/)
          return { operator: "eq", value: expr } unless range_match

          inclusive_start = range_match[1] == "["
          min_val = parse_value(range_match[2])
          max_val = parse_value(range_match[3])
          inclusive_end = range_match[4] == "]"

          # For Phase 2A, we only support fully inclusive ranges
          # Map to 'between' operator
          if inclusive_start && inclusive_end
            { operator: "between", value: [min_val, max_val] }
          else
            # Fall back to complex condition (Phase 2B)
            raise FeelParseError,
                  "Half-open ranges not yet supported: #{expr}. " \
                  "Use [min..max] for inclusive ranges."
          end
        end

        def parse_value(str)
          str = str.to_s.strip

          # Remove quotes
          if str.start_with?('"') && str.end_with?('"')
            return str[1..-2]
          end

          # Try to parse as number
          if str.match?(/^-?\d+\.\d+$/)
            return str.to_f
          elsif str.match?(/^-?\d+$/)
            return str.to_i
          end

          # Boolean
          return true if str.downcase == "true"
          return false if str.downcase == "false"

          # Return as string
          str
        end

        # Parse expression to condition structure (Phase 2A backward compatibility)
        def parse_expression_to_condition(expression, field_name, context)
          expr = expression.to_s.strip

          # Try Phase 2A patterns
          if literal?(expr) || comparison_expression?(expr) || list_expression?(expr) || range_expression?(expr)
            parsed = parse_expression(expr)
            return {
              "field" => field_name,
              "op" => parsed[:operator],
              "value" => parsed[:value]
            }
          end

          # Try simple parser for arithmetic/logical expressions
          if SimpleParser.can_parse?(expr)
            begin
              ast = @simple_parser.parse(expr)
              return translate_ast(ast, field_name, context)
            rescue FeelParseError => e
              warn "FEEL parse warning: #{e.message}, falling back to literal match"
            end
          end

          # Default: literal equality
          {
            "field" => field_name,
            "op" => "eq",
            "value" => parse_value(expr)
          }
        end

        # Translate AST to ConditionEvaluator format
        def translate_ast(node, field_name, context = {})
          case node[:type]
          when :literal
            # Just a value
            return node[:value] if field_name.nil?

            { "field" => field_name, "op" => "eq", "value" => node[:value] }

          when :field
            # Field reference - get value from context
            context.to_h[node[:name].to_sym] || context.to_h[node[:name]]

          when :arithmetic
            translate_arithmetic(node, field_name, context)

          when :logical
            translate_logical(node, field_name, context)

          when :comparison
            translate_comparison(node, field_name, context)

          else
            raise FeelEvaluationError.new("Unknown AST node type: #{node[:type]}", expression: node.inspect)
          end
        end

        # Translate arithmetic operations
        def translate_arithmetic(node, _field_name, context)
          op = node[:operator]

          if op == "negate"
            # Unary negation
            operand_val = evaluate_ast_value(node[:operand], context)
            return -operand_val
          end

          # Binary arithmetic
          left_val = evaluate_ast_value(node[:left], context)
          right_val = evaluate_ast_value(node[:right], context)

          case op
          when "+" then left_val + right_val
          when "-" then left_val - right_val
          when "*" then left_val * right_val
          when "/" then left_val / right_val.to_f
          when "**" then left_val**right_val
          when "%" then left_val % right_val
          else
            raise FeelEvaluationError, "Unknown arithmetic operator: #{op}"
          end
        end

        # Translate logical operations
        def translate_logical(node, field_name, context)
          op = node[:operator]

          if op == "not"
            # Unary NOT
            operand = translate_ast(node[:operand], nil, context)
            return { "all" => [{ "field" => field_name, "op" => "eq", "value" => false }] } if operand == true
            return { "all" => [{ "field" => field_name, "op" => "eq", "value" => true }] } if operand == false

            return !operand
          end

          # Binary logical (and, or)
          left_condition = ast_to_condition(node[:left], field_name, context)
          right_condition = ast_to_condition(node[:right], field_name, context)

          case op
          when "and"
            { "all" => [left_condition, right_condition] }
          when "or"
            { "any" => [left_condition, right_condition] }
          else
            raise FeelEvaluationError, "Unknown logical operator: #{op}"
          end
        end

        # Translate comparison operations
        def translate_comparison(node, _field_name, context)
          left_val = evaluate_ast_value(node[:left], context)
          right_val = evaluate_ast_value(node[:right], context)
          op = node[:operator]

          # Map FEEL comparison to ConditionEvaluator operator
          condition_op = case op
                         when ">=" then "gte"
                         when "<=" then "lte"
                         when ">" then "gt"
                         when "<" then "lt"
                         when "!=" then "neq"
                         when "=" then "eq"
                         else "eq"
                         end

          # If left side is a field reference, use it as the field
          if node[:left][:type] == :field
            return {
              "field" => node[:left][:name],
              "op" => condition_op,
              "value" => right_val
            }
          end

          # Otherwise, evaluate both sides and return boolean result
          case op
          when ">=" then left_val >= right_val
          when "<=" then left_val <= right_val
          when ">" then left_val > right_val
          when "<" then left_val < right_val
          when "!=" then left_val != right_val
          when "=" then left_val == right_val
          else left_val == right_val
          end
        end

        # Convert AST node to condition structure
        def ast_to_condition(node, field_name, context)
          case node[:type]
          when :comparison
            translate_comparison(node, field_name, context)
          when :logical
            translate_logical(node, field_name, context)
          when :field
            # Field reference in boolean context
            { "field" => node[:name], "op" => "eq", "value" => true }
          when :literal
            # Literal in boolean context
            { "field" => field_name, "op" => "eq", "value" => node[:value] }
          else
            # Evaluate and create condition
            val = translate_ast(node, nil, context)
            { "field" => field_name, "op" => "eq", "value" => val }
          end
        end

        # Evaluate AST node to get a value (not a condition)
        def evaluate_ast_value(node, context)
          case node[:type]
          when :literal
            node[:value]
          when :field
            context.to_h[node[:name].to_sym] || context.to_h[node[:name]] || 0
          when :arithmetic
            translate_arithmetic(node, nil, context)
          else
            translate_ast(node, nil, context)
          end
        end

        # Evaluate Parslet AST node (Phase 2B - full FEEL support)
        def evaluate_ast_node(node, context)
          return node unless node.is_a?(Hash)

          case node[:type]
          when :number, :string, :boolean
            node[:value]
          when :null
            nil
          when :field
            get_field_value(node[:name], context)
          when :list
            evaluate_list(node, context)
          when :context
            evaluate_context(node, context)
          when :range
            evaluate_range(node, context)
          when :function_call
            evaluate_function_call(node, context)
          when :property_access
            evaluate_property_access(node, context)
          when :comparison
            evaluate_comparison_node(node, context)
          when :arithmetic
            evaluate_arithmetic_node(node, context)
          when :logical
            evaluate_logical_node(node, context)
          when :conditional
            evaluate_conditional(node, context)
          when :quantified
            evaluate_quantified(node, context)
          when :for
            evaluate_for(node, context)
          when :filter
            evaluate_filter(node, context)
          when :between
            evaluate_between(node, context)
          when :in
            evaluate_in_node(node, context)
          when :instance_of
            evaluate_instance_of(node, context)
          else
            raise FeelEvaluationError, "Unknown AST node type: #{node[:type]}"
          end
        end

        # Get field value from context
        def get_field_value(field_name, context)
          ctx = context.to_h
          ctx[field_name.to_sym] || ctx[field_name] || ctx[field_name.to_s]
        end

        # Evaluate list literal
        def evaluate_list(node, context)
          return [] if node[:elements].nil? || node[:elements].empty?

          Array(node[:elements]).map { |elem| evaluate_ast_node(elem, context) }
        end

        # Evaluate context literal
        def evaluate_context(node, context)
          result = {}
          return result if node[:pairs].nil? || node[:pairs].empty?

          node[:pairs].each do |key, value|
            result[key.to_sym] = evaluate_ast_node(value, context)
          end
          result
        end

        # Evaluate range
        def evaluate_range(node, context)
          start_val = evaluate_ast_node(node[:start], context)
          end_val = evaluate_ast_node(node[:end], context)

          {
            type: :range,
            start: start_val,
            end: end_val,
            start_inclusive: node[:start_inclusive],
            end_inclusive: node[:end_inclusive]
          }
        end

        # Evaluate function call
        def evaluate_function_call(node, context)
          function_name = node[:name].is_a?(Hash) ? node[:name][:name] : node[:name]
          args = Array(node[:arguments]).map { |arg| evaluate_ast_node(arg, context) }

          Functions.execute(function_name.to_s, args, context)
        end

        # Evaluate property access
        def evaluate_property_access(node, context)
          object = evaluate_ast_node(node[:object], context)
          property = node[:property]

          case object
          when Hash
            object[property.to_sym] || object[property.to_s] || object[property]
          when Types::Context
            object[property.to_sym]
          else
            object.respond_to?(property) ? object.send(property) : nil
          end
        end

        # Evaluate comparison node
        def evaluate_comparison_node(node, context)
          left_val = evaluate_ast_node(node[:left], context)
          right_val = evaluate_ast_node(node[:right], context)

          case node[:operator]
          when "=" then left_val == right_val
          when "!=" then left_val != right_val
          when "<" then left_val < right_val
          when ">" then left_val > right_val
          when "<=" then left_val <= right_val
          when ">=" then left_val >= right_val
          else false
          end
        end

        # Evaluate arithmetic node
        def evaluate_arithmetic_node(node, context)
          if node[:operand]
            # Unary operation
            operand_val = evaluate_ast_node(node[:operand], context)
            return node[:operator] == "negate" ? -operand_val : operand_val
          end

          # Binary operation
          left_val = evaluate_ast_node(node[:left], context)
          right_val = evaluate_ast_node(node[:right], context)

          case node[:operator]
          when "+" then left_val + right_val
          when "-" then left_val - right_val
          when "*" then left_val * right_val
          when "/" then left_val / right_val.to_f
          when "**" then left_val**right_val
          when "%" then left_val % right_val
          else 0
          end
        end

        # Evaluate logical node
        def evaluate_logical_node(node, context)
          if node[:operand]
            # Unary NOT
            operand_val = evaluate_ast_node(node[:operand], context)
            return !operand_val
          end

          # Binary operation
          left_val = evaluate_ast_node(node[:left], context)

          case node[:operator]
          when "and"
            return false unless left_val

            right_val = evaluate_ast_node(node[:right], context)
            left_val && right_val
          when "or"
            return true if left_val

            right_val = evaluate_ast_node(node[:right], context)
            left_val || right_val
          else
            false
          end
        end

        # Evaluate if/then/else conditional
        def evaluate_conditional(node, context)
          condition_val = evaluate_ast_node(node[:condition], context)

          if condition_val
            evaluate_ast_node(node[:then_expr], context)
          else
            evaluate_ast_node(node[:else_expr], context)
          end
        end

        # Evaluate quantified expression (some/every)
        def evaluate_quantified(node, context)
          list_val = evaluate_ast_node(node[:list], context)
          return false unless list_val.is_a?(Array) || list_val.is_a?(Types::List)

          variable = node[:variable]

          case node[:quantifier]
          when "some"
            Array(list_val).any? do |item|
              item_context = context.to_h.merge(variable.to_sym => item)
              evaluate_ast_node(node[:condition], item_context)
            end
          when "every"
            Array(list_val).all? do |item|
              item_context = context.to_h.merge(variable.to_sym => item)
              evaluate_ast_node(node[:condition], item_context)
            end
          else
            false
          end
        end

        # Evaluate for expression
        def evaluate_for(node, context)
          list_val = evaluate_ast_node(node[:list], context)
          return [] unless list_val.is_a?(Array) || list_val.is_a?(Types::List)

          variable = node[:variable]

          Array(list_val).map do |item|
            item_context = context.to_h.merge(variable.to_sym => item)
            evaluate_ast_node(node[:return_expr], item_context)
          end
        end

        # Evaluate filter expression
        def evaluate_filter(node, context)
          list_val = evaluate_ast_node(node[:list], context)
          return [] unless list_val.is_a?(Array) || list_val.is_a?(Types::List)

          Array(list_val).select do |item|
            # For filter, use 'item' as the implicit variable
            item_context = if item.is_a?(Hash)
                             context.to_h.merge(item)
                           else
                             context.to_h.merge(item: item)
                           end
            evaluate_ast_node(node[:condition], item_context)
          end
        end

        # Evaluate between expression
        def evaluate_between(node, context)
          value = evaluate_ast_node(node[:value], context)
          min_val = evaluate_ast_node(node[:min], context)
          max_val = evaluate_ast_node(node[:max], context)

          value >= min_val && value <= max_val
        end

        # Evaluate in expression
        def evaluate_in_node(node, context)
          value = evaluate_ast_node(node[:value], context)
          list_val = evaluate_ast_node(node[:list], context)

          if list_val.is_a?(Array) || list_val.is_a?(Types::List)
            Array(list_val).include?(value)
          elsif list_val.is_a?(Hash) && list_val[:type] == :range
            # Check if value is in range
            in_range?(value, list_val)
          else
            false
          end
        end

        # Evaluate instance of expression
        def evaluate_instance_of(node, context)
          value = evaluate_ast_node(node[:value], context)
          type_name = node[:type_name]

          case type_name
          when "number"
            value.is_a?(Numeric)
          when "string"
            value.is_a?(String)
          when "boolean"
            value.is_a?(TrueClass) || value.is_a?(FalseClass)
          when "date"
            value.is_a?(Types::Date) || value.is_a?(Date) || value.is_a?(Time)
          when "time"
            value.is_a?(Types::Time) || value.is_a?(Time)
          when "duration"
            value.is_a?(Types::Duration)
          when "list"
            value.is_a?(Array) || value.is_a?(Types::List)
          when "context"
            value.is_a?(Hash) || value.is_a?(Types::Context)
          else
            false
          end
        end

        # Check if value is in range
        def in_range?(value, range)
          start_check = range[:start_inclusive] ? value >= range[:start] : value > range[:start]
          end_check = range[:end_inclusive] ? value <= range[:end] : value < range[:end]
          start_check && end_check
        end
      end
    end
  end
end
