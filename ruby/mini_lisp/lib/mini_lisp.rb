# frozen_string_literal: true

require_relative 'mini_lisp/version'
require_relative 'mini_lisp/parser'
require_relative 'mini_lisp/compiler'
require_relative 'mini_lisp/vm'
require_relative 'mini_lisp/evaluator'

module MiniLisp
  class Error < StandardError; end

  def self.run(src)
    puts src if $debug
    parsed = Parser.parse(src)
    pp parsed if $debug
    code_table = Compiler.compile([:~, *parsed])
    pp code_table if $debug
    Evaluator.exec(code_table)
  end
end

# bundle exec ruby -W0 lib/mini_lisp.rb ../../if.mlisp -g -d
if $PROGRAM_NAME == __FILE__
  $debug = !!ARGV.delete('-d')
  $gc_every_time = !!ARGV.delete('-g')
  src = File.open(ARGV.first).read
  MiniLisp.run(src)
end
