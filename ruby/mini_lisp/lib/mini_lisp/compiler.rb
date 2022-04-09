module MiniLisp
  class Compiler
    class << self
      INT_REGEX = /^(-?\d+)$/
      STR_REGEX = /^"(.*)"$/

      def compile(ast)
        first_code, code_table = compile_r(ast, [])
        [*code_table, first_code]
      end

      private

      def compile_r(ast, code_table)
        case ast
        when String
          case ast
          when INT_REGEX
            [ ["int #{$1}"], code_table ]
          when STR_REGEX
            [ ["str #{$1}"], code_table ]
          else
            [ ["get #{ast}"], code_table ]
          end
        when Array
          method, *args = ast
          case method
          when 'qq'
            raise '`qq` take only one argument.' unless args.size == 1
            [
              compile_quote(args.first),
              code_table
            ]
          when 'uq'
            raise '`uq` must be inside `qq`.'
          when '~'
            args.reduce([[], code_table]) do |(mc, mct), a|
              c, ct = compile_r(a, mct)
              [[*mc, *c], ct]
            end
          when 'if'
            args.reduce([[], code_table]) do |(mc, mct), a|
              c, ct = compile_r(a, mct)
              [[*mc, c], ct]
            end => [[if_code, then_code, else_code], new_code_table]
            [
              [
                *if_code,
                "jumpif #{else_code.size + 1}",
                *else_code,
                "jump #{then_code.size}",
                *then_code,
              ],
              new_code_table
            ]
          # when '||'
            # TODO
          # when '&&'
            # TODO
          # when 'while'
            # TODO
          when '='
            args => [name_ast, value_ast]
            value_code, new_code_table = compile_r(value_ast, code_table)
            [
              [
                *value_code,
                "set #{name_ast}"
              ], new_code_table
            ]
          when '->'
            args => [closure_args, *closure_body]
            closure_body.reduce([[], code_table]) do |(mc, mct), a|
              c, ct = compile_r(a, mct)
              [[*mc, *c], ct]
            end => [closure_code, new_code_table]
            [
              [ "closure #{new_code_table.size} #{closure_args.join(',')}" ],
              [*new_code_table, closure_code]
            ]
          else
            [method, *args].reduce([[], code_table]) do |(mc, mct), a|
              c, ct = compile_r(a, mct)
              [[*mc, *c], ct]
            end => [[method_code, *arg_codes], new_code_table]
            [
              [
                *arg_codes,
                method_code,
                "send #{args.size}"
              ],
              new_code_table
            ]
          end
        end
      end

      def compile_quote(ast)
        case ast
        when String
          case ast
          when INT_REGEX
            ["int #{$1}"]
          when STR_REGEX
            ["str #{$1}"]
          else
            ["symbol #{ast}"]
          end
        when Array
          method, *args = ast
          case method
          when 'uq'
            raise '`uq` take only one argument.' unless args.size == 1
            # quote内でクロージャの定義は無効、ということにしておく
            compile_r(args.first, [])[0]
          # when 'uqs'
          else
            [
              *ast.flat_map { |a| compile_quote(a) },
              'get list',
              "send #{ast.size}"
            ]
          end
        end
      end
    end
  end
end

