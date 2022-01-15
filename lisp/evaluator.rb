class Lisp
  class Evaluator
    class << self
      def exec(code_table)
        init_vm = VM[
          0,
          {
            0 => StackFrame[
              [], # stack
              {
                :'+' => ->(a, b) { a + b }.curry(2),
                :'-' => ->(a, b) { a - b }.curry(2),
                :'==' => ->(a, b) { a == b }.curry(2),
                :'!=' => ->(a, b) { a != b }.curry(2),
                :'!' => ->(a) { !a },
                :p => ->(a) { p a },
                :puts => ->(a) { puts a; a },
                :sleep => ->(a) { sleep(a); a }
              }, # env
              0, # line_num
              nil, # call_parent_num
              nil, # env_parent_num
              0 # code_table_num
            ].freeze
          }
        ].freeze

        (0..).reduce(init_vm) do |vm, _|
          if vm.current_stack_frame_finish?(code_table)
            print_debug_log(vm, code_table) if $debug
            if vm.current_stack_frame.call_parent_num.nil?
              break
            else
              next vm.change_stack_frame_num(vm.current_stack_frame.call_parent_num)
                     .current_stack_frame_stack_push(vm.current_stack_frame.stack.last)
            end
          end

          print_debug_log(vm, code_table) if $debug

          line = code_table[vm.current_stack_frame.code_table_num][vm.current_stack_frame.line_num]
          case line
          when /^int@(-?\d+)/
            vm.current_stack_frame_stack_push($1.to_i)
              .current_stack_frame_line_num_add(1)
          when /^str@(.*)/
            vm.current_stack_frame_stack_push($1)
              .current_stack_frame_line_num_add(1)
          when /^set@(.+)/
            name = $1.to_sym
            value = vm.current_stack_frame.stack.last
            vm.current_stack_frame_update_env(name, value)
              .current_stack_frame_line_num_add(1)
          when /^get@(.+)/
            var_name = $1.to_sym
            value = vm.current_stack_frame_find_env(var_name)
            raise "variable `#{var_name}` is not defined" if value.nil?

            vm.current_stack_frame_stack_push(value)
              .current_stack_frame_line_num_add(1)
          when /^closure@(\d+)@([\w,]*)/
            function_num = $1.to_i
            args = $2.split(',').map(&:to_sym)
            closure = Closure[
              function_num,
              args,
              vm.stack_frame_num
            ]
            vm.current_stack_frame_stack_push(closure)
              .current_stack_frame_line_num_add(1)
          when /^callcc/
            closure_poped_vm, closure = vm.current_stack_frame_stack_pop
            continuation = Continuation[closure_poped_vm.current_stack_frame_line_num_add(1)]
            new_stack_frame = StackFrame[
              [], # stack
              { closure.args.first => continuation }, # env
              0, # line_num
              closure_poped_vm.stack_frame_num, # call_parent_num
              closure.stack_frame_num, # env_parent_num
              closure.function_num # code_table_num
            ].freeze
            new_stack_frame_num = closure_poped_vm.stack_frames.size
            closure_poped_vm.current_stack_frame_line_num_add(1)
              .insert_stack_frame(new_stack_frame_num, new_stack_frame)
              .change_stack_frame_num(new_stack_frame_num)
          when /^send/
            exec_send(vm, code_table)
          when /^jumpif@(\d+)/
            cond = vm.current_stack_frame.stack.last
            line_relative = $1.to_i
            vm.then { cond ? _1.current_stack_frame_line_num_add(line_relative) : _1 }
              .current_stack_frame_line_num_add(1)
          when /^jump@(-?\d+)/
            line_relative = $1.to_i
            vm.current_stack_frame_line_num_add(line_relative)
              .current_stack_frame_line_num_add(1)
          else
            raise "command `#{line.inspect}` is not found"
          end
        end
      end

      private

      def exec_send(vm, code_table)
        method_poped_vm, method = vm.current_stack_frame_stack_pop
        arg_poped_vm, arg = method_poped_vm.current_stack_frame_stack_pop
        args = [arg] # TODO あとで変数名直す
        args_poped_vm = arg_poped_vm # TODO あとで変数名直す

        case method
        in Continuation => continuation
          VM[ # continuation.vmの環境を現在の環境に差し替えている
            continuation.vm.stack_frame_num,
            continuation.vm.stack_frames.to_h { |continuation_stack_frame_num, continuation_stack_frame|
              [
                continuation_stack_frame_num,
                StackFrame[
                  [*continuation_stack_frame.stack, args.first], # stack
                  args_poped_vm.stack_frames[continuation_stack_frame_num].env, # env
                  continuation_stack_frame.line_num, # line_num
                  continuation_stack_frame.call_parent_num, # call_parent_num
                  continuation_stack_frame.env_parent_num, # env_parent_num
                  continuation_stack_frame.code_table_num, # code_table_num
                ].freeze
              ]
            }
          ].freeze
        in Proc => pro
          proc_applyed = args.reduce(pro) { |proc_applying, arg| proc_applying.(arg) }

          args_poped_vm.current_stack_frame_stack_push(proc_applyed)
            .current_stack_frame_line_num_add(1)
        in Closure => closure
          new_stack_frame = StackFrame[
            [], # stack
            closure.args.zip(args).to_h, # env
            0, # line_num
            args_poped_vm.stack_frame_num, # call_parent_num
            closure.stack_frame_num, # env_parent_num
            closure.function_num # code_table_num
          ].freeze
          new_stack_frame_num = args_poped_vm.stack_frames.size
          args_poped_vm.current_stack_frame_line_num_add(1)
            .insert_stack_frame(new_stack_frame_num, new_stack_frame)
            .change_stack_frame_num(new_stack_frame_num)
        end
      end

      def print_debug_log(vm, code_table)
        p vm.current_stack_frame.stack
        p vm.current_stack_frame.list_env(vm.stack_frames)
        code = code_table[vm.current_stack_frame.code_table_num]
        line = code[vm.current_stack_frame.line_num]
        puts "code_table[#{vm.current_stack_frame.code_table_num}][#{vm.current_stack_frame.line_num}]\n= #{code}[#{vm.current_stack_frame.line_num}]\n= #{line.inspect}"
        puts '------------'
      end
    end
  end
end
