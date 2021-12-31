$debug = ARGV.include?('-d')

require_relative 'lisp/parser.rb'
require_relative 'lisp/compiler.rb'
require_relative 'lisp/vm.rb'
require_relative 'lisp/evaluator.rb'

class Proc
  alias __inspect__ inspect
  def inspect
    'Proc' + __inspect__[/:\d+ /][/\d+/]
  end
end

class Lisp
  def self.run(src)
    puts src if $debug
    parsed = Parser.parse(src)
    pp parsed if $debug
    code_table = Compiler.compile([:~, *parsed])
    pp code_table if $debug
    Evaluator.exec(code_table)
  end
end

Lisp.run(<<~LISP)
(= f (-> (x)
  (= init x)
  (-> () (= init (+ init 1)))
))
(= inc (f 10))
(p (inc))
(inc)
(inc)
(p (inc))
LISP

=begin
require 'continuation'

def b(re)
  if rand(2).zero?
    re.()
  else
    p :b
  end
end

def a(re)
  if rand(2).zero?
    re.()
  else
    p :a
    b(re)
  end
end

callcc { |raise_exception|
  if rand(2).zero?
    raise_exception.()
  else
    p :root
    a(raise_exception)
  end
}
p :fin
=end
