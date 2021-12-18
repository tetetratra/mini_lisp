
class Lisp
  Env = Struct.new(:parent, :bindings) do
    def add(key, value)
      bindings[key] = value unless add_rec(key, value)
      self
    end

    def add_rec(key, value)
      if bindings[key]
        bindings[key] = value
        true
      else
        if parent.nil?
          false
        else
          parent.add_rec(key, value)
        end
      end
    end
  end

  Closure = Struct.new(:args, :code, :env)

  def initialize(code)
    @exp = parse(code)
    @env = Env.new(nil, {
      :+ => ->(args){ args[0] + args[1] },
      :- => ->(args){ args[0] - args[1] },
      :* => ->(args){ args[0] * args[1] },
      :'==' => ->(args){ args[0] == args[1] },
      :'!=' => ->(args){ args[0] == args[1] },
      :p => ->(args){ p args[0] }
    })
  end

  def run
    eval(@exp, @env)
  end

  private

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
    parsed = tokens[1..].reduce([tokens.first]) do |parsed, token|
      case token
      when :')'
        # findパターンは最初のマッチを取り出してしまうためreverse
        parsed.reverse => [*after_reversed_rest, :'(', *before_reversed_rest]
        before_rest = before_reversed_rest.reverse
        after_rest = after_reversed_rest.reverse
        [*before_rest, after_rest]
      else
        [*parsed, token]
      end
    end
    parsed.first
  end

  def eval(exp, env)
    case exp
    in []
      [nil, env]
    in Symbol
      [find_value(exp, env), env]
    in Integer
      [exp, env]
    in [:code | :~, a]
      eval(a, env)
    in [:code | :~, a, *b]
      eval([:code, *b], eval(a, env)[1])
    in [:'=', a, b]
      b_value = eval(b, env)[0]
      [nil, env.add(a, b_value)]
    in [:'->', [*vars], code]
      [Closure.new(vars, code, env), env]
    in [:if, a, b]
      if eval(a, env)[0]
        eval(b, env)
      else
        [nil, env]
      end
    in [:if, a, b, c]
      if eval(a, env)[0]
        eval(b, env)
      else
        eval(c, env)
      end
    in [:callcc, closure_node]
      closure = eval(closure_node, env)[0]
      # TODO: リターンアドレスのようなものをevalの引数に加えないとダメかも。
      # もしくは現在の全体のexpをどうにかして入手するか。
      # そのためには再帰的にevalするんじゃなくてスタックマシンっぽくしないといけないかも
      cnt = nil
      eval([closure, cnt], env)
    in [first, *rest]
      f = case first
          when Array
            eval(first, env)[0]
          else
            find_value(first, env)
          end
      case f
      in Proc # 組み込み
        args = rest.map { |t| eval(t, env)[0] }
        [f.call(args), env]
      in Closure # ユーザー定義
        new_env = Env.new(
          f.env,
          f.args.zip(rest.map { |r| eval(r, env)[0] }).to_h
        )
        eval(f.code, new_env)
      end
    end
  end

  def find_value(name, env)
    def find_value_rec(name, env)
      return nil if env.nil?
      env.bindings[name] || find_value_rec(name, env.parent)
    end
    v = find_value_rec(name, env)
    if v.nil?
      pp env
      raise "`#{name}` not found"
    end
    v
  end
end

Lisp.new(<<~LISP).run
(p (+ (+ 1 2) (+ 3 4)))
LISP
# (~
#   (= f (-> () (~
#     (p 1)
#     (= c (callcc (-> (cnt) cnt)))
#     (p 2)
#     c
#   )))
#   (p 0)
#   (= cc (f ()))
#   (if (!= cc 100) (cc 100))
# )

