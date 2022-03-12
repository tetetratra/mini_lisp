use regex::Regex;
use super::parser::Ast;

// #[derive(Debug)]
// pub struct ByteCode(Vec<String>);

trait AsRef<T: ?Sized> {
    fn as_ref(&self) -> &T;
}

pub fn compile(ast: Ast) -> Vec<String> {
    match ast {
        Ast::S(s) => {
            if Regex::new(r#"^-?\d+$"#).unwrap().is_match(s.as_str()) {
                vec![format!("int@{}", s)]
            } else if Regex::new(r#"^"(.*)"$"#).unwrap().is_match(s.as_str()) {
                vec![format!("str@{}", s)]
            } else {
                vec![format!("get@{}", s)]
            }
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
                        else_compiled,
                        vec![format!("jump@{}", then_compiled_len)],
                        then_compiled
                    ]
                    .concat()
                }
                Ast::S(s) if s == "while".to_string() => {
                    let cond = ast_vec[1].clone();
                    let compiled_cond = compile(cond);
                    let compiled_cond_len = compiled_cond.len();

                    let statements: Vec<Ast> = ast_vec.clone().drain(2..).collect();
                    let compiled_statements: Vec<String> = statements.into_iter().flat_map(compile).collect();
                    let compiled_statements_len = compiled_statements.len();

                    vec![
                      compiled_cond,
                      vec![format!("jumpunless@{}", compiled_statements_len + 1)],
                      compiled_statements,
                      vec![format!("jump@{}", -(2 + compiled_statements_len as i32 + compiled_cond_len as i32))],
                      vec!["get@nil".to_string()]
                    ].concat()
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
