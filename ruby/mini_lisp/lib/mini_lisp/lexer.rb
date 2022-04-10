require 'rainbow/refinement'
using Rainbow

module MiniLisp
  module Lexer
    class << self
      def tokenize(src)
        regex = /\(|\)|,|`|'|#t|#f|\".+?\"|[\w\d\-+=*%_^~<>?$&|!@]+/
        tokens = src.gsub(/;.*/, '').gsub(/\s+/, ' ').scan(regex)
        tokens.map do |token|
          case token
          when '('
            Token::ParenBegin
          when ')'
            Token::ParenEnd
          when "'"
            Token::Quote
          when '`'
            Token::QuasiQuote
          when ','
            Token::UnQuote
          when '#t'
            Token::True
          when '#f'
            Token::False
          when /^(-?\d+)$/
            Token::Integer[$1.to_i]
          when /^"(.*)"$/
            Token::String[$1]
          else
            Token::Symbol[token]
          end
        end
      end
    end

    module Token
      ParenBegin = Object.new
      class << ParenBegin
        def inspect = '('.magenta
      end

      ParenEnd = Object.new
      class << ParenEnd
        def inspect = ')'.magenta
      end

      Quote = Object.new
      class << Quote
        def inspect = "'".magenta
      end

      QuasiQuote = Object.new
      class << QuasiQuote
        def inspect = '`'.magenta
      end

      UnQuote = Object.new
      class << UnQuote
        def inspect = ','.magenta
      end

      True = Object.new
      class << True
        def inspect = '#t'.magenta
      end

      False = Object.new
      class << False
        def inspect = '#f'.magenta
      end

      Integer = Struct.new(:v) do
        def inspect = v.to_s.magenta
      end

      String = Struct.new(:v) do
        def inspect = %Q("#{v}").magenta
      end

      Symbol = Struct.new(:v) do
        def inspect = v.to_s.magenta
      end
    end
  end
end
