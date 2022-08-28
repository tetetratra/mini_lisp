require 'set'
require 'rainbow/refinement'

module MiniLisp
  class Evaluator
    using Rainbow

    class << self
      def exec(code_table)
        init_vm = VM.new(0,
                         {
                           0 => StackFrame.new([],
                                               Functions,
                                               0,
                                               nil,
                                               nil,
                                               code_table.size - 1).freeze
                         }).freeze

        print_code_table(init_vm, code_table) if $debug

        loop.reduce(init_vm) do |vm, _|
          if vm.current_stack_frame_finish?(code_table)
            print_stack_frame(vm, code_table) if $debug
            if vm.current_stack_frame.call_parent_num.nil?
              break vm.current_stack_frame.stack.last
            else
              next_vm = vm.change_stack_frame_num(vm.current_stack_frame.call_parent_num)
                          .current_stack_frame_stack_push(vm.current_stack_frame.stack.last)
              print_code_table(next_vm, code_table) if $debug
              next next_vm
            end
          end

          print_stack_frame(vm, code_table) if $debug

          line = code_table[vm.current_stack_frame.code_table_num][vm.current_stack_frame.line_num]
          case line
          when 'nil'
            vm.current_stack_frame_stack_push(Value::Nil)
              .current_stack_frame_line_num_add(1)
          when 'true'
            vm.current_stack_frame_stack_push(Value::True)
              .current_stack_frame_line_num_add(1)
          when 'false'
            vm.current_stack_frame_stack_push(Value::False)
              .current_stack_frame_line_num_add(1)
          when /^int (-?\d+)/
            vm.current_stack_frame_stack_push(Value::Num[Regexp.last_match(1).to_i])
              .current_stack_frame_line_num_add(1)
          when /^str (.*)/
            vm.current_stack_frame_stack_push(Value::String[Regexp.last_match(1)])
              .current_stack_frame_line_num_add(1)
          when /^set (.+)/
            name = Regexp.last_match(1).to_sym
            raise 'bug!' if vm.current_stack_frame.stack.empty?

            value = vm.current_stack_frame.stack.last
            vm.current_stack_frame_update_env(name, value)
              .current_stack_frame_line_num_add(1)
          when /^get (.+)/
            var_name = Regexp.last_match(1).to_sym
            value = vm.current_stack_frame_find_env(var_name)

            vm.current_stack_frame_stack_push(value)
              .current_stack_frame_line_num_add(1)
          when /^symbol (.+)/
            vm.current_stack_frame_stack_push(Value::Symbol[Regexp.last_match(1)])
              .current_stack_frame_line_num_add(1)
          when /^closure (\d+) ([\w,]*)/
            function_num = Regexp.last_match(1).to_i
            args = Regexp.last_match(2).split(',').map(&:to_sym)
            closure = Value::Closure[
              function_num,
              args,
              vm.stack_frame_num
            ]
            vm.current_stack_frame_stack_push(closure)
              .current_stack_frame_line_num_add(1)
          when /^send (\d+)/
            exec_send(vm, code_table, Regexp.last_match(1).to_i)
          when /^jumpif (-?\d+)/
            cond = vm.current_stack_frame.stack.last
            if cond == Value::False || cond == Value::Nil
              vm.current_stack_frame_line_num_add(1)
            else
              vm.current_stack_frame_line_num_add(Regexp.last_match(1).to_i + 1)
            end
          when /^jump (-?\d+)/
            vm.current_stack_frame_line_num_add(Regexp.last_match(1).to_i + 1)
          else
            raise "command `#{line.inspect}` is not found"
          end.then { $gc_every_time ? _1.gc : _1 }
        end
      end

      private

      def exec_send(vm, code_table, argc)
        method_poped_vm, method = vm.current_stack_frame_stack_pop
        args_poped_vm, args = argc.times
                                  .reduce([method_poped_vm, []]) do |(memo_vm, args), _|
          next_vm, poped = memo_vm.current_stack_frame_stack_pop
          [next_vm, [poped, *args]]
        end
        case method
        in :callcc
          continuation = Value::Continuation[
            args_poped_vm
                         .current_stack_frame_line_num_add(1)
          ]

          closure = args.first

          new_stack_frame = StackFrame.new([],
                                           { closure.args.first => continuation },
                                           0,
                                           args_poped_vm.stack_frame_num,
                                           closure.stack_frame_num,
                                           closure.function_num).freeze
          new_stack_frame_num = args_poped_vm.available_stack_frame_num

          next_vm = args_poped_vm
                    .current_stack_frame_line_num_add(1)
                    .insert_stack_frame(new_stack_frame_num, new_stack_frame)
                    .change_stack_frame_num(new_stack_frame_num)
          print_code_table(next_vm, code_table) if $debug
          next_vm
        in :gc
          args_poped_vm
            .gc
            .current_stack_frame_line_num_add(1)
        in Value::Continuation => continuation
          # continuation.vmの環境を現在の環境に差し替えている
          next_vm = VM.new(continuation.vm.stack_frame_num,
                           {
                             # continuation.vm には含まれていないスタックフレームも引き継ぐ
                             **args_poped_vm.stack_frames,
                             **continuation.vm.stack_frames.to_h do |continuation_stack_frame_num, continuation_stack_frame|
                               [
                                 continuation_stack_frame_num,
                                 StackFrame.new([*continuation_stack_frame.stack, args.first],
                                                args_poped_vm.stack_frames[continuation_stack_frame_num].env,
                                                continuation_stack_frame.line_num,
                                                continuation_stack_frame.call_parent_num,
                                                continuation_stack_frame.env_parent_num,
                                                continuation_stack_frame.code_table_num,).freeze
                               ]
                             end
                           }).freeze
          print_code_table(next_vm, code_table) if $debug
          print_stack_frame(next_vm, code_table) if $debug
          next_vm
        in Value::Function => function
          args_poped_vm
            .current_stack_frame_stack_push(function.call(args, vm))
            .current_stack_frame_line_num_add(1)
        in Value::Closure => closure
          new_stack_frame = StackFrame.new([],
                                           closure.args.zip(args).to_h,
                                           0,
                                           args_poped_vm.stack_frame_num,
                                           closure.stack_frame_num,
                                           closure.function_num).freeze
          new_stack_frame_num = args_poped_vm.available_stack_frame_num
          next_vm = args_poped_vm
                    .current_stack_frame_line_num_add(1)
                    .insert_stack_frame(new_stack_frame_num, new_stack_frame)
                    .change_stack_frame_num(new_stack_frame_num)
          print_code_table(next_vm, code_table) if $debug
          next_vm
        end
      end

      def print_code_table(vm, code_table)
        puts(vm.current_stack_frame.code_table_num => code_table[vm.current_stack_frame.code_table_num]).inspect.red
        puts '------------'
      end

      def print_stack_frame(vm, code_table)
        p vm.current_stack_frame.stack
        puts "#{vm.stack_frame_num.inspect}, c: #{vm.current_stack_frame.call_parent_num.inspect}, e: #{vm.current_stack_frame.env_parent_num.inspect}, sfs: #{vm.stack_frames.keys.to_set.inspect[/{.*}/]}"
        print '...' if vm.current_stack_frame.env.size > 3
        puts vm.current_stack_frame.env.to_a.reverse.to_a.take(3).reverse.to_h.inspect
        line = code_table[vm.current_stack_frame.code_table_num][vm.current_stack_frame.line_num]
        puts "[#{vm.current_stack_frame.code_table_num}][#{vm.current_stack_frame.line_num}] = " + line.inspect.yellow
        puts '------------'
      end
    end
  end
end
