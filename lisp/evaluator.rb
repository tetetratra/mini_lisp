module Lisp
  class Evaluator
    class << self
      def exec(code_table)
        init_vm = VM[
          0,
          {
            0 => StackFrame[
              [], # stack
              {
                :callcc => :callcc,
                :gc => :gc,
                :'+' => Fn { args.inject(:+) },
                :'-' => Fn { args[0] - args[1..].inject(:+) },
                :'==' => Fn { args[0] == args[1] },
                :'!=' => Fn { args[0] != args[1] },
                :'!' => Fn { !args[0] },
                :p => Fn { p args.first },
                :pp => Fn { pp args.first },
                :puts => Fn { puts args.first; args.first },
                :print => Fn { print args.first; args.first },
                :sleep => Fn { sleep(args.first); args.first },
                :stack_frames_size => Fn { vm.stack_frames.size },
                :vm => Fn { vm }
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
          when /^send@(\d+)/
            exec_send(vm, code_table, $1.to_i)
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

      def exec_send(vm, code_table, argc)
        method_poped_vm, method = vm.current_stack_frame_stack_pop
        args_poped_vm, args = argc.times.reduce([method_poped_vm, []]) { |(memo_vm, args), _|
          next_vm, poped = memo_vm.current_stack_frame_stack_pop
          [next_vm, [poped, *args]]
        }
        case method
        in :callcc
          continuation = Continuation[args_poped_vm.current_stack_frame_line_num_add(1).then { exec_gc(_1) }]
          closure = args.first
          new_stack_frame = StackFrame[
            [], # stack
            { closure.args.first => continuation }, # env
            0, # line_num
            args_poped_vm.stack_frame_num, # call_parent_num
            closure.stack_frame_num, # env_parent_num
            closure.function_num # code_table_num
          ].freeze
          new_stack_frame_num = args_poped_vm.available_stack_frame_num
          args_poped_vm.current_stack_frame_line_num_add(1)
            .insert_stack_frame(new_stack_frame_num, new_stack_frame)
            .change_stack_frame_num(new_stack_frame_num)
        in :gc
          exec_gc(args_poped_vm)
            .current_stack_frame_line_num_add(1)
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
        in Function => function
          args_poped_vm.current_stack_frame_stack_push(function.(args, vm))
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
          new_stack_frame_num = args_poped_vm.available_stack_frame_num
          args_poped_vm.current_stack_frame_line_num_add(1)
            .insert_stack_frame(new_stack_frame_num, new_stack_frame)
            .change_stack_frame_num(new_stack_frame_num)
        end
      end

      def exec_gc(vm)
        keep = vm.stack_frames.to_h { |num, _sf| [num, false] }

        keep[vm.stack_frame_num] = true
        stack = [ vm.stack_frame_num ]

        until stack.empty?
          poped_stack_frame_num = stack.pop
          stack_frame = vm.stack_frames[poped_stack_frame_num]

          if (cpn = stack_frame.call_parent_num) && !keep[cpn]
            stack << cpn
            keep[cpn] = true
          end

          if (epn = stack_frame.env_parent_num) && !keep[epn]
            stack << epn
            keep[epn] = true
          end

          stack_frame.env
            .select { |_n, v| v in Closure }
            .each do |_name, value|
            case value
            in Closure => closure_value
              unless keep[sfn = closure_value.stack_frame_num]
                stack << sfn
                keep[sfn] = true
              end
            end
          end
        end

        VM[
          vm.stack_frame_num,
          vm.stack_frames.select { |num, _sf| keep[num] }
        ]
      end

      def Fn(&block)
        Function.new(block)
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
