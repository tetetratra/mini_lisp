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
