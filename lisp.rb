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
(= x 10)
(= cnt 'tmp')
(callcc (-> (continuation)
  (= cnt continuation)
))
(= x (+ x -1))
(p x)
(if (== x 0)
  (puts 'finish')
  (cnt)
)

(puts '-----------')
(= f (-> (raise)
  (puts 'before raise')
  (raise)
  (puts 'after raise')
))
(puts 'before callcc')
(callcc (-> (raise)
  (puts 'before f')
  (f raise)
  (puts 'after f')
))
(puts 'after callcc')

(puts '-----------')
(= cnt 'tmp')
(= r (callcc (-> (continuation)
  (= cnt continuation)
  10
)))
(p r)
(if (== 100 r)
  (puts 'fin')
  (cnt 100)
)
LISP

