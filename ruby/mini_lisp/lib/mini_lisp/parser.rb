module MiniLisp
  module Parser
    class << self
      include Lexer

      def parse(tokens)
        tokens = tokens.dup
        parsed = [tokens.shift]
        until tokens.empty?
          case s = tokens.shift
          when Token::ParenEnd
            poped = [s]
            until poped in [Token::ParenBegin, *rest, Token::ParenEnd]
              poped.unshift(parsed.pop)
            end
            poped = poped[1..-2]
            case parsed.last
            when Token::Quote
              parsed.pop
              parsed << [Token::Symbol['q'], poped]
            when Token::QuasiQuote
              parsed.pop
              parsed << [Token::Symbol['qq'], poped]
            when Token::UnQuote
              parsed.pop
              parsed << [Token::Symbol['uq'], poped]
            else
              parsed << poped
            end
          when Token::ParenBegin
            parsed << s
          else
            case parsed.last
            when Token::Quote
              parsed.pop
              parsed << [Token::Symbol['q'], s]
            when Token::QuasiQuote
              parsed.pop
              parsed << [Token::Symbol['qq'], s]
            when Token::UnQuote
              parsed.pop
              parsed << [Token::Symbol['uq'], s]
            else
              parsed << s
            end
          end
        end
        unless ([Token::ParenBegin, Token::ParenEnd] & parsed.flatten).empty?
          raise "Parse error:\n`#{str.chomp}` is not valid code"
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
