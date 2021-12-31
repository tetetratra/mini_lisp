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
      unless ([:'(', :')'] & parsed.flatten).empty?
        puts "Parse error:\n`#{str.chomp}` is not valid code"
        exit
      end
      parsed
    end

    def run(src)
      puts src if $debug
      parsed = parse(src)
      pp parsed if $debug
      code_table = make_code_table([:~, *parsed])
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
          in :if
            if_exp = exp[1]
            then_exp = exp[2]
            else_exp = exp[3]
            if_compiled = compile.(if_exp)
            then_compiled = compile.(then_exp)
            else_compiled = compile.(else_exp)
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
            compiled_cond = compile.(cond)
            compiled_statements = statements.flat_map { |s| compile.(s) }
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
            [*compile.(exp[2]), "set@#{exp[1]}"]
          in :'->'
            args = exp[1]
            raise "argument `#{args.find { Symbol != _1 }}` in `#{exp}` must be symbol" unless args.all? { |a| Symbol === a }
            codes = exp[2..]
            code_table << codes.flat_map { |code| compile.(code) }
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
      :stack, # 可変
      :env, # 可変
      :line_num, # 可変
      :call_parent_num, # 不変
      :env_parent_num, # 不変
      :code_table_num # 不変
    ) do

      def stack_parent(call_stack)
        call_stack[call_parent_num]
      end

      def env_parent(call_stack)
        call_stack[env_parent_num]
      end

      def finish?(code_table)
        line_num == code_table[code_table_num].size
      end

      def find_env(name, call_stack)
        env[name] || env_parent(call_stack)&.find_env(name, call_stack)
      end

      def list_env(call_stack)
        [ *env_parent(call_stack)&.list_env(call_stack), { **env } ]
      end

      def update_env(name, value, call_stack)
        current_stack_frame = self
        loop do
          if current_stack_frame.env[name]
            current_stack_frame.env[name] = value
            break
          else
            current_stack_frame = current_stack_frame.env_parent(call_stack)
            if current_stack_frame.nil?
              env[name] = value # 親を辿っても無かったら自身に登録
              break
            end
          end
        end
      end
    end

    Closure = Struct.new(:function_num, :args, :stack_frame_num) do
      def inspect
        "Closure#{function_num}(#{args.join(',')})"
      end
    end

    def exec(code_table)
      call_stack = {
        0 => StackFrame[
          [], # stack
          {
            :true => true,
            :false => false,
            :'+' => ->(args) { args.inject(:+) },
            :'-' => ->(args) { args[0] - args[1..].inject(:+) },
            :'==' => ->(args) { args[0] == args[1] },
            :'!=' => ->(args) { args[0] != args[1] },
            :'!' => ->(args) { !args[0] },
            :'p' => ->(args) { p args.first }
          }, # env
          0, # line_num
          nil, # call_parent_num
          nil, # env_parent_num
          0 # code_table_num
        ]
      }

      stack_frame_num = 0

      loop do
        stack_frame = call_stack[stack_frame_num]
        code = code_table[stack_frame.code_table_num]
        line = code[stack_frame.line_num]

        if stack_frame.finish?(code_table)
          if stack_frame.call_parent_num.nil?
            p stack_frame.stack if $debug
            break
          else
            stack_frame_num = stack_frame.call_parent_num
            call_stack[stack_frame_num].stack << stack_frame.stack.last
            redo
          end
        end

        if $debug
          p stack_frame.stack
          p stack_frame.list_env(call_stack)
          puts "code_table[#{stack_frame.code_table_num}][#{stack_frame.line_num}] = #{code}[#{stack_frame.line_num}] = #{line.inspect}"
          puts '------------'
        end

        case line
        when /^(\d+)/
          stack_frame.stack << $1.to_i
        when /^set@(.+)/
          name = $1.to_sym
          value = stack_frame.stack.last
          stack_frame.update_env(name, value, call_stack)
        when /^get@(.+)/
          var_name = $1.to_sym
          value = stack_frame.find_env(var_name, call_stack)
          raise "variable `#{var_name}` is not defined" if value.nil?
          stack_frame.stack << value
        when /^closure@(\d+)@([\w,]*)/
          function_num = $1.to_i
          args = $2.split(',').map(&:to_sym)
          stack_frame.stack << Closure[
            function_num,
            args,
            stack_frame_num
          ]
        when /^send@(\d+)/
          argc = $1.to_i
          method = stack_frame.stack.pop
          args = argc.times.map { stack_frame.stack.pop }.reverse
          case method
          in Proc => pro
            stack_frame.stack << pro.(args)
          in Closure => closure
            new_stack_frame = StackFrame[
              [], # stack
              closure.args.zip(args).to_h, # env
              0, # line_num
              stack_frame_num, # call_parent_num
              closure.stack_frame_num, # env_parent_num
              closure.function_num # code_table_num
            ]
            new_stack_frame_num = call_stack.size
            call_stack[new_stack_frame_num] = new_stack_frame
            stack_frame_num = new_stack_frame_num
          end
        when /^jumpif@(\d+)/
          cond = stack_frame.stack.last
          add = $1.to_i
          if cond
            stack_frame.line_num += add
          end
        when /^jump@(-?\d+)/
          add = $1.to_i
          stack_frame.line_num += add
        else
          raise "command `#{line.inspect}` is not found"
        end
        stack_frame.line_num += 1
      end
    end
  end
end

Lisp.run(<<~LISP)
(= a 123)
(p a)
(= f (-> () (= a (+ a 1))))
(f)
(f)
(f)
(p a)
LISP

=begin
require 'continuation'

def b(re)
  if rand(2).zero?
    re.()
  else
    p :b
  end
end

def a(re)
  if rand(2).zero?
    re.()
  else
    p :a
    b(re)
  end
end

callcc { |raise_exception|
  if rand(2).zero?
    raise_exception.()
  else
    p :root
    a(raise_exception)
  end
}
p :fin
=end
