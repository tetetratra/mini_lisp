class Lisp
  class Evaluator
    def self.exec(code_table)
      init_vm = VM[
        0,
        {
          0 => StackFrame[
            [], # stack
            {
              :callcc => :callcc,
              :'+' => ->(args) { args.inject(:+) },
              :'-' => ->(args) { args[0] - args[1..].inject(:+) },
              :'==' => ->(args) { args[0] == args[1] },
              :'!=' => ->(args) { args[0] != args[1] },
              :'!' => ->(args) { !args[0] },
              :p => ->(args) { p args.first },
              :sleep => ->(args) { sleep(args.first); args.first }
            }, # env
            0, # line_num
            nil, # call_parent_num
            nil, # env_parent_num
            0 # code_table_num
          ].freeze
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
            next vm.change_stack_frame_num(vm.current_stack_frame.call_parent_num)
                   .current_stack_frame_stack_push(vm.current_stack_frame.stack.last)
          end
        end

        if $debug
          p vm.current_stack_frame.stack
          p vm.current_stack_frame.list_env(vm.stack_frames)
          puts "code_table[#{vm.current_stack_frame.code_table_num}][#{vm.current_stack_frame.line_num}]\n= #{code}[#{vm.current_stack_frame.line_num}]\n= #{line.inspect}"
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
          method_poped_vm, method = vm.current_stack_frame_stack_pop
          new_vm, args = argc.times.reduce([method_poped_vm, []]) { |(memo_vm, args), _|
            next_vm, poped = memo_vm.current_stack_frame_stack_pop
            [next_vm, [poped, *args]]
          }
          case method
          in :callcc
            continuation = Continuation[
              vm.current_stack_frame_line_num_add(1)
            ]
            closure = args.first
            new_stack_frame = StackFrame[
              [], # stack
              { closure.args.first => continuation }, # env
              0, # line_num
              new_vm.stack_frame_num, # call_parent_num
              closure.stack_frame_num, # env_parent_num
              closure.function_num # code_table_num
            ].freeze
            new_stack_frame_num = new_vm.stack_frames.size
            next new_vm
                   .current_stack_frame_line_num_add(1)
                   .insert_stack_frame(new_stack_frame_num, new_stack_frame)
                   .change_stack_frame_num(new_stack_frame_num)
          in Continuation => continuation
            next VM[ # continuation.vmの環境を現在の環境に差し替えている
              continuation.vm.stack_frame_num,
              continuation.vm.stack_frames.to_h { |continuation_stack_frame_num, continuation_stack_frame|
                [
                  continuation_stack_frame_num,
                  StackFrame[
                    continuation_stack_frame.stack, # stack
                    vm.current_stack_frame.env, # env
                    continuation_stack_frame.line_num, # line_num
                    continuation_stack_frame.call_parent_num, # call_parent_num
                    continuation_stack_frame.env_parent_num, # env_parent_num
                    continuation_stack_frame.code_table_num, # code_table_num
                  ].freeze
                ]
              }
            ].freeze
          in Proc => pro
            new_vm.current_stack_frame_stack_push(pro.(args))
          in Closure => closure
            new_stack_frame = StackFrame[
              [], # stack
              closure.args.zip(args).to_h, # env
              0, # line_num
              new_vm.stack_frame_num, # call_parent_num
              closure.stack_frame_num, # env_parent_num
              closure.function_num # code_table_num
            ].freeze
            new_stack_frame_num = new_vm.stack_frames.size
            next new_vm
                   .current_stack_frame_line_num_add(1)
                   .insert_stack_frame(new_stack_frame_num, new_stack_frame)
                   .change_stack_frame_num(new_stack_frame_num)
          end
        when /^jumpif@(\d+)/
          cond = vm.current_stack_frame.stack.last
          line_relative = $1.to_i
          if cond
            vm.current_stack_frame_line_num_add(line_relative)
          else
            vm
          end
        when /^jump@(-?\d+)/
          line_relative = $1.to_i
          vm.current_stack_frame_line_num_add(line_relative)
        else
          raise "command `#{line.inspect}` is not found"
        end => next_vm
        next_vm.current_stack_frame_line_num_add(1)
      end
    end
  end
end
