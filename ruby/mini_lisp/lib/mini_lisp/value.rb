# frozen_string_literal: true

require 'set'
require 'rainbow/refinement'
using Rainbow

module MiniLisp
  module Value
    class Nil
      class << self
        def inspect = '()'.yellow
        def to_ruby = []
        def to_ast = []
      end
    end

    class True
      class << self
        def inspect = 'true'.magenta
        def to_ruby = true
        def to_ast = Lexer::Token::True
      end
    end

    class False
      class << self
        def inspect = 'false'.magenta
        def to_ruby = false
        def to_ast = Lexer::Token::False
      end
    end

    Num = Struct.new(:v) do
      def inspect = v.inspect.magenta
      def to_ruby = v
      def to_ast = Lexer::Token::Integer[v]
    end

    String = Struct.new(:v) do
      def inspect = v.inspect.cyan
      def to_ruby = v
      def to_ast = Lexer::Token::String[v]
    end

    Symbol = Struct.new(:v) do
      def inspect = v.magenta
      def to_ruby = v
      def to_ast = Lexer::Token::Symbol[v]
    end

    Function = Struct.new(:proc) do
      def inspect = 'Fn'.red

      def call(args, vm)
        Struct.new(:args, :vm).new(args, vm).instance_eval(&proc)
      end
    end

    Cons = Struct.new(:head, :rest) do
      def inspect
        "#{'('.yellow}#{head.inspect} . #{rest.inspect}#{')'.yellow}"
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
