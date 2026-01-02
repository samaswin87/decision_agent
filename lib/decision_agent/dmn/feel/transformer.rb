require "parslet"
require_relative "../errors"

module DecisionAgent
  module Dmn
    module Feel
      # Transforms Parslet parse tree into AST
      class Transformer < Parslet::Transform
        # Literals
        rule(null: simple(:_)) { { type: :null, value: nil } }

        rule(boolean: simple(:val)) do
          { type: :boolean, value: val.to_s == "true" }
        end

        rule(number: simple(:val)) do
          str = val.to_s
          value = str.include?(".") ? str.to_f : str.to_i
          { type: :number, value: value }
        end

        rule(string: simple(:val)) do
          { type: :string, value: val.to_s }
        end

        # Argument wrapper (unwrap the arg node to get the inner expression)
        rule(arg: subtree(:expr)) do
          expr
        end

        # List literal
        rule(list_literal: { list: subtree(:items) }) do
          items_array = case items
                        when Array then items
                        when Hash then [items]
                        when nil then []
                        else [items]
                        end
          { type: :list_literal, elements: items_array }
        end

        # Context entry (unwrap the entry wrapper)
        rule(entry: { key: subtree(:k), value: subtree(:v) }) do
          { key: k, value: v }
        end

        # Context literal
        rule(context_literal: { context: subtree(:entries) }) do
          entries_array = case entries
                          when Array then entries
                          when Hash then [entries]
                          when nil then []
                          else [entries]
                          end

          pairs = entries_array.map do |entry|
            # Extract key - could be a transformed field node, string node, or raw value
            key = if entry[:key].is_a?(Hash)
                    # Key is a structured node
                    if entry[:key][:type] == :field
                      entry[:key][:name].to_s
                    elsif entry[:key][:type] == :string
                      entry[:key][:value].to_s
                    elsif entry[:key][:type] == :identifier
                      entry[:key][:name].to_s
                    else
                      entry[:key][:identifier]&.to_s || entry[:key][:string]&.to_s || entry[:key].to_s
                    end
                  elsif entry[:key].is_a?(Parslet::Slice)
                    entry[:key].to_s
                  else
                    entry[:key].to_s
                  end

            [key, entry[:value]]
          end

          { type: :context_literal, pairs: pairs }
        end

        # Range literal
        rule(range: {
               start_bracket: simple(:sb),
               start: subtree(:s),
               end: subtree(:e),
               end_bracket: simple(:eb)
             }) do
          {
            type: :range,
            start: s,
            end: e,
            start_inclusive: sb.to_s == "[",
            end_inclusive: eb.to_s == "]"
          }
        end

        # Identifier
        rule(identifier: simple(:name)) do
          { type: :field, name: name.to_s.strip }
        end

        # Identifier or function call (with arguments)
        rule(identifier_or_call: { name: subtree(:name), arguments: subtree(:args) }) do
          # It's a function call
          args_array = case args
                       when Array then args
                       when Hash then args.empty? ? [] : [args]
                       when nil then []
                       else [args]
                       end

          func_name = case name
                      when Hash
                        # Handle transformed field nodes or raw identifier hashes
                        if name[:type] == :field
                          name[:name].to_s.strip
                        else
                          name[:identifier]&.to_s&.strip || name.to_s
                        end
                      else
                        name.to_s.strip
                      end

          {
            type: :function_call,
            name: func_name,
            arguments: args_array
          }
        end

        # Identifier or function call (just identifier, no arguments)
        rule(identifier_or_call: { name: subtree(:name) }) do
          # Just an identifier
          field_name = case name
                       when Hash
                         name[:identifier]&.to_s&.strip || name[:type] == :field ? name[:name] : name.to_s
                       else
                         name.to_s.strip
                       end

          { type: :field, name: field_name }
        end

        # Comparison operations
        rule(comparison: { left: subtree(:l), op: simple(:o), right: subtree(:r) }) do
          {
            type: :comparison,
            operator: o.to_s,
            left: l,
            right: r
          }
        end

        # Between expression
        rule(between: { value: subtree(:val), min: subtree(:min), max: subtree(:max) }) do
          {
            type: :between,
            value: val,
            min: min,
            max: max
          }
        end

        # In expression
        rule(in: { value: subtree(:val), list: subtree(:list) }) do
          {
            type: :in,
            value: val,
            list: list
          }
        end

        # Instance of
        rule(instance_of: { value: subtree(:val), type: simple(:t) }) do
          {
            type: :instance_of,
            value: val,
            type_name: t.to_s
          }
        end

        # Arithmetic operations
        rule(arithmetic: { left: subtree(:l), op: simple(:o), right: subtree(:r) }) do
          {
            type: :arithmetic,
            operator: o.to_s,
            left: l,
            right: r
          }
        end

        rule(term: { left: subtree(:l), op: simple(:o), right: subtree(:r) }) do
          {
            type: :arithmetic,
            operator: o.to_s,
            left: l,
            right: r
          }
        end

        rule(exponentiation: { left: subtree(:l), op: simple(:o), right: subtree(:r) }) do
          {
            type: :arithmetic,
            operator: o.to_s,
            left: l,
            right: r
          }
        end

        # Unary operations
        rule(unary: { op: simple(:o), operand: subtree(:operand) }) do
          if o.to_s == "not"
            {
              type: :logical,
              operator: "not",
              operand: operand
            }
          elsif o.to_s == "-" && operand.is_a?(Hash) && operand[:type] == :number
            # Special case: unary minus on a number literal -> negative number literal
            {
              type: :number,
              value: -operand[:value]
            }
          else
            {
              type: :arithmetic,
              operator: "negate",
              operand: operand
            }
          end
        end

        # Logical operations
        rule(or: { left: subtree(:l), or_ops: subtree(:ops) }) do
          ops_array = Array(ops)
          # Build nested or structure
          ops_array.reduce(l) do |left_side, op|
            {
              type: :logical,
              operator: "or",
              left: left_side,
              right: op[:right]
            }
          end
        end

        rule(and: { left: subtree(:l), and_ops: subtree(:ops) }) do
          ops_array = Array(ops)
          # Build nested and structure
          ops_array.reduce(l) do |left_side, op|
            {
              type: :logical,
              operator: "and",
              left: left_side,
              right: op[:right]
            }
          end
        end

        # Postfix operations (property access, function calls, filters)
        rule(postfix: { base: subtree(:base), postfix_ops: subtree(:ops) }) do
          ops_array = Array(ops)
          ops_array.reduce(base) do |current, op|
            case op
            when Hash
              if op[:property_access]
                {
                  type: :property_access,
                  object: current,
                  property: op[:property_access][:property][:identifier].to_s
                }
              elsif op[:function_call]
                {
                  type: :function_call,
                  name: current,
                  arguments: op[:function_call][:arguments] || []
                }
              elsif op[:filter]
                {
                  type: :filter,
                  list: current,
                  condition: op[:filter][:filter]
                }
              else
                current
              end
            else
              current
            end
          end
        end

        # If-then-else conditional
        rule(condition: subtree(:c), then_expr: subtree(:t), else_expr: subtree(:e)) do
          {
            type: :conditional,
            condition: c,
            then_expr: t,
            else_expr: e
          }
        end

        # Quantified expressions
        rule(quantifier: simple(:q), var: subtree(:v), list: subtree(:l), condition: subtree(:c)) do
          # Variable might be already transformed to a field node or still be an identifier hash
          var_name = if v.is_a?(Hash) && v[:type] == :field
                       v[:name]
                     elsif v.is_a?(Hash) && v[:identifier]
                       v[:identifier].to_s
                     else
                       v.to_s
                     end

          {
            type: :quantified,
            quantifier: q.to_s,
            variable: var_name,
            list: l,
            condition: c
          }
        end

        # For expression
        rule(var: subtree(:v), list: subtree(:l), return_expr: subtree(:r)) do
          # Variable might be already transformed to a field node or still be an identifier hash
          var_name = if v.is_a?(Hash) && v[:type] == :field
                       v[:name]
                     elsif v.is_a?(Hash) && v[:identifier]
                       v[:identifier].to_s
                     else
                       v.to_s
                     end

          {
            type: :for,
            variable: var_name,
            list: l,
            return_expr: r
          }
        end

        # Function definition
        rule(function_def: { params: subtree(:params), body: subtree(:body) }) do
          params_array = case params
                         when Array then params.map { |p| p[:param][:identifier].to_s }
                         when Hash then [params[:param][:identifier].to_s]
                         when nil then []
                         else []
                         end

          {
            type: :function_definition,
            parameters: params_array,
            body: body
          }
        end

        # Helper to convert parse tree to AST
        def self.to_ast(parse_tree)
          new.apply(parse_tree)
        rescue => e
          raise FeelTransformError.new(
            "Failed to transform parse tree to AST: #{e.message}",
            parse_tree: parse_tree,
            error: e
          )
        end
      end
    end
  end
end
