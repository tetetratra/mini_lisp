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
      # pp parsed
      code_table = make_code_table(parsed)
      exec(code_table)
    end

    def make_code_table(s_exp)
      code_table = {}
      compile = -> (exp) do
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
            code_table[n] = args.flat_map{|a| "arg@#{a}" } + compile.(code)
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

    StackFrame = Struct.new(:vm_stack, :env, :sp, :code_num) do
      def finish?(code_table)
        sp == code_table[code_num].size
      end
    end

    Closure = Struct.new(:function_num, :call_stack) do
      def inspect
        "Closure#{function_num}"
      end
    end

    def exec(code_table)
      # puts '=============================================================================='
      call_stack = [
        StackFrame[
          [],
          {
            :'+' => ->(args){ args.inject(:+) },
            :'p' => ->(args){ p args.first }
          },
          0, # sp = 0
          0 # root
        ]
      ]

      loop do
        stack_frame = call_stack[-1]
        code = code_table[stack_frame.code_num]
        line = code[stack_frame.sp]

        # puts "#{call_stack.size} ::: #{code}[#{stack_frame.sp}] = #{line.inspect}"
        # p stack_frame.env
        # p stack_frame.vm_stack
        # puts '------------'
        # sleep 0.1

        if call_stack[-1].finish?(code_table)
          finished_stack_frame = call_stack.pop
          if call_stack.empty?
            # puts 'finish!'
            # p finished_stack_frame.vm_stack
            # p finished_stack_frame.vm_stack.last
            break
          else
            call_stack[-1].vm_stack << finished_stack_frame.vm_stack.last
            redo
          end
        end

        case line
        when /^(\d+)/
          stack_frame.vm_stack << $1.to_i
        when /^=@(\w+)/
          name = $1.to_sym
          value = stack_frame.vm_stack.last
          stack_frame.env[name] = value
        when /^get@(\w+)/
          var_name = $1.to_sym
          value = call_stack.map(&:env).reverse.find { |env| env[var_name] }[var_name]
          stack_frame.vm_stack << value
        when /^closure@(.+?)/
          function_num = $1.to_i
          stack_frame.vm_stack << Closure[function_num, call_stack]
        when /^send@(.+?)@(\d+)/
          method_name = $1.to_sym
          argc = $2.to_i
          method = call_stack.map(&:env).reverse.find { |env| env[method_name] }[method_name]
          args = argc.times.map { stack_frame.vm_stack.pop }
          case method
          when Proc
            stack_frame.vm_stack << method.(args)
          when Closure
            call_stack << StackFrame[
              args.reverse,
              {},
              0,
              method.function_num
            ]
          end
        when /^arg@(\w+)/
          name = $1.to_sym
          value = stack_frame.vm_stack.pop
          stack_frame.env[name] = value
        else
          raise "line: #{line.inspect}"
        end
        stack_frame.sp += 1
      end
    end
  end
end

Lisp.run(<<~LISP)
(~
  (= a 100)
  (= f (-> (x)
    (+ x x)
  ))
  (p 12345)
  (f 10)
  (p (f 12))
)
LISP

