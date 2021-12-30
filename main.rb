$debug = false

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
            [*compile.(exp[2]), "=@#{exp[1]}"]
          in :'->'
            args = exp[1]
            raise unless args.all? { |a| Symbol === a }
            code = exp[2]
            code_table << args.flat_map{|a| "arg@#{a}" } + compile.(code)
            [ "closure@#{code_table.size - 1}" ] # 環境とコードをもったオブジェクトを作成する命令
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

    StackFrame = Struct.new(:vm_stack, :env, :parent_env_sf, :sp, :code_num) do
      def finish?(code_table)
        sp == code_table[code_num].size
      end

      def find_env(name)
        env[name] || parent_env_sf&.find_env(name)
      end

      def list_env
        [ *parent_env_sf&.list_env, { **env } ]
      end

      def update_env(name, value)
        unless update_env_rec(name, value)
          env[name] = value
        end
        self
      end

      private

      def update_env_rec(name, value)
        if env[name]
          env[name] = value
          true
        else
          if parent_env_sf
            parent_env_sf.update_env(name, value)
          else
            false
          end
        end
      end
    end

    Closure = Struct.new(:function_num, :stack_frame) do
      def inspect
        "Closure#{function_num}"
      end
    end

    def exec(code_table)
      call_stack = [
        StackFrame[
          [], # vm_stack
          {
            :'+' => ->(args){ args.inject(:+) },
            :'p' => ->(args){ p args.first }
          }, # env
          nil, # parent_env_sf
          0, # sp = 0
          0 # root
        ]
      ]

      loop do
        stack_frame = call_stack[-1]
        code = code_table[stack_frame.code_num]
        line = code[stack_frame.sp]

        if call_stack[-1].finish?(code_table)
          finished_stack_frame = call_stack.pop
          if call_stack.empty?
            if $debug
              puts 'finish!'
              p finished_stack_frame.vm_stack
            end
            break
          else
            call_stack[-1].vm_stack << finished_stack_frame.vm_stack.last
            redo
          end
        end

        if $debug
          p stack_frame.vm_stack
          p stack_frame.list_env
          puts "code_table[#{stack_frame.code_num}][#{stack_frame.sp}] = #{code}[#{stack_frame.sp}] = #{line.inspect}"
          puts '------------'
          sleep 0.1
        end

        case line
        when /^(\d+)/
          stack_frame.vm_stack << $1.to_i
        when /^=@(\w+)/
          name = $1.to_sym
          value = stack_frame.vm_stack.last

          stack_frame.update_env(name, value)

        when /^get@(.+)/
          var_name = $1.to_sym
          value = stack_frame.find_env(var_name)
          stack_frame.vm_stack << value
        when /^closure@(\d+)/
          function_num = $1.to_i
          stack_frame.vm_stack << Closure[
            function_num,
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
              args.reverse, # vm_stack
              {}, # env
              closure.stack_frame, # parent_env_sf
              0,
              closure.function_num
            ]
          end
        when /^arg@(\w+)/
          name = $1.to_sym
          value = stack_frame.vm_stack.pop
          stack_frame.env[name] = value
        else
          raise "no match line: #{line.inspect}"
        end
        stack_frame.sp += 1
      end
    end
  end
end

Lisp.run(<<~LISP)
(~
  (= a 10)
  (= f (-> ()
    (= a (+ a 1))
  ))
  (f)
  (f)
  (f)
  (f)
  (p a)
)
LISP

