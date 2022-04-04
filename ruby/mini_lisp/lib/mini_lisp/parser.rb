module MiniLisp
  class Parser
    class << self
      def parse(str)
        regex = /\(|\)|[\w\d\-+=*%_@^~<>?$&|!']+|\".+?\"/
        tokens = str.gsub(/[#;].*/, '').gsub(/\s+/, ' ').scan(regex)
        parsed = [tokens.shift]
        until tokens.empty?
          parsed <<
            case s = tokens.shift
            when ')'
              poped = [')']
              until poped in ['(', *rest, ')']
                poped = [parsed.pop, *poped]
              end
              poped[1..-2]
            else
              s
            end
        end
        unless (['(', ')'] & parsed.flatten).empty?
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
        in String
          parsed
        end
      end
    end
  end
end
