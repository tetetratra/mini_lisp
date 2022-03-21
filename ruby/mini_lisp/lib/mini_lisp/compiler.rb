module MiniLisp
  class Compiler
    def self.compile(s_exp)
      code_table = [ nil ] # rootのために一時的にnilを置いておく
      compile_r = -> (exp) do
        case exp
        in String => str
          [ "str@#{str}" ]
        in Integer => i
          [ "int@#{i}" ]
        in Symbol => s
          [ "get@#{s}" ]
        in Array
          case exp.first
          in :~
            exp[1..].map { |e| compile_r.(e) }
          in :if
            if_exp = exp[1]
            then_exp = exp[2]
            else_exp = exp[3]
            if_compiled = compile_r.(if_exp)
            then_compiled = compile_r.(then_exp)
            else_compiled = compile_r.(else_exp)
            [
              *if_compiled,
              "jumpif@#{else_compiled.size + 1}",
              *else_compiled,
              "jump@#{then_compiled.size}",
              *then_compiled,
            ]
          in :'||'
            [
              *compile_r.(exp[1]),
              *exp[2..].map(&compile_r).flat_map { |e_compiled|
                [
                  "jumpif@#{e_compiled.size}",
                  *e_compiled
                ]
              }
            ]
          in :'&&'
            [
              *compile_r.(exp[1]),
              *exp[2..].map(&compile_r).flat_map { |e_compiled|
                [
                  "jumpunless@#{e_compiled.size}",
                  *e_compiled
                ]
              }
            ]
          in :while
            cond = exp[1]
            statements = exp[2..]
            compiled_cond = compile_r.(cond)
            compiled_statements = statements.flat_map { |s| compile_r.(s) }
            [
              *compiled_cond,
              "jumpunless@#{compiled_statements.size + 1}",
              *compiled_statements,
              "jump@#{-(2 + compiled_statements.size + compiled_cond.size)}",
              'get@nil'
            ]
          in :'='
            raise "variable `#{exp[1]}` in `#{exp}` is not symbol" unless Symbol === exp[1]

            [*compile_r.(exp[2]), "set@#{exp[1]}"]
          in :'->'
            args = exp[1]
            codes = exp[2..]
            raise "argument `#{args.find { Symbol != _1 }}` in `#{exp}` must be symbol" unless args.all? { Symbol === _1 }

            codes_index = code_table.size
            code_table[codes_index] = nil # TODO 改善したい
            code_table[codes_index] = codes.flat_map { |code| compile_r.(code) }
            [ "closure@#{codes_index}@#{args.join(',')}" ]
          in Symbol | Array
            method = exp.first
            args = exp[1..]
            [
              *args.map { |a| compile_r.(a) },
              *compile_r.(method),
              "send@#{args.size}"
            ]
          end
        end.flatten(1)
      end
      root = compile_r.(s_exp)
      code_table[0] = root
      code_table.map.with_index { |a,i| [i, a] }.to_h
    end
  end
end
