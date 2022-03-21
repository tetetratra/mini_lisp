require 'set'
require 'rainbow/refinement'
using Rainbow

module MiniLisp
  module Value
    Nil = Struct.new(:_) do
      def inspect = 'nil'.magenta
      def to_ruby = nil
    end

    True = Struct.new(:_) do
      def inspect = 'true'.magenta
      def to_ruby = true
    end

    False = Struct.new(:_) do
      def inspect = 'false'.magenta
      def to_ruby = false
    end

    Num = Struct.new(:v) do
      def inspect = v.inspect.magenta
      def to_ruby = v
    end

    String = Struct.new(:v) do
      def inspect = v.inspect.cyan
      def to_ruby = v
    end

    Function = Struct.new(:proc) do
      def inspect = 'Fn'.red

      def call(args, vm)
        Struct.new(:args, :vm).new(args, vm).instance_eval(&proc)
      end
    end

    Cons = Struct.new(:head, :rest) do
      def inspect
        '('.yellow + head.inspect + ' . ' + rest.inspect + ')'.yellow
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