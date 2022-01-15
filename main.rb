#! /usr/bin/env ruby -W0

$debug = !!ARGV.delete('-d')

require_relative 'lisp.rb'
require_relative 'lisp/parser.rb'
require_relative 'lisp/compiler.rb'
require_relative 'lisp/vm.rb'
require_relative 'lisp/evaluator.rb'

src = File.open(ARGV.first, &:read)
Lisp.run(src)

