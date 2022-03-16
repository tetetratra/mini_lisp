use super::parser::Ast;
use regex::Regex;

pub fn compile(ast: Ast, code_table: Vec<Vec<String>>) -> (Vec<String>, Vec<Vec<String>>) {
    let mut code_table = code_table.clone();
    let code = match ast {
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
            let mut ast_vec_iter = ast_vec.into_iter();

            let first_ast = ast_vec_iter.next().unwrap();
            let mut rest_asts = ast_vec_iter;

            match first_ast {
                Ast::S(s) if s == "~".to_string() => rest_asts
                    .flat_map(|a| {
                        let (c, next_code_table) = compile(a, code_table.clone());
                        code_table = next_code_table;
                        c
                    })
                    .collect(),
                Ast::S(s) if s == "if".to_string() => {
                    let (if_compiled, code_table_if) =
                        compile(rest_asts.next().unwrap(), code_table.clone());
                    code_table = code_table_if;
                    let (then_compiled, code_table_then) =
                        compile(rest_asts.next().unwrap(), code_table.clone());
                    code_table = code_table_then;
                    let (else_compiled, code_table_else) =
                        compile(rest_asts.next().unwrap(), code_table.clone());
                    code_table = code_table_else;
                    let else_compiled_len = else_compiled.len();
                    let then_compiled_len = then_compiled.len();
                    [
                        if_compiled,
                        vec![format!("jumpif@{}", else_compiled_len + 1)],
                        else_compiled,
                        vec![format!("jump@{}", then_compiled_len)],
                        then_compiled,
                    ]
                    .concat()
                }
                Ast::S(s) if s == "while".to_string() => {
                    let cond = rest_asts.next().unwrap();
                    let (compiled_cond, code_table_cond) = compile(cond, code_table.clone());
                    code_table = code_table_cond;
                    let compiled_cond_len = compiled_cond.len();

                    let statements: Vec<Ast> = rest_asts.collect();
                    let compiled_statements: Vec<String> = statements
                        .into_iter()
                        .flat_map(|s| {
                            let (code_s, code_table_s) = compile(s, code_table.clone());
                            code_table = code_table_s;
                            code_s
                        })
                        .collect();
                    let compiled_statements_len = compiled_statements.len();

                    vec![
                        compiled_cond,
                        vec![format!("jumpunless@{}", compiled_statements_len + 1)],
                        compiled_statements,
                        vec![format!(
                            "jump@{}",
                            -(2 + compiled_statements_len as i32 + compiled_cond_len as i32)
                        )],
                        vec!["get@nil".to_string()],
                    ]
                    .concat()
                }
                Ast::S(s) if s == "=".to_string() => {
                    let variable_name = if let Ast::S(vn) = rest_asts.next().unwrap() {
                        vn
                    } else {
                        panic!()
                    };
                    let (code_val, code_table_val) =
                        compile(Ast::A(rest_asts.collect()), code_table.clone());
                    code_table = code_table_val;
                    vec![code_val, vec![format!("set@{}", variable_name)]].concat()
                }
                Ast::S(s) if s == "->".to_string() => {
                    let args_ast = rest_asts.next().unwrap();
                    let args: String = if let Ast::A(a) = args_ast {
                        a.into_iter()
                            .map(|aa| match aa {
                                Ast::S(string) => string,
                                Ast::A(_) => {
                                    panic!()
                                }
                            })
                            .collect::<Vec<String>>()
                            .join(",")
                    } else {
                        panic!()
                    };
                    let codes_ast = rest_asts;
                    let new_code = codes_ast
                        .flat_map(|c| {
                            let (c, next_code_table) = compile(c, code_table.clone());
                            code_table = next_code_table;
                            c
                        })
                        .collect();

                    let closure_index = code_table.len();
                    code_table.push(new_code);
                    vec![format!("closure@{}@{}", closure_index, args)]
                }
                _ => {
                    // (method ...) | ((...) ...)
                    let args = rest_asts;
                    let args_len = args.len();

                    let (code_ast, code_table_ast) = compile(first_ast, code_table.clone());
                    code_table = code_table_ast;
                    [
                        args.flat_map(|a| {
                            let (c, next_code_table) = compile(a, code_table.clone());
                            code_table = next_code_table;
                            c
                        })
                        .collect(),
                        code_ast,
                        vec![format!("send@{:?}", args_len)],
                    ]
                    .concat()
                }
            }
        }
    };
    (code, code_table)
}
