module MiniLisp
  def self.Fn(&block)
    Value::Function[block]
  end

  Functions = {
    :nil => Value::Nil[],
    :true => Value::True[],
    :false => Value::False[],
    :nil? => Fn { args[0] == Value::Nil[] ? Value::True[] : Value::False[] },
    :list => Fn { args.reverse.reduce(Value::Nil[]) { |cons, a| Value::Cons[a, cons] } },
    :cons => Fn { Value::Cons[args[0], args[1]] },
    :car => Fn { args[0].car },
    :cdr => Fn { args[0].cdr },
    :'+' => Fn { Value::Num[args[0].to_ruby + args[1].to_ruby] },
    :'-' => Fn { Value::Num[args[0].to_ruby - args[1].to_ruby] },
    :'==' => Fn { args[0].to_ruby == args[1].to_ruby ? Value::True[] : Value::False[] },
    :'!=' => Fn { args[0].to_ruby != args[1].to_ruby ? Value::True[] : Value::False[] },
    :'!' => Fn { args[0].to_ruby ? Value::False[] : Value::True[] },
    :p => Fn { p args.first },
    :sleep => Fn { sleep(args.first); args.first },
    :stack_frames_size => Fn { vm.stack_frames.size },
    :callcc => :callcc,
    :gc => :gc,
  }
end
