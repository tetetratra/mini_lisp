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

    VM = Struct.new(:stack_frame_num, :stack_frames) do
      def change_stack_frame_num(n)
        VM[
          n,
          stack_frames
        ].freeze
      end

      def current_stack_frame
        stack_frames[stack_frame_num]
      end

      def current_stack_frame_call_parent
        stack_frames[current_stack_frame.call_parent_num]
      end

      def current_stack_frame_env_parent
        stack_frames[current_stack_frame.env_parent_num]
      end

      def current_stack_frame_finish?(code_table)
        current_stack_frame.line_num == code_table[current_stack_frame.code_table_num].size
      end

      def current_stack_frame_find_env(name)
        current_stack_frame.find_env(name, stack_frames)
      end

      def current_stack_frame_list_env
        current_stack_frame.list_env(stack_frames)
      end

      def current_stack_frame_update_env(name, value)
        stack_frame_target_num = stack_frame_num
        if current_stack_frame.env[name].nil?
          loop do
            stack_frame_target_num = stack_frames[stack_frame_target_num].env_parent_num
            if stack_frame_target_num.nil?
              stack_frame_target_num = stack_frame_num
              break
            end
            break if stack_frames[stack_frame_target_num].env[name]
          end
        end

        VM[
          stack_frame_num,
          {
            **stack_frames.except(stack_frame_target_num),
            stack_frame_target_num => StackFrame[
              stack_frames[stack_frame_target_num].stack,
              { **stack_frames[stack_frame_target_num].env, name => value },
              stack_frames[stack_frame_target_num].line_num,
              stack_frames[stack_frame_target_num].call_parent_num,
              stack_frames[stack_frame_target_num].env_parent_num,
              stack_frames[stack_frame_target_num].code_table_num
            ]
          }
        ].freeze
      end

      def current_stack_frame_stack_push(value)
        VM[
          stack_frame_num,
          {
            **stack_frames.except(stack_frame_num),
            stack_frame_num => StackFrame[
              [*current_stack_frame.stack, value],
              current_stack_frame.env,
              current_stack_frame.line_num,
              current_stack_frame.call_parent_num,
              current_stack_frame.env_parent_num,
              current_stack_frame.code_table_num
            ]
          }
        ].freeze
      end

      def current_stack_frame_stack_pop
        vm = VM[
          stack_frame_num,
          {
            **stack_frames.except(stack_frame_num),
            stack_frame_num => StackFrame[
              current_stack_frame.stack[..-2],
              current_stack_frame.env,
              current_stack_frame.line_num,
              current_stack_frame.call_parent_num,
              current_stack_frame.env_parent_num,
              current_stack_frame.code_table_num
            ]
          }
        ].freeze
        [vm, current_stack_frame.stack.last]
      end

      def current_stack_frame_line_num_add(n)
        VM[
          stack_frame_num,
          {
            **stack_frames.except(stack_frame_num),
            stack_frame_num => StackFrame[
              current_stack_frame.stack,
              current_stack_frame.env,
              current_stack_frame.line_num + n,
              current_stack_frame.call_parent_num,
              current_stack_frame.env_parent_num,
              current_stack_frame.code_table_num
            ]
          }
        ].freeze
      end

      def insert_stack_frame(n, stack_frame)
        VM[
          stack_frame_num,
          {
            **stack_frames,
            n => stack_frame
          }
        ].freeze
      end
    end

    StackFrame = Struct.new(
      :stack, # 可変
      :env, # 可変
      :line_num, # 可変
      :call_parent_num, # 不変
      :env_parent_num, # 不変
      :code_table_num # 不変
    ) do
      def env_parent(call_stack)
        call_stack[env_parent_num]
      end

      def find_env(name, call_stack)
        env[name] || env_parent(call_stack)&.find_env(name, call_stack)
      end

      def list_env(call_stack)
        [ *env_parent(call_stack)&.list_env(call_stack), { **env } ]
      end
    end

    Closure = Struct.new(:function_num, :args, :stack_frame_num) do
      def inspect
        "Closure#{function_num}(#{args.join(',')})"
      end
    end

    def exec(code_table)
      init_vm = VM[
        0,
        {
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
      ].freeze

      (0..).reduce(init_vm) do |vm, _|
        code = code_table[vm.current_stack_frame.code_table_num]
        line = code[vm.current_stack_frame.line_num]

        if vm.current_stack_frame_finish?(code_table)
          if vm.current_stack_frame.call_parent_num.nil?
            p vm.current_stack_frame.stack if $debug
            break
          else
            new_vm = vm.change_stack_frame_num(vm.current_stack_frame.call_parent_num)
                       .current_stack_frame_stack_push(vm.current_stack_frame.stack.last)
            next new_vm
          end
        end

        if $debug
          p vm.current_stack_frame.stack
          p vm.current_stack_frame.list_env(vm.stack_frames)
          puts "code_table[#{vm.current_stack_frame.code_table_num}][#{vm.current_stack_frame.line_num}] = #{code}[#{vm.current_stack_frame.line_num}] = #{line.inspect}"
          puts '------------'
        end

        case line
        when /^(\d+)/
          vm.current_stack_frame_stack_push($1.to_i)
        when /^set@(.+)/
          name = $1.to_sym
          value = vm.current_stack_frame.stack.last
          vm.current_stack_frame_update_env(name, value)
        when /^get@(.+)/
          var_name = $1.to_sym
          value = vm.current_stack_frame_find_env(var_name)
          raise "variable `#{var_name}` is not defined" if value.nil?
          vm.current_stack_frame_stack_push(value)
        when /^closure@(\d+)@([\w,]*)/
          function_num = $1.to_i
          args = $2.split(',').map(&:to_sym)
          closure = Closure[
            function_num,
            args,
            vm.stack_frame_num
          ]
          vm.current_stack_frame_stack_push(closure)
        when /^send@(\d+)/
          argc = $1.to_i
          new_vm, method = vm.current_stack_frame_stack_pop
          new_vm2, args = argc.times.reduce([new_vm, []]) { |(memo_vm, args), _|
            vm.current_stack_frame.stack.pop
            next_vm, poped = memo_vm.current_stack_frame_stack_pop
            [next_vm, [poped, *args]]
          }
          case method
          in Proc => pro
            new_vm2.current_stack_frame_stack_push(pro.(args))
          in Closure => closure
            new_stack_frame = StackFrame[
              [], # stack
              closure.args.zip(args).to_h, # env
              0, # line_num
              new_vm2.stack_frame_num, # call_parent_num
              closure.stack_frame_num, # env_parent_num
              closure.function_num # code_table_num
            ]
            new_stack_frame_num = new_vm2.stack_frames.size
            next new_vm2
                   .current_stack_frame_line_num_add(1)
                   .insert_stack_frame(new_stack_frame_num, new_stack_frame)
                   .change_stack_frame_num(new_stack_frame_num)
          end
        when /^jumpif@(\d+)/
          cond = new_vm2.current_stack_frame.stack.last
          line_relative = $1.to_i
          if cond
            new_vm2.current_stack_frame_line_num_add(line_relative)
          else
            new_vm2
          end
        when /^jump@(-?\d+)/
          line_relative = $1.to_i
          new_vm2.current_stack_frame_line_num_add(line_relative)
        else
          raise "command `#{line.inspect}` is not found"
        end => new_vm3
        new_vm3.current_stack_frame_line_num_add(1)
      end
    end
  end
end

Lisp.run(<<~LISP)
(= f (-> (x)
  (= init x)
  (-> () (= init (+ init 1)))
))
(= inc (f 10))
(p (inc))
(inc)
(inc)
(p (inc))
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
