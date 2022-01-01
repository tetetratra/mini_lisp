class Lisp
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

    def list_env(call_stack)
      [ *env_parent(call_stack)&.list_env(call_stack), { **env } ]
    end
  end

  Closure = Struct.new(:function_num, :args, :stack_frame_num) do
    def inspect
      "Closure#{function_num}(#{args.join(',')})"
    end
  end
end
