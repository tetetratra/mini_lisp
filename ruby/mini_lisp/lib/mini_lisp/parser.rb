module MiniLisp
  class Parser
    def self.parse(str)
      regex = /\(|\)|[\w\d\-+=*%_@^~<>?$&|!']+|\".+?\"/
      tokens = str.gsub(/[#;].*/, '').gsub(/\s+/, ' ').scan(regex).map(&:to_sym)
      parsed = [tokens.shift]
      until tokens.empty?
        parsed <<
          case s = tokens.shift
          when :')'
            poped = [:')']
            until poped in [:'(', *rest, :')']
              poped = [parsed.pop, *poped]
            end
            poped[1..-2]
          else
            s
          end
      end
      unless ([:'(', :')'] & parsed.flatten).empty?
        puts "Parse error:\n`#{str.chomp}` is not valid code"
        exit
      end
      parsed
    end
  end
end
