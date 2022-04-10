module MiniLisp
  module Parser
    class << self
      include Lexer::Token

      def parse(tokens)
        tokens = tokens.dup
        parsed = [tokens.shift]
        until tokens.empty?
          parsed <<
            case s = tokens.shift
            when ParenEnd
              poped = [s]
              until poped in [ParenBegin, *rest, ParenEnd]
                poped = [parsed.pop, *poped]
              end
              poped[1..-2]
            else
              s
            end
        end
        unless ([ParenBegin, ParenEnd] & parsed.flatten).empty?
          puts "Parse error:\n`#{str.chomp}` is not valid code"
          exit
        end
        parsed
      end

      def format(parsed, depth = 0)
        case parsed
        in Array
          "\n" +
            '  ' * depth + '(' +
            parsed.map { |p| format(p, depth + 1) }.join(' ') + ')'
        else
          parsed.inspect
        end
      end
    end
  end
end
