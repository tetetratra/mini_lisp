#! /usr/bin/env ruby -W0

$debug = !!ARGV.delete('-d')
$gc_every_time = !!ARGV.delete('-g')

require_relative 'lisp.rb'
require_relative 'lisp/parser.rb'
require_relative 'lisp/compiler.rb'
require_relative 'lisp/vm.rb'
require_relative 'lisp/evaluator.rb'

ARGV.each do |file_name|
  puts "\n----- #{file_name} -----" if $debug
  src = File.open(file_name, &:read)
  Lisp.run(src)
end

