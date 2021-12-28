
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

  Code = Struct.new(:exp, :line)

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
    case exp
    in []
      [nil, env]
    in Symbol
      [find_value(exp, env), env]
    in Integer
      [exp, env]
    in [:code | :~, *rest]
      eval([Code.new(rest, 0), *rest], env)
    in [:'=', a, b]
      b_value = eval(b, env)[0]
      [nil, env.add(a, b_value)]
    in [:'->', [*vars], code]
      [Closure.new(vars, code, env), env]
    in [:if, *rest]
      case rest
      in [a,b]
        if eval(a, env)[0]
          eval(b, env)
        else
          [nil, env]
        end
      in [a,b,c]
        if eval(a, env)[0]
          eval(b, env)
        else
          eval(c, env)
        end
      end
    in [Code => code, *args]
      # pp exp
      case args
      in [current]
        eval(current, env)
      in [current, *rest]
        eval([Code.new(rest, code.line + 1), *rest], eval(current, env)[1])
      end
    # in [:callcc, closure_node]
      # TODO: 未実装
      # eval(exp, env, call_stack) にする？
      # Callcc構造体に保存する
      # code組み込み関数でevalするときに、
    # in [Callcc => cc, *rest]
      # TODO: 未実装
    in [Proc => pr, *rest] # (組み込みの)関数の呼び出し
      args = rest.map { |t| eval(t, env)[0] }
      [pr.call(args), env]
    in [Closure => cl, *rest] # (ユーザー定義の)クロージャの呼び出し
      new_env = Env.new(
        cl.env,
        cl.args.zip(rest.map { |r| eval(r, env)[0] }).to_h
      )
      eval(cl.code, new_env)
    in [Array => first, *rest]
      f = eval(first, env)[0]
      eval([f, *rest], env)
    in [Symbol => first, *rest] # (p (f))は関数を呼び出ている。(p f)は関数を扱っているだけ
      f = find_value(first, env)
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
LISP

