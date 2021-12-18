
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
    in [:callcc, closure_node] # TODO: 未実装
    # eval(exp, env, call_stack) にする？
    # Callcc構造体に保存する
    in [Callcc => cc, *rest] # TODO: 未実装
    in [Proc => pr, *rest] # 組み込み関数
      args = rest.map { |t| eval(t, env)[0] }
      [pr.call(args), env]
    in [Closure => cl, *rest] # ユーザー定義のクロージャ
      new_env = Env.new(
        cl.env,
        cl.args.zip(rest.map { |r| eval(r, env)[0] }).to_h
      )
      eval(cl.code, new_env)
    in [first, *rest] # 関数呼び出しはこの形
      # (p (f))は関数を呼び出ている。(p f)は関数を扱っているだけ
      f = case first
          when Array
            eval(first, env)[0]
          else
            find_value(first, env)
          end
      eval([f, *rest], env)
    end
  end

  def find_value(name, env)
    v = find_value_rec(name, env)
    if v.nil?
      pp env
      raise "`#{name}` not found"
    end
    v
  end

  def find_value_rec(name, env)
    return nil if env.nil?
    env.bindings[name] || find_value_rec(name, env.parent)
  end
end

Lisp.new(<<~LISP).run
(~
  (= c 0)
  (= f3 (-> () (~
    (p 300)
  )))
  (= f2 (-> () (~
    (p 200)
    (= c (callcc (-> cnt cnt)))
    (f3)
  )))
  (= f1 (-> () (~
    (p 100)
    (f2)
  )))
  (p (f1)) # 100 200 300 300
  (c) # 300 300
)
LISP

