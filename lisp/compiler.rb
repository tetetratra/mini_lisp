class Lisp
  class Compiler
    def self.compile(s_exp)
      code_table = [ nil ] # rootのために一時的にnilを置いておく
      compile_r = -> (exp) do
        case exp
        in Integer => i
          [ "#{i}" ]
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
          in :while
            cond = exp[1]
            statements = exp[2..]
            compiled_cond = compile_r.(cond)
            compiled_statements = statements.flat_map { |s| compile_r.(s) }
            [
              *compiled_cond,
              'get@!',
              'send@1',
              "jumpif@#{compiled_statements.size + 1}",
              *compiled_statements,
              "jump@#{-(4 + compiled_statements.size + compiled_cond.size)}"
            ]
          in :'='
            raise "variable `#{exp[1]}` in `#{exp}` is not symbol" unless Symbol === exp[1]
            [*compile_r.(exp[2]), "set@#{exp[1]}"]
          in :'->'
            args = exp[1]
            raise "argument `#{args.find { Symbol != _1 }}` in `#{exp}` must be symbol" unless args.all? { |a| Symbol === a }
            codes = exp[2..]
            code_table << codes.flat_map { |code| compile_r.(code) }
            [ "closure@#{code_table.size - 1}@#{args.join(',')}" ] # 環境とコードをもったオブジェクトを作成する命令
          in Symbol | Array
            method = exp.first
            args = exp[1..]
            [*args.map { |a| compile_r.(a) }, compile_r.(method), "send@#{args.size}"]
          end
        end.flatten(1)
      end
      root = compile_r.(s_exp)
      code_table[0] = root
      code_table.map.with_index { |a,i| [i, a] }.to_h
    end
  end
end
