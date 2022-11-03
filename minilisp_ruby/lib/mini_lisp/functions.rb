# frozen_string_literal: true

module MiniLisp
  def self.Fn(&block)
    Value::Function[block]
  end

  Functions = {
    nil?: Fn { args[0] == Value::Nil ? Value::True : Value::False },
    list: Fn { args.reverse.reduce(Value::Nil) { |cons, a| Value::Cons[a, cons] } },
    cons: Fn { Value::Cons[args[0], args[1]] },
    car: Fn { args[0].head },
    cdr: Fn { args[0].rest },
    '+': Fn { Value::Num[args[0].to_ruby + args[1].to_ruby] },
    '-': Fn { Value::Num[args[0].to_ruby - args[1].to_ruby] },
    '==': Fn { args[0].to_ruby == args[1].to_ruby ? Value::True : Value::False },
    '!=': Fn { args[0].to_ruby != args[1].to_ruby ? Value::True : Value::False },
    '!': Fn { args[0].to_ruby ? Value::False : Value::True },
    p: Fn { p args.first },
    sleep: Fn do
             sleep(args.first)
             args.first
           end,
    stack_frames_size: Fn { Value::Num[vm.stack_frames.size] },
    callcc: :callcc, # TODO: 関数ではないはず
    gc: :gc # TODO: 関数ではないはず
  }.freeze
end
