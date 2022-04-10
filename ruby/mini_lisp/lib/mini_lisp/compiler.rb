module MiniLisp
  module Compiler
    class << self
      include Lexer

      def compile(ast)
        first_code, code_table, _macro_table = compile_r(ast, [], {})
        [*code_table, first_code]
      end

      private

      def compile_r(ast, code_table, macro_table)
        case ast
        in Token::True
          [ ['true'], code_table, macro_table]
        in Token::False
          [ ['false'], code_table, macro_table]
        in Token::Integer
          [ ["int #{ast.v}"], code_table, macro_table]
        in Token::String
          [ ["str #{ast.v}"], code_table, macro_table]
        in Token::Symbol
          [ ["get #{ast.v}"], code_table, macro_table]
        in Array if ast.empty?
          [ ['nil'], code_table, macro_table ]
        in Array
          method, *args = ast
          case method
          in Token::Symbol
            case method.v
            when 'macro'
              args => [macro_name, macro_body]
              [
                [],
                code_table,
                { **macro_table, macro_name.v => macro_body }
              ]
            when 'q'
              raise '`q` take only one argument.' unless args.size == 1

              compile_quote(args.first, code_table, macro_table, false)
            when 'qq'
              raise '`qq` take only one argument.' unless args.size == 1

              compile_quote(args.first, code_table, macro_table, true)
            when 'uq'
              raise '`uq` must be inside `qq`.'
            when '~'
              args.reduce([[], code_table, macro_table]) do |(mc, mct, mmt), a|
                c, ct, mt = compile_r(a, mct, mmt)
                [[*mc, *c], ct, mt]
              end
            when 'if'
              args.reduce([[], code_table, macro_table]) do |(mc, mct, mmt), a|
                c, ct, mt = compile_r(a, mct, mmt)
                [[*mc, c], ct, mt]
              end => [[if_code, then_code, else_code], new_code_table, new_macro_table]
              [
                [
                  *if_code,
                  "jumpif #{else_code.size + 1}",
                  *else_code,
                  "jump #{then_code.size}",
                  *then_code,
                ],
                new_code_table,
                new_macro_table
              ]
            when '='
              args => [name_ast, value_ast]
              value_code, new_code_table, new_macro_table = compile_r(value_ast, code_table, macro_table)
              [
                [
                  *value_code,
                  "set #{name_ast.v}"
                ],
                new_code_table,
                new_macro_table
              ]
            when '->'
              args => [closure_args, *closure_body]
              closure_body.reduce([[], code_table, macro_table]) do |(mc, mct, mmt), a|
                c, ct, mt = compile_r(a, mct, mmt)
                [[*mc, *c], ct, mt]
              end => [closure_code, new_code_table, new_macro_table]
              [
                [ "closure #{new_code_table.size} #{closure_args.map(&:v).join(',')}" ],
                [*new_code_table, closure_code],
                new_macro_table
              ]
            when macro_table.method(:key?)
              puts "\nexpanding `#{method.v}` macro." if $debug
              tokens = [
                macro_table[method.v],
                *args.map { |a| [Token::Symbol['qq'], a] }
              ]
              puts "macro tokens: #{tokens.inspect}" if $debug
              macro_code_table = Compiler.compile(tokens)
              puts "compiled to #{macro_code_table.inspect}" if $debug
              macro_result = Evaluator.exec(macro_code_table)
              puts "expanded to #{macro_result.inspect}.\n" if $debug

              compile_r(macro_result.to_ast, code_table, macro_table)
            else
              [method, *args].reduce([[], code_table, macro_table]) do |(mc, mct, mmt), a|
                c, ct, mt = compile_r(a, mct, mmt)
                [[*mc, *c], ct, mt]
              end => [[method_code, *arg_codes], new_code_table, new_macro_table]
              [
                [
                  *arg_codes,
                  method_code,
                  "send #{args.size}"
                ],
                new_code_table,
                new_macro_table
              ]
            end.tap { raise "compiler bug!!. not match: `#{method.inspect}`" if _1.nil? }
          in Array
            [method, *args].reduce([[], code_table, macro_table]) do |(mc, mct, mmt), a|
              c, ct, mt = compile_r(a, mct, mmt)
              [[*mc, *c], ct, mt]
            end => [[method_code, *arg_codes], new_code_table, new_macro_table]
            [
              [
                *arg_codes,
                method_code,
                "send #{args.size}"
              ],
              new_code_table,
              new_macro_table
            ]
          end
        else
          raise "compiler bug!. not match: `#{ast.inspect}`"
        end
      end

      def compile_quote(ast, code_table, macro_table, quasiquote)
        case ast
        in Token::True
          [['true'], code_table, macro_table]
        in Token::False
          [['false'], code_table, macro_table]
        in Token::Integer
          [["int #{ast.v}"], code_table, macro_table]
        in Token::String
          [["str #{ast.v}"], code_table, macro_table]
        in Token::Symbol
          [["symbol #{ast.v}"], code_table, macro_table]
        in Array if ast.empty?
          [['nil'], code_table, macro_table]
        in Array
          method, *args = ast
          case method
          in Token::Symbol['uq'] if quasiquote
            raise '`uq` take only one argument.' unless args.size == 1

            compile_r(args.first, code_table, macro_table)
          else
            ast.reduce([[], code_table, macro_table]) do |(mc, mct, mmt), a|
              c, ct, mt = compile_quote(a, mct, mmt, quasiquote)
              [[*mc, *c], ct, mt]
            end => [new_code, new_code_table, new_macro_table]
            [
              [
                *new_code,
                'get list',
                "send #{ast.size}"
              ],
              new_code_table,
              new_macro_table
            ]
          end
        end
      end
    end
  end
end

