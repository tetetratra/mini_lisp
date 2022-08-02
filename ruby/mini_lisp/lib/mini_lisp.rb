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
    stdlib = $mini ? '' : File.open(File.expand_path('../../mlisp/standard_library.mlisp', __FILE__)).read
    tokens = Lexer.tokenize(stdlib + src)
    puts tokens.map(&:inspect).join(' ') if $debug

    parsed = [Lexer::Token::Symbol['~'], *Parser.parse(tokens)]
    puts Parser.format(parsed) if $debug

    code_table = Compiler.compile(parsed)
    pp code_table if $debug

    Evaluator.exec(code_table)
  end
end
