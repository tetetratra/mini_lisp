class Proc
  alias __inspect__ inspect
  def inspect
    'proc' + __inspect__[/:\d+ /][/\d+/]
  end
end

class Lisp
  class << self
    def parse(str)
      regex = /\(|\)|[\w\d\-+=*%_@^~<>?$&|!]+/
      tokens = str.gsub(/#.*/, '').gsub(/\s+/, ' ').scan(regex).map do |token|
        case token
        when /^\d+$/
          token.to_i
        else
          token.to_sym
        end
      end
      parsed = [tokens.shift]
      until tokens.empty?
        parsed <<
          case s = tokens.shift
          when :')'
            poped = [:')']
            until poped in [:'(', *rest, :')']
              poped = [parsed.pop, *poped]
            end
            poped[1..-2]
          else
            s
          end
      end
      parsed.first
    end

    def run(src)
      parsed = parse(src)
      pp parsed
      code_table = make_code_table(parsed)
      puts '~~~~~~~~~'
      pp code_table
      exec(code_table)
    end

    def make_code_table(s_exp)
      code_table = {}
      compile = -> (exp) do
        pp exp
        case exp
        in Integer => i
          [ "#{i}" ]
        in Symbol => s
          [ "get@#{s}" ]
        in Array
          case exp.first
          in :~
            exp[1..].map { |e| compile.(e) }
          in :'='
            raise unless Symbol === exp[1]
            [*compile.(exp[2]), "=@#{exp[1]}"]
          in :'->'
            args = exp[1]
            raise unless args.all? { |a| Symbol === a }
            code = exp[2]
            n = code_table.size + 1
            code_table[n] = args.flat_map{|a| "=:@#{a}" } + compile.(code)
            [ "closure@#{n}" ] # 環境とコードをもったオブジェクトを作成する命令
          in Symbol => method
            args = exp[1..]
            [*args.map { |a| compile.(a) }, "send@#{method}@#{args.size}"]
          end
        end.flatten(1)
      end
      root = compile.(s_exp)
      code_table[0] = root
      code_table.sort_by { |k,v| k }.to_h
    end

    StackFrame = Struct.new(:env, :sp, :code)

    def exec(code_table)
      puts '~~~~~~~~~'
      call_stack = [
        StackFrame[
          {
            :'+' => ->(args){ args.inject(:+) }
          },
          0,
          code_table[0]
        ]
      ]
      vm_stack = []
      until call_stack.empty?
        stack_frame = call_stack[-1]
        line = stack_frame.code[stack_frame.sp]

        p call_stack
        p vm_stack
        p line
        puts '------------'
        sleep 1

        case line
        when /^(\d+)/
          vm_stack << $1.to_i
        when /^=@(\w+)/
          name = $1.to_sym
          value = vm_stack.last
          call_stack[-1].env[name] = value
        when /^get@(\w+)/
          var_name = $1.to_sym
          value = call_stack.map(&:env).reverse.find { |env| env[var_name] }[var_name]
          vm_stack << value
        when /^closure@(.+?)@(.+?)/
          args = $1
          codes = $2
          vm_stack << Closure

        when /^send@(.+?)@(\d+)/
          method_name = $1.to_sym
          argc = $2.to_i
          method = call_stack.map(&:env).reverse.find { |env| env[method_name] }[method_name]
          args = argc.times.map { vm_stack.pop }
          vm_stack << method.(args)
        else
          raise
        end
        stack_frame.sp += 1

        if stack_frame.sp == stack_frame.code.size
          call_stack.pop
        end
      end

      p call_stack
      p vm_stack
      p line
      puts '!!!!!!!!!!!!'
    end
  end
end

Lisp.run(<<~LISP)
(~
  (= a 100)
  (= f (-> (x)
    x
  ))
  (f 10)
)
LISP

