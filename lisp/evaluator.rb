require 'set'
require 'rainbow/refinement'
using Rainbow

module Lisp
  class Evaluator
    class << self
      def exec(code_table)
        init_vm = VM[
          0,
          {
            0 => StackFrame[
              [],
              {
                :nil => nil,
                :true => true,
                :t => true,
                :false => false,
                :f => false,
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
              },
              0,
              nil,
              nil,
              0
            ].freeze
          }
        ].freeze

        print_code_table(init_vm, code_table) if $debug

        loop.reduce(init_vm) do |vm, _|
          if vm.current_stack_frame_finish?(code_table)
            print_stack_frame(vm, code_table) if $debug
            if vm.current_stack_frame.call_parent_num.nil?
              break
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
          when /^jumpif@(-?\d+)/
            cond = vm.current_stack_frame.stack.last
            if cond
              vm.current_stack_frame_line_num_add($1.to_i + 1)
            else
              vm.current_stack_frame_line_num_add(1)
            end
          when /^jump@(-?\d+)/
            vm.current_stack_frame_line_num_add($1.to_i + 1)
          else
            raise "command `#{line.inspect}` is not found"
          end.then { $gc_every_time ? _1.gc : _1 }
        end
      end

      private

      def exec_send(vm, code_table, argc)
        method_poped_vm, method = vm.current_stack_frame_stack_pop
        args_poped_vm, args = argc.times
          .reduce([method_poped_vm, []]) { |(memo_vm, args), _|
          next_vm, poped = memo_vm.current_stack_frame_stack_pop
          [next_vm, [poped, *args]]
        }
        case method
        in :callcc
          continuation = Continuation[
            args_poped_vm
              .current_stack_frame_line_num_add(1)
          ]

          closure = args.first

          new_stack_frame = StackFrame[
            [],
            { closure.args.first => continuation },
            0,
            args_poped_vm.stack_frame_num,
            closure.stack_frame_num,
            closure.function_num
          ].freeze
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
        in Continuation => continuation
          # continuation.vmの環境を現在の環境に差し替えている
          next_vm = VM[
            continuation.vm.stack_frame_num,
            {
               # continuation.vm には含まれていないスタックフレームも引き継ぐ
              **args_poped_vm.stack_frames,
              **continuation.vm.stack_frames.to_h { |continuation_stack_frame_num, continuation_stack_frame|
                [
                  continuation_stack_frame_num,
                  StackFrame[
                    [*continuation_stack_frame.stack, args.first],
                    args_poped_vm.stack_frames[continuation_stack_frame_num].env,
                    continuation_stack_frame.line_num,
                    continuation_stack_frame.call_parent_num,
                    continuation_stack_frame.env_parent_num,
                    continuation_stack_frame.code_table_num,
                  ].freeze
                ]
              }
            }
          ].freeze
          print_code_table(next_vm, code_table) if $debug
          print_stack_frame(next_vm, code_table) if $debug
          next_vm
        in Function => function
          args_poped_vm
            .current_stack_frame_stack_push(function.(args, vm))
            .current_stack_frame_line_num_add(1)
        in Closure => closure
          new_stack_frame = StackFrame[
            [],
            closure.args.zip(args).to_h,
            0,
            args_poped_vm.stack_frame_num,
            closure.stack_frame_num,
            closure.function_num
          ].freeze
          new_stack_frame_num = args_poped_vm.available_stack_frame_num
          next_vm = args_poped_vm
            .current_stack_frame_line_num_add(1)
            .insert_stack_frame(new_stack_frame_num, new_stack_frame)
            .change_stack_frame_num(new_stack_frame_num)
          print_code_table(next_vm, code_table) if $debug
          next_vm
        end
      end

      def Fn(&block)
        Function.new(block)
      end

      def print_code_table(vm, code_table)
        puts ({ vm.current_stack_frame.code_table_num => code_table[vm.current_stack_frame.code_table_num] }).inspect.red
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
