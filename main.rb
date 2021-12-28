
class Lisp
    Fn = Struct.new(:args, :codes)

    Closure = Struct.new(:fn, :env)

    Env = Struct.new(:parent, :bindings) do
      def add(hash)
        Env[parent, { **bindings, **hash }]
      end

      def find(name)
        find_r = ->(name, env) do
          env.bindings[name] || find_r.(name, env.parent) if env
        end
        find_r.(name, self)
      end
    end

    Frame = Struct.new(:fn, :line, :env) do
      def current_code
        fn.codes[line]
      end

      def next
        Frame[fn, line + 1, env]
      end

      def last_line?
        fn.codes.size - 1 <= line
      end

      def update_env(next_env)
        Frame[fn, line, next_env]
      end
    end

  class << self
    def run(src)
      parsed = parse("(-> () #{src})")
      @function_table = construct_function_table(parsed)
      root_fn = @function_table.first
      root_env = Env[nil, {
        :+ => ->(args, env){ args.inject(:+) },
        :- => ->(args, env){ args.first - args[1..].inject(:+) },
        :p => ->(args, env){ p args }
      }]
      root_frame = Frame[root_fn, 0, root_env]
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
      frame = cs.last
      code = frame.current_code
      env = frame.env

      # prev_value は前回のframeの計算の結果
      # calced_value は今回の計算の結果
      calced_value, next_env, new_frame = calc(code, env, prev_value)

      next_cs = if new_frame
                  [*cs[..-2], frame.next.update_env(next_env), new_frame]
                elsif frame.last_line?
                  cs[..-2]
                else
                  [*cs[..-2], frame.next.update_env(next_env)]
                end
      eval(next_cs, calced_value) unless next_cs.empty?
    end

    def calc(code, env, prev_value = nil) # 再帰OK
      puts '-------------'
      pp code
      case code
      in Integer
        [code, env]
      in Symbol => sym
        [env.find(sym), env]
      in [:'=', name, value]
        calced_value = calc(value, env)[0]
        print 'calced_value =>'
        pp calced_value
        [name, env.add({ name => calced_value })]
      in [:'->', [*args], *codes]
        fn = @function_table.find { |f| f.args == args && f.codes == codes }
        closure = Closure[fn, env]
        [closure, env]
      in [Symbol => name, *args]
        value = env.find(name)
        calc([value, *args], env)
      in [Proc => pro, *args]
        calced_args = args.map { |a| calc(a, env)[0] }
        [pro.(calced_args, env), env]
      in [Closure => closure, *args]
        calced_args = args.map { |a| calc(a, env)[0] }
        new_frame = Frame[
          closure.fn,
          0,
          closure.env.add(closure.fn.args.zip(calced_args).to_h)
        ]
        # 関数呼び出しなのでcsにpush
        [prev_value, env, new_frame]
      in nil
        [nil, nil]
      end
    end
  end
end

Lisp.run(<<~LISP)
  (= g (-> (a) b))
  (= r (g 150))
  (p r)
LISP

