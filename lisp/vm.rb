module Lisp
  StackFrame = Struct.new(
    :stack,
    :env,
    :line_num,
    :call_parent,
    :env_parent,
    :code_table_num
  ) do
    def push(val)
      StackFrame[
        [*stack, val],
        env,
        line_num,
        call_parent,
        env_parent,
        code_table_num
      ]
    end

    def pop
      stack => [*poped_stack, poped_value]
      [
        StackFrame[
          poped_stack,
          env,
          line_num,
          call_parent,
          env_parent,
          code_table_num
        ],
        poped_value
      ]
    end

    def finish?(code_table)
      line_num == code_table[code_table_num].size
    end

    def find_variable(name)
      env[name] || env_parent&.find_variable(name)
    end

    def update_variable(name, value)
      if env[name] || find_variable(name).nil?
        StackFrame[
          stack,
          { **env, name => value },
          line_num,
          call_parent,
          env_parent,
          code_table_num
        ]
      else
        StackFrame[
          stack,
          env,
          line_num,
          call_parent,
          env_parent.update_variable(name, value),
          code_table_num
        ]
      end
    end

    def line_num_add(n)
      StackFrame[
        stack,
        env,
        line_num + n,
        call_parent,
        env_parent,
        code_table_num
      ]
    end

    def call_parent_size
      call_parent ? (1 + call_parent.call_parent_size) : 0
    end

    def env_parent_size
      env_parent ? (1 + env_parent.env_parent_size) : 0
    end

    def print_debug_log(code_table)
      all_env = Proc.new { [_1.env_parent && all_env.(_1.env_parent), _1.env].compact }
      p stack
      p all_env.(self)

      puts 'call: ' + '- ' * call_parent_size + '*'
      puts 'env:  ' + '- ' * env_parent_size + '*'
      code = code_table[code_table_num]
      line = code[line_num]
      print "code_table[#{code_table_num}][#{line_num}]"
      # puts "  = #{code}[#{line_num}]"
      puts "  = #{line.inspect}"
      puts '------------'
    end
  end

  Function = Struct.new(:proc) do
    def inspect
      "Fn#{proc.inspect.match(/rb:(\d+)/)[1]}"
    end

    def call(args, stack_frame)
      Struct.new(:args, :stack_frame).new(args, stack_frame).instance_eval(&proc)
    end
  end

  Closure = Struct.new(:function_num, :args, :stack_frame) do
    def inspect
      "Closure#{function_num}(#{args.join(',')})"
    end
  end

  Continuation = Struct.new(:stack_frame) do
    def inspect
      "Continuation"
    end
  end
end
