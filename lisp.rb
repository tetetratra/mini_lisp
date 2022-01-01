$debug = !!ARGV.delete('-d')

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

src = File.open(ARGV.first, &:read)
Lisp.run(src)

