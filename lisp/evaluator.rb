module Lisp
  class Evaluator
    class << self
      def exec(code_table)
        root_stack_frame = StackFrame[
          [],
          {
            # :callcc => :callcc,
            # :gc => :gc,
            :'+' => Fn { args.inject(:+) },
            :'-' => Fn { args[0] - args[1..].inject(:+) },
            :'==' => Fn { args[0] == args[1] },
            :'!=' => Fn { args[0] != args[1] },
            :'!' => Fn { !args[0] },
            :p => Fn { p args.first },
            # :pp => Fn { pp args.first },
            # :puts => Fn { puts args.first; args.first },
            # :print => Fn { print args.first; args.first },
            # :sleep => Fn { sleep(args.first); args.first }
          },
          0,
          nil,
          nil,
          0
        ]

        loop.reduce(root_stack_frame) do |stack_frame, _|
          if stack_frame.finish?(code_table)
            stack_frame.print_debug_log(code_table) if $debug
            if stack_frame.call_parent.nil?
              break
            else
              next stack_frame.call_parent.push(stack_frame.stack.last)
            end
          end

          stack_frame.print_debug_log(code_table) if $debug

          line = code_table[stack_frame.code_table_num][stack_frame.line_num]
          case line
          when /^int@(-?\d+)/
            stack_frame
              .push($1.to_i)
              .line_num_add(1)
          when /^str@(.*)/
            stack_frame
              .push($1)
              .line_num_add(1)
          when /^set@(.+)/
            name = $1.to_sym
            value = stack_frame.stack.last
            stack_frame
              .update_variable(name, value)
              .line_num_add(1)
          when /^get@(.+)/
            var_name = $1.to_sym
            value = stack_frame.find_variable(var_name)
            raise "variable `#{var_name}` is not defined" if value.nil?

            stack_frame
              .push(value)
              .line_num_add(1)
          when /^closure@(\d+)@([\w,]*)/
            function_num = $1.to_i
            args = $2.split(',').map(&:to_sym)
            closure = Closure[
              function_num,
              args,
              stack_frame
            ]
            stack_frame
              .push(closure)
              .line_num_add(1)
          when /^send@(\d+)/
            exec_send(stack_frame, code_table, $1.to_i)
          when /^jumpif@(-?\d+)/
            if stack_frame.stack.last
              stack_frame
                .line_num_add($1.to_i + 1)
            else
              stack_frame
                .line_num_add(1)
            end
          when /^jump@(-?\d+)/
            stack_frame
              .line_num_add($1.to_i + 1)
          else
            raise "command `#{line.inspect}` is not found"

          end.then { exec_gc(_1) }
        end
      end

      private

      def exec_send(stack_frame, code_table, argc)
        poped_stack_frame, method = stack_frame.pop
        args_poped_stack_frame, args = argc.times.reduce([poped_stack_frame, []]) { |(memo_sf, args), _|
          next_sf, poped = memo_sf.pop
          [next_sf, [poped, *args]]
        }
        case method
        in :callcc
          continuation = Continuation[
            args_poped_stack_frame.line_num_add(1).then { exec_gc(_1) }
          ]
          closure = args.first
          StackFrame[
            [], # stack
            { closure.args.first => continuation }, # env
            0, # line_num
            args_poped_stack_frame.line_num_add(1), # call_parent
            closure.stack_frame, # env_parent
            closure.function_num # code_table_num
          ].freeze
        in :gc
          exec_gc(args_poped_stack_frame).line_num_add(1)
        in Continuation => continuation
          # todo
          # args_poped_stack_frame.env,
          # StackFrame[
          #   [*continuation.stack_frame.stack, args.first],
          #   env,
          #   continuation.stack_frame.line_num
          #   continuation.stack_frame.call_parent
          #   continuation.stack_frame.env_parent
          #   continuation.stack_frame.code_table_num
          # ]

          # VM[ # continuation.vmの環境を現在の環境に差し替えている
          #   continuation.vm.stack_frame_num,
          #   {
          #     **args_poped_vm.stack_frames, # continuation.vm には含まれていないスタックフレームも引き継ぐ
          #     **continuation.vm.stack_frames.to_h { |continuation_stack_frame_num, continuation_stack_frame|
          #       [
          #         continuation_stack_frame_num,
          #         StackFrame[
          #           [*continuation_stack_frame.stack, args.first], # stack
          #           args_poped_vm.stack_frames[continuation_stack_frame_num].env, # env
          #           continuation_stack_frame.line_num, # line_num
          #           continuation_stack_frame.call_parent_num, # call_parent_num
          #           continuation_stack_frame.env_parent_num, # env_parent_num
          #           continuation_stack_frame.code_table_num, # code_table_num
          #         ].freeze
          #       ]
          #     }
          #   }
          # ].freeze
        in Function => function
          args_poped_stack_frame
            .push(function.(args, stack_frame))
            .line_num_add(1)
        in Closure => closure
          # binding.irb

          StackFrame[
            [],
            closure.args.zip(args).to_h, # env
            0, # line_num
            args_poped_stack_frame.line_num_add(1), # call_parent
            closure.stack_frame, # env_parent
            closure.function_num # code_table_num
          ]
        end
      end

      def exec_gc(stack_frame)
        # TODO
        stack_frame
      end

      def Fn(&block)
        Function.new(block)
      end
    end
  end
end
