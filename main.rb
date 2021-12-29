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
      bytecode = compile(parsed)
      pp bytecode
      exec(bytecode)
    end

    def compile(exp)
      case exp
      in Integer => i
        [ "#{i}" ]
      in Symbol => s
        [ "get@#{s}" ]
      in Array
        case exp.first
        in :~
          exp[1..].map { |e| compile(e) }
        # in :+
        #   [*exp[1..].map { |e| compile(e) }, "+@#{exp.size - 1}"]
        in :'='
          raise unless Symbol === exp[1]
          [*compile(exp[2]), "=@#{exp[1]}"]
        in :'->'
          args = exp[1]
          raise unless args.all? { |a| Symbol === a }
          codes = exp[2..]
          [ "closure@#{args.inspect}@#{codes.inspect}" ] # 環境とコードをもったオブジェクトを作成する命令
        in Symbol => method
          args = exp[1..]
          [*args.map { |a| compile(a) }, "send@#{method}@#{args.size}"]
        end
      end.flatten(1)
    end

    # StackFrame = Struct.new(:variables) do
    #   def add(**hash)
    #     StackFrame[{ **variables, **hash }]
    #   end
    # end

    def exec(bytecode)
      call_stack = [
        {
          :'+' => ->(args){ args.inject(:+) },
        }
      ]
      vm_stack = []
      sp = 0
      while code = bytecode[sp]
        case code
        when /^\d/
          vm_stack << code.to_i
        when /^=@(\w+)/
          name = $1.to_sym
          value = vm_stack.last
          call_stack = [*call_stack[..-2], { **call_stack[-1], name => value }]
        when /^get@(\w+)/
          name = $1.to_sym
          value = call_stack.reverse.find { |variables| variables[name] }[name]
          vm_stack << value
        when /^closure@(.+?)@(.+?)/
          args = $1
          codes = $2
          vm_stack << Closure

        when /^send@(.+?)@(\d+)/
          method_name = $1.to_sym
          argc = $2.to_i
          method = call_stack.reverse.find { |frame| frame[method_name] }[method_name]
          args = argc.times.map { vm_stack.pop }
          vm_stack << method.(args)
        else
          raise
        end
        sp += 1
        p code
        p call_stack
        p vm_stack
        puts
      end
    end
  end
end

Lisp.run(<<~LISP)
(~
  (= a (+ (+ 15 25) 30))
  (+ a a a)
  (= f (-> (x) (+ a x)))
  (f 10)
)
LISP

