require 'set'
require 'rainbow/refinement'
using Rainbow

module MiniLisp
  module Value
    class Nil
      def inspect
        'nil'.magenta
      end
      def to_ruby
        nil
      end
    end

    class True
      def inspect
        'true'.magenta
      end
      def to_ruby
        true
      end
    end

    class False
      def inspect
        'false'.magenta
      end
      def to_ruby
        false
      end
    end

    Num = Struct.new(:v) do
      def inspect
        v.inspect.magenta
      end
      def to_ruby
        v
      end
    end

    String = Struct.new(:v) do
      def inspect
        v.inspect.cyan
      end
      def to_ruby
        v
      end
    end

    Function = Struct.new(:proc) do
      def inspect
        'Fn'.red
      end

      def call(args, vm)
        Struct.new(:args, :vm).new(args, vm).instance_eval(&proc)
      end
    end

    Cons = Struct.new(:head, :rest) do
      def inspect
        '('.yellow + head.inspect + ' ' + rest.inspect + ')'.yellow
      end
    end

    Closure = Struct.new(:function_num, :args, :stack_frame_num) do
      def inspect
        "->#{stack_frame_num}[#{function_num}](#{args.join(',')})".blue
      end
    end

    Continuation = Struct.new(:vm) do
      def inspect
        "Cont#{vm.stack_frames.keys.to_set.inspect[/{.*}/]}".green
      end
    end
  end
end
