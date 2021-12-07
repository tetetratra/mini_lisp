
class Lisp
  Env = Struct.new(:parent, :bindings) do
    def add(key, value)
      bindings[key] = value
      self
    end
  end

  Closure = Struct.new(:arg, :code)

  def initialize(code)
    @exp = parse(code)
    @env = Env.new(nil, {
      :+ => ->(args){ args[0] + args[1] },
      :- => ->(args){ args[0] - args[1] },
      :* => ->(args){ args[0] * args[1] },
      :'==' => ->(args){ args[0] == args[1] },
      :p => ->(args){ p args[0] }
    })
  end

  def run
    eval(@exp, @env)
  end

  private

  def parse(str)
    regex = /\(|\)|[\w\d\-+=*%_@^~<>?#$&|!]+/
    tokens = str.gsub(/\s+/, ' ').scan(regex).map do |token|
      case token
      when /\d+/
        token.to_i
      when '_'
        -rand(10000)
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
    parsed.first
  end

  def eval(exp, env)
    p exp
    pp env
    case exp
    in [:code, a]
      eval(a, env)
    in [:code, a, *b]
      eval([:code, *b], eval(a, env)[1])
    in [:'=', a, b]
      [nil, env.add(a, eval(b, env)[0])]
    in [:'->', a, b]
      [Closure.new(a, b), env]
    in [:if, a, b]
      if eval(a, env)[0]
        eval(b, env)
      end
    in [:if, a, b, c]
      if eval(a, env)[0]
        eval(b, env)
      else
        eval(c, env)
      end
    in [first, second, *rest]
      f = case first
          when Array
            eval(first, env)[0]
          else
            find_value(first, env)
          end
      case f
      in Proc
        args = [second, *rest].map { |t| eval(t, env)[0] }
        [f.call(args), env]
      in Closure
        new_env = Env.new(env, { f.arg => eval(second, env)[0] })
        eval(f.code, new_env)
      end
    in Symbol
      [find_value(exp, env), env]
    in Integer
      [exp, env]
    end
  end

  def find_value(name, env)
    def find_value_rec(name, env)
      return nil if env.nil?
      env.bindings[name] || find_value_rec(name, env.parent)
    end
    v = find_value_rec(name, env)
    if v.nil?
      puts "----------------"
      pp env
      raise "`#{name}` not found"
    end
    v
  end
end

Lisp.new(<<~LISP).run
(code
  (= inc (-> x (code
    (= i 10)
    (-> y (code
      (= i (+ i 1))
      i
    ))
  )))
  (p ((inc _) _))
)
LISP

