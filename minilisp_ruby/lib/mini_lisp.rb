# frozen_string_literal: true

require_relative 'mini_lisp/version'
require_relative 'mini_lisp/lexer'
require_relative 'mini_lisp/parser'
require_relative 'mini_lisp/compiler'
require_relative 'mini_lisp/value'
require_relative 'mini_lisp/vm'
require_relative 'mini_lisp/functions'
require_relative 'mini_lisp/evaluator'

module MiniLisp
  class Error < StandardError; end

  def self.run(src)
    $debug = !!ARGV.delete('-d')
    $gc_every_time = !!ARGV.delete('-g')
    $mini = !!ARGV.delete('-m')

    stdlib = $mini ? '' : File.open(File.expand_path('../mlisp/standard_library.mlisp', __dir__)).read
    tokens = Lexer.tokenize(stdlib + src)
    puts tokens.map(&:inspect).join(' ') if $debug

    parsed = [Lexer::Token::Symbol['~'], *Parser.parse(tokens)]
    puts Parser.format(parsed) if $debug

    code_table = Compiler.compile(parsed)
    pp code_table if $debug

    Evaluator.exec(code_table)
  end
end

if __FILE__ == $PROGRAM_NAME
  MiniLisp.run <<-LISP
    (= increment (-> (init)
      (-> () (= init (+ init 1)))))
    (= inc (increment 10))
    (p (inc))
    (p (inc))
    (p (inc))
  LISP
end
