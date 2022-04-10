require 'set'
require 'rainbow/refinement'
using Rainbow

module MiniLisp
  module Value
    include Lexer

    Nil = Object.new
    class << Nil
      def inspect = '()'.yellow
      def to_ruby = []
      def to_ast = []
    end

    True = Object.new
    class << True
      def inspect = 'true'.magenta
      def to_ruby = true
      def to_ast = Token::Symbol['true']
    end

    False = Object.new
    class << False
      def inspect = 'false'.magenta
      def to_ruby = false
      def to_ast = Token::Symbol['false']
    end

    Num = Struct.new(:v) do
      def inspect = v.inspect.magenta
      def to_ruby = v
      def to_ast = Token::Integer[v]
    end

    String = Struct.new(:v) do
      def inspect = v.inspect.cyan
      def to_ruby = v
      def to_ast = Token::String[v]
    end

    Symbol = Struct.new(:v) do
      def inspect = v.magenta
      def to_ruby = v
      def to_ast = Token::Symbol[v]
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

      def to_ast
        [head.to_ast, *rest.to_ast]
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
