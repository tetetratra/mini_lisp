require 'rainbow/refinement'
using Rainbow

module Lisp
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

    def available_stack_frame_num
      (0..).find { |n| !stack_frames.keys.include?(n) }
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

    def gc
      keep = stack_frames.to_h { |num, _sf| [num, false] }

      keep[stack_frame_num] = true
      stack = [stack_frame_num]

      until stack.empty?
        poped_stack_frame_num = stack.pop
        stack_frame = stack_frames[poped_stack_frame_num]

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
        stack_frame_num,
        stack_frames.select { |num, _sf| keep[num] }
      ]
    end
  end

  StackFrame = Struct.new(
    :stack,
    :env,
    :line_num,
    :call_parent_num,
    :env_parent_num,
    :code_table_num
  ) do
    def env_parent(call_stack)
      call_stack[env_parent_num]
    end

    def find_env(name, call_stack)
      env[name] || env_parent(call_stack)&.find_env(name, call_stack)
    end
  end

  Function = Struct.new(:proc) do
    def inspect
      'Fn'
    end

    def call(args, vm)
      Struct.new(:args, :vm).new(args, vm).instance_eval(&proc)
    end
  end

  Closure = Struct.new(:function_num, :args, :stack_frame_num) do
    def inspect
      "->#{function_num}(#{args.join(',')})".blue
    end
  end

  Continuation = Struct.new(:vm) do
    def inspect
      "Cont".green
    end
  end
end
