$debug = ARGV.include?('-d')

class Proc
  alias __inspect__ inspect
  def inspect
    'Proc' + __inspect__[/:\d+ /][/\d+/]
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
      puts src if $debug
      parsed = parse(src)
      pp parsed if $debug
      code_table = make_code_table(parsed)
      pp code_table if $debug
      exec(code_table)
    end

    def make_code_table(s_exp)
      code_table = [ nil ] # rootのために一時的にnilを置いておく
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
            [*compile.(exp[2]), "set@#{exp[1]}"]
          in :'->'
            args = exp[1]
            raise unless args.all? { |a| Symbol === a }
            code = exp[2]
            code_table << compile.(code)
            [ "closure@#{code_table.size - 1}@#{args.join(',')}" ] # 環境とコードをもったオブジェクトを作成する命令
          in Symbol | Array
            method = exp.first
            args = exp[1..]
            [*args.map { |a| compile.(a) }, compile.(method), "send@#{args.size}"]
          end
        end.flatten(1)
      end
      root = compile.(s_exp)
      code_table[0] = root
      code_table.map.with_index { |a,i| [i, a] }.to_h
    end

    StackFrame = Struct.new(
      :vm_stack, # 可変
      :env, # 可変
      :env_parent, # 不変
      :code_table_num, # 不変
      :line_num # 可変
    ) do
      def finish?(code_table)
        line_num == code_table[code_table_num].size
      end

      def find_env(name)
        env[name] || env_parent&.find_env(name)
      end

      def list_env
        [ *env_parent&.list_env, { **env } ]
      end

      def update_env(name, value)
        current_stack_frame = self
        loop do
          if current_stack_frame.env[name]
            current_stack_frame.env[name] = value
            break
          else
            current_stack_frame = current_stack_frame.env_parent
            if current_stack_frame.nil?
              env[name] = value # 親を辿っても無かったら自身に登録
              break
            end
          end
        end
      end
    end

    Closure = Struct.new(:function_num, :args, :stack_frame) do
      def inspect
        "Closure#{function_num}(#{args.join(',')})"
      end
    end

    def exec(code_table)
      call_stack = [
        StackFrame[
          [], # vm_stack
          {
            :'+' => ->(args){ args.inject(:+) },
            :'-' => ->(args){ args[0] - args[1..].inject(:+) },
            :'p' => ->(args){ p args.first }
          }, # env
          nil, # env_parent
          0, # root
          0 # line_num = 0
        ]
      ]

      loop do
        stack_frame = call_stack[-1]
        code = code_table[stack_frame.code_table_num]
        line = code[stack_frame.line_num]

        if call_stack[-1].finish?(code_table)
          finished_stack_frame = call_stack.pop
          if call_stack.empty?
            p finished_stack_frame.vm_stack if $debug
            break
          else
            call_stack[-1].vm_stack << finished_stack_frame.vm_stack.last
            redo
          end
        end

        if $debug
          p stack_frame.vm_stack
          p stack_frame.list_env
          puts "code_table[#{stack_frame.code_table_num}][#{stack_frame.line_num}] = #{code}[#{stack_frame.line_num}] = #{line.inspect}"
          puts '------------'
        end

        case line
        when /^(\d+)/
          stack_frame.vm_stack << $1.to_i
        when /^set@(\w+)/
          name = $1.to_sym
          value = stack_frame.vm_stack.last
          stack_frame.update_env(name, value)
        when /^get@(.+)/
          var_name = $1.to_sym
          value = stack_frame.find_env(var_name)
          stack_frame.vm_stack << value
        when /^closure@(\d+)@([\w,]*)/
          function_num = $1.to_i
          args = $2.split(',').map(&:to_sym)
          stack_frame.vm_stack << Closure[
            function_num,
            args,
            stack_frame
          ]
        when /^send@(\d+)/
          argc = $1.to_i
          method = stack_frame.vm_stack.pop
          args = argc.times.map { stack_frame.vm_stack.pop }
          case method
          in Proc => pro
            stack_frame.vm_stack << pro.(args)
          in Closure => closure
            call_stack << StackFrame[
              [], # vm_stack
              closure.args.zip(args).to_h, # env
              closure.stack_frame, # env_parent
              closure.function_num, # code_table_num
              0 # line_num
            ]
          end
        else
          raise "no match line: #{line.inspect}"
        end
        stack_frame.line_num += 1
      end
    end
  end
end

Lisp.run(<<~LISP)
(~
  (= a 10)
  (= f (-> (a b) (~
    (= x (+ a b))
    (-> () (= x (+ x 1)))
  )))
  (= inc (f 10 20))
  (p (inc))
  (p (inc))
  (p (inc))
  (p a)
)
LISP

