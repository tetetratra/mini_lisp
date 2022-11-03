# MiniLisp

おもちゃのLispインタプリタ

## 機能

|                  | ruby | rust |
| ---------------- | ---- | ---- |
| consセル         | ✅   | ⬜   |
| if, while        | ✅   | ✅   |
| 第一級クロージャ | ✅   | ✅   |
| call/cc          | ✅   | ⬜   |
| マクロ           | ✅   | ⬜   |
| GC               | 🔼   | ⬜   |

## 使い方

Ruby
```
$ cd minilisp_ruby
$ bin/run ../sample_code/fib.mlisp
```

Rust
```
$ cd minilisp_rust
$ cargo run ../sample_code/fib.mlisp
```

