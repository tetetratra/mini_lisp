module MiniLisp
  class Compiler
    class << self
      INT_REGEX = /^(-?\d+)$/
      STR_REGEX = /^"(.*)"$/

      def compile(ast)
        first_code, code_table, _macro_table = compile_r(ast, [], {})
        [*code_table, first_code]
      end

      private

      def compile_r(ast, code_table, macro_table)
        case ast
        when String
          case ast
          when INT_REGEX
            [ ["int #{$1}"], code_table, macro_table]
          when STR_REGEX
            [ ["str #{$1}"], code_table, macro_table]
          else
            [ ["get #{ast}"], code_table, macro_table]
          end
        when Array
          method, *args = ast
          case method
          when 'macro'
            args => [macro_name, macro_body]
            [
              [],
              code_table,
              { **macro_table, macro_name => macro_body }
            ]
          when 'q'
            raise '`q` take only one argument.' unless args.size == 1

            compile_quote(args.first, code_table, macro_table, false)
          when 'qq'
            raise '`qq` take only one argument.' unless args.size == 1

            compile_quote(args.first, code_table, macro_table, true)
          when 'uq'
            raise '`uq` must be inside `qq`.'
          when '~'
            args.reduce([[], code_table, macro_table]) do |(mc, mct, mmt), a|
              c, ct, mt = compile_r(a, mct, mmt)
              [[*mc, *c], ct, mt]
            end
          when 'if'
            args.reduce([[], code_table, macro_table]) do |(mc, mct, mmt), a|
              c, ct, mt = compile_r(a, mct, mmt)
              [[*mc, c], ct, mt]
            end => [[if_code, then_code, else_code], new_code_table, new_macro_table]
            [
              [
                *if_code,
                "jumpif #{else_code.size + 1}",
                *else_code,
                "jump #{then_code.size}",
                *then_code,
              ],
              new_code_table,
              new_macro_table
            ]
          when '='
            args => [name_ast, value_ast]
            value_code, new_code_table, new_macro_table = compile_r(value_ast, code_table, macro_table)
            [
              [
                *value_code,
                "set #{name_ast}"
              ],
              new_code_table,
              new_macro_table
            ]
          when '->'
            args => [closure_args, *closure_body]
            closure_body.reduce([[], code_table, macro_table]) do |(mc, mct, mmt), a|
              c, ct, mt = compile_r(a, mct, mmt)
              [[*mc, *c], ct, mt]
            end => [closure_code, new_code_table, new_macro_table]
            [
              [ "closure #{new_code_table.size} #{closure_args.join(',')}" ],
              [*new_code_table, closure_code],
              new_macro_table
            ]
          when macro_table.method(:key?)
            puts "\nexpanding `#{method}` macro." if $debug
            macro_code_table = Compiler.compile([
              macro_table[method],
              *args.map { |a| ['qq', a] }
            ])
            macro_result = Evaluator.exec(macro_code_table)
            puts "expanded to #{macro_result.inspect}.\n" if $debug

            compile_r(macro_result.to_ast, code_table, macro_table)
          else
            [method, *args].reduce([[], code_table, macro_table]) do |(mc, mct, mmt), a|
              c, ct, mt = compile_r(a, mct, mmt)
              [[*mc, *c], ct, mt]
            end => [[method_code, *arg_codes], new_code_table, new_macro_table]
            [
              [
                *arg_codes,
                method_code,
                "send #{args.size}"
              ],
              new_code_table,
              new_macro_table
            ]
          end
        end.tap { raise 'compiler bug!' if _1.nil? }
      end

      def compile_quote(ast, code_table, macro_table, quasiquote)
        case ast
        when String
          case ast
          when INT_REGEX
            [["int #{$1}"], code_table, macro_table]
          when STR_REGEX
            [["str #{$1}"], code_table, macro_table]
          else
            [["symbol #{ast}"], code_table, macro_table]
          end
        when Array
          method, *args = ast
          case method
          in 'uq' if quasiquote
            raise '`uq` take only one argument.' unless args.size == 1

            compile_r(args.first, code_table, macro_table)
          else
            ast.reduce([[], code_table, macro_table]) do |(mc, mct, mmt), a|
              c, ct, mt = compile_quote(a, mct, mmt, quasiquote)
              [[*mc, *c], ct, mt]
            end => [new_code, new_code_table, new_macro_table]
            [
              [
                *new_code,
                'get list',
                "send #{ast.size}"
              ],
              new_code_table,
              new_macro_table
            ]
          end
        end
      end
    end
  end
end

