
class Lisp
    Fn = Struct.new(:args, :codes)

    Env = Struct.new(:parent, :bindings) do
      def add(name, value)
        Env[parent, { **bindings, name => value }]
      end

      def find(name)
        find_r = ->(name, env) do
          env.bindings[name] || find_r.(name, env.parent) if env
        end
        find_r.(name, self)
      end
    end

    Flame = Struct.new(:fn, :line, :env) do
      def current_code
        fn.codes[line]
      end

      def next
        Flame[fn, line + 1, env]
      end

      def last_line?
        fn.codes.size - 1 == line
      end

      def update_env(next_env)
        Flame[fn, line, next_env]
      end
    end

  class << self
    def run(src)
      parsed = parse("(-> () #{src})")
      @function_table = construct_function_table(parsed)
      root_fn = @function_table.first
      root_env = Env[nil, {}]
      root_frame = Flame[root_fn, 0, root_env]
      eval([root_frame], nil)
    end

    def parse(str)
      regex = /\(|\)|[\w\d\-+=*%_@^~<>?$&|!]+/
      tokens = str.gsub(/#.*/, '').gsub(/\s+/, ' ').scan(regex).map do |token|
        case token
        when /^\d+$/
          token.to_i
        else
          token.to_sym
        end
      end
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
      parsed
    end

    def construct_function_table(exp)
      case exp
      in [:'->', [*args], *codes]
        [
          Fn.new(args, codes),
          *codes.map { |c| construct_function_table(c) }.flatten
        ]
      in [*codes]
        codes.map { |c| construct_function_table(c) }.flatten
      else
        []
      end
    end

    def eval(cs, prev_value) # 再帰NG
      print "\ncs => "
      pp cs

      frame = cs.last
      code = frame.current_code
      env = frame.env

      calced_value, next_env = calc(code, env)

      print 'calced_value => '
      pp calced_value

      next_cs = if frame.last_line?
                  cs[..-2]
                else
                  [*cs[..-2], frame.next.update_env(next_env)]
                end
      eval(next_cs, calced_value) unless next_cs.empty?
    end

    def calc(code, env) # 再帰OK
      print 'code => '
      p code
      print 'env => '
      p env

      case code
      in Integer
        [code, env]
      in Symbol => sym
        [env.find(sym), env]
      in [:'=', name, value]
        calced_value = calc(value, env)[0]
        [calced_value, env.add(name, calced_value)]
      in [Symbol => sym, *args]
      end
    end
  end
end

lisp = Lisp.run(<<~LISP)
  1
  (= x 2)
  (+ x x)
  x
LISP
# pp lisp.send(:construct_function_table, )


