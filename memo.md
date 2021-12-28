コールスタック

- eval(call_stack, env)にする?
  - 方法
    - codeが来たらcall_stackにpush
    - topがcodeなら実行してline+=1, 終わったらpop
  - s式をどうやって見ていくかの問題がある
    - 実行前にコンパイルする?
     - 関数のテーブルっぽいものを作っておく

```ruby
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
```
