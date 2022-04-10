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
        def inspect = '('
      end

      ParenEnd = Object.new
      class << ParenEnd
        def inspect = ')'
      end

      Quote = Object.new
      class << Quote
        def inspect = "'"
      end

      QuasiQuote = Object.new
      class << QuasiQuote
        def inspect = '`'
      end

      UnQuote = Object.new
      class << UnQuote
        def inspect = ','
      end

      True = Object.new
      class << True
        def inspect = '#t'
      end

      False = Object.new
      class << False
        def inspect = '#f'
      end

      Integer = Struct.new(:v) do
        def inspect = v
      end

      String = Struct.new(:v) do
        def inspect = %Q("#{v}")
      end

      Symbol = Struct.new(:v) do
        def inspect = v
      end
    end
  end
end
