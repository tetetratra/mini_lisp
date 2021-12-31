class Lisp
  class Evaluator
    def self.exec(code_table)
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
