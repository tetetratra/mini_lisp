# frozen_string_literal: true

module MiniLisp
  module Parser
    class << self
      def parse(tokens)
        tokens = tokens.dup
        parsed = [tokens.shift]
        until tokens.empty?
          case s = tokens.shift
          when Lexer::Token::ParenEnd
            poped = [s]
            poped.unshift(parsed.pop) until poped in [Lexer::Token::ParenBegin, *rest, Lexer::Token::ParenEnd]
            poped = poped[1..-2]
            case parsed.last
            when Lexer::Token::Quote
              parsed.pop
              parsed << [Lexer::Token::Symbol['q'], poped]
            when Lexer::Token::QuasiQuote
              parsed.pop
              parsed << [Lexer::Token::Symbol['qq'], poped]
            when Lexer::Token::UnQuote
              parsed.pop
              parsed << [Lexer::Token::Symbol['uq'], poped]
            else
              parsed << poped
            end
          when Lexer::Token::ParenBegin
            parsed << s
          else
            case parsed.last
            when Lexer::Token::Quote
              parsed.pop
              parsed << [Lexer::Token::Symbol['q'], s]
            when Lexer::Token::QuasiQuote
              parsed.pop
              parsed << [Lexer::Token::Symbol['qq'], s]
            when Lexer::Token::UnQuote
              parsed.pop
              parsed << [Lexer::Token::Symbol['uq'], s]
            else
              parsed << s
            end
          end
        end
        unless ([Lexer::Token::ParenBegin, Lexer::Token::ParenEnd] & parsed.flatten).empty?
          raise "Parse error: parentheses are not valid"
        end

        parsed
      end

      def format(parsed, depth = 0)
        case parsed
        when Array
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
