module MiniLisp
  class Compiler
    class << self
      def compile(ast)
        first_code, code_table = compile_r(ast, [])
        [*code_table, first_code]
      end

      def compile_r(ast, code_table)
        case ast
        in String
          case ast
          when /^-?\d+$/
            [ ["int #{ast}"], code_table ]
          when /^"(.*)"$/
            [ ["str #{$1}"], code_table ]
          when /^'(.*)$/
            [ ["quote #{$1}"], code_table ]
          else
            [ ["get #{ast}"], code_table ]
          end
        in Array
          method, *args = ast
          case method
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
    end
  end
end

