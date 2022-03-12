use super::parser::Ast;

// #[derive(Debug)]
// pub struct ByteCode(Vec<String>);

trait AsRef<T: ?Sized> {
    fn as_ref(&self) -> &T;
}

pub fn compile(ast: Ast) -> Vec<String> {
    match ast {
        Ast::S(s) => {
            vec![s] // TODO: 文字,数値,変数 に分ける
        }
        Ast::A(ast_vec) => {
            let first = ast_vec[0].clone();
            match first {
                Ast::S(s) if s == "~".to_string() => {
                    ast_vec.clone().drain(1..).flat_map(compile).collect()
                }
                Ast::S(s) if s == "if".to_string() => {
                    let if_compiled = compile(ast_vec[1].clone());
                    let then_compiled = compile(ast_vec[2].clone());
                    let else_compiled = compile(ast_vec[3].clone());
                    let else_compiled_len = else_compiled.len();
                    let then_compiled_len = then_compiled.len();
                    [
                        if_compiled,
                        vec![format!("jumpif@{}", else_compiled_len + 1)],
                        then_compiled,
                        vec![format!("jump@{}", then_compiled_len)],
                        else_compiled,
                    ]
                    .concat()
                }
                ast => { // マッチしなかったシンボル or ベクタ
                    let mut ast_vec_c = ast_vec.clone();
                    let args = ast_vec_c.drain(1..);
                    let args_len = args.len();
                    [
                        args.flat_map(compile).collect(),
                        compile(ast),
                        vec![format!("send@{:?}", args_len)]
                    ].concat()
                }
            }
        }
    }
}
