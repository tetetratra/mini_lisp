use super::parser::Ast;
use regex::Regex;

pub fn compile(ast: Ast) -> Vec<Vec<String>> {
    let (first_bytecode, mut rest_bytecodes) = compile_r(ast, vec![]);
    rest_bytecodes.push(first_bytecode);
    rest_bytecodes
}

fn compile_r(ast: Ast, code_table: Vec<Vec<String>>) -> (Vec<String>, Vec<Vec<String>>) {
    match ast {
        Ast::S(string) => {
            if string == "nil" {
                (vec!["nil".to_string()], code_table)
            } else if string == "true" || string == "#t" {
                (vec!["true".to_string()], code_table)
            } else if string == "false" || string == "#f" {
                (vec!["false".to_string()], code_table)
            } else if Regex::new(r#"^-?\d+$"#).unwrap().is_match(string.as_str()) {
                (vec![format!("int@{}", string)], code_table)
            } else if Regex::new(r#"^"(.*)"$"#).unwrap().is_match(string.as_str()) {
                (vec![format!("str@{}", string)], code_table)
            } else {
                (vec![format!("get@{}", string)], code_table)
            }
        }
        Ast::A(ast_vec) => {
            let mut ast_iter = ast_vec.into_iter();

            let first_ast = ast_iter.next().unwrap();
            let mut rest_asts = ast_iter;

            match first_ast {
                Ast::S(string) => match string.as_str() {
                    "~" => {
                        rest_asts.fold((vec![], code_table), |(memo_code, memo_code_table), ast| {
                            let (code, new_code_table) = compile_r(ast, memo_code_table);
                            (vec![memo_code, code].concat(), new_code_table)
                        })
                    }
                    "if" => {
                        let (if_compiled, code_table) =
                            compile_r(rest_asts.next().unwrap(), code_table);
                        let (then_compiled, code_table) =
                            compile_r(rest_asts.next().unwrap(), code_table);
                        let (else_compiled, code_table) =
                            compile_r(rest_asts.next().unwrap(), code_table);
                        (
                            [
                                if_compiled,
                                vec![format!("jumpif@{}", else_compiled.len() + 1)],
                                else_compiled,
                                vec![format!("jump@{}", then_compiled.len())],
                                then_compiled,
                            ]
                            .concat(),
                            code_table,
                        )
                    }
                    "while" => {
                        let (compiled_cond, code_table) =
                            compile_r(rest_asts.next().unwrap(), code_table);
                        let compiled_cond_len = compiled_cond.len();
                        let (compiled_statements, code_table) = rest_asts.fold(
                            (vec![], code_table),
                            |(memo_code, memo_code_table), ast| {
                                let (code, new_code_table) = compile_r(ast, memo_code_table);
                                (vec![memo_code, code].concat(), new_code_table)
                            },
                        );
                        let compiled_statements_len = compiled_statements.len();
                        (
                            vec![
                                compiled_cond,
                                vec![format!("jumpunless@{}", compiled_statements.len() + 1)],
                                compiled_statements,
                                vec![format!(
                                    "jump@{}",
                                    -(2 + compiled_statements_len as i32
                                        + compiled_cond_len as i32)
                                )],
                                vec!["get@nil".to_string()],
                            ]
                            .concat(),
                            code_table,
                        )
                    }
                    "=" => {
                        if let Ast::S(variable_name) = rest_asts.next().unwrap() {
                            let (code_val, code_table) =
                                compile_r(rest_asts.next().unwrap(), code_table);
                            (
                                vec![code_val, vec![format!("set@{}", variable_name)]].concat(),
                                code_table,
                            )
                        } else {
                            panic!()
                        }
                    }
                    "->" => {
                        if let Ast::A(args) = rest_asts.next().unwrap() {
                            let joined_args = args
                                .into_iter()
                                .map(|arg| match arg {
                                    Ast::S(string) => string,
                                    Ast::A(_) => {
                                        panic!()
                                    }
                                })
                                .collect::<Vec<String>>()
                                .join(",");
                            let (new_code, code_table) = rest_asts.fold(
                                (vec![], code_table),
                                |(memo_code, memo_code_table), ast| {
                                    let (new_code, code_table) = compile_r(ast, memo_code_table);
                                    (vec![memo_code, new_code].concat(), code_table)
                                },
                            );
                            let closure_index = code_table.len();
                            (
                                vec![format!("closure@{}@{}", closure_index, joined_args)],
                                vec![code_table, vec![new_code]].concat(),
                            )
                        } else {
                            panic!()
                        }
                    }
                    _ => compile_other(
                        Ast::A(std::iter::once(Ast::S(string)).chain(rest_asts).collect()),
                        code_table,
                    ),
                },
                ast_a @ Ast::A(_) => compile_other(
                    Ast::A(std::iter::once(ast_a).chain(rest_asts).collect()),
                    code_table,
                ),
            }
        }
    }
}

fn compile_other(ast: Ast, code_table: Vec<Vec<String>>) -> (Vec<String>, Vec<Vec<String>>) {
    // (method ...) | ((...) ...)
    match ast {
        Ast::A(ast_vec) => {
            let mut ast_iter = ast_vec.into_iter();
            let first_ast = ast_iter.next().unwrap();
            let rest_asts = ast_iter;

            let args_len = rest_asts.len();
            let (code_ast, code_table) = compile_r(first_ast, code_table);
            let (code, code_table) =
                rest_asts.fold((vec![], code_table), |(memo_code, memo_code_table), ast| {
                    let (new_code, code_table) = compile_r(ast, memo_code_table);
                    (vec![memo_code, new_code].concat(), code_table)
                });
            (
                [code, code_ast, vec![format!("send@{:?}", args_len)]].concat(),
                code_table,
            )
        }
        Ast::S(_) => {
            panic!()
        }
    }
}
