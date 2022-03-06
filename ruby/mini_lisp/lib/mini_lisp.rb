# frozen_string_literal: true

require_relative 'mini_lisp/version'
require_relative 'mini_lisp/parser'
require_relative 'mini_lisp/compiler'
require_relative 'mini_lisp/evaluator'

module MiniLisp
  class Error < StandardError; end

  def self.run(src)
    # puts src if $debug
    parsed = Parser.parse(src)
    # pp parsed if $debug
    code_table = Compiler.compile([:~, *parsed])
    # pp code_table if $debug
    Evaluator.exec(code_table)
  end
end
