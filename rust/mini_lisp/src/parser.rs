use regex::Regex;
use std::fmt;

#[derive(Clone)]
pub enum Ast {
    S(String),
    A(Vec<Ast>),
}

impl Ast {
    fn inspect(&self, depth: usize) -> String {
        let indent = vec!["  "]
            .into_iter()
            .cycle()
            .take(depth)
            .collect::<Vec<&str>>()
            .join(" ");
        let mut formatted = String::new();
        match self {
            Ast::S(s) => {
                formatted.push_str(format!("{}", s).as_str());
            }
            Ast::A(ast_vec) => {
                formatted.push_str(format!("\n{}(", indent).as_str());
                for (i, ast) in ast_vec.into_iter().enumerate() {
                    formatted.push_str(ast.inspect(depth + 1).as_str());
                    if i != ast_vec.len() - 1 {
                        formatted.push_str(" ");
                    };
                }
                formatted.push_str(")");
            }
        };
        formatted
    }
}

impl fmt::Debug for Ast {
    fn fmt(&self, dest: &mut fmt::Formatter) -> fmt::Result {
        write!(dest, "{}", self.inspect(0))
    }
}

pub fn parse(raw_code: String) -> Ast {
    let raw_code_without_comment = Regex::new(r"[#;].*")
        .unwrap()
        .replace_all(raw_code.as_str(), "")
        .into_owned();
    let code = Regex::new(r"\s+")
        .unwrap()
        .replace_all(raw_code_without_comment.as_str(), " ");

    let regex = Regex::new(r#"\(|\)|[\w\d\-+=*%_@^~<>?$&|!]+|".+?""#).unwrap();
    let mut tokens = regex.find_iter(&code).map(|m| m.as_str().to_string());

    let mut parsed: Vec<Ast> = vec![Ast::S(tokens.next().unwrap())];
    let tokens_rest: Vec<String> = tokens.collect();

    for token in tokens_rest {
        let element = match token.as_str() {
            ")" => {
                let mut poped: Vec<Ast> = vec![Ast::S(")".to_string())];
                loop {
                    match [poped.first(), poped.last()] {
                        [Some(Ast::S(fst)), Some(Ast::S(lst))]
                            if fst.as_str() == "(" && lst.as_str() == ")" =>
                        {
                            break Ast::A(poped.drain(1..=poped.len() - 2).collect())
                        }
                        _ => {
                            poped.insert(0, parsed.pop().unwrap());
                        }
                    }
                }
            }
            _ => Ast::S(token),
        };
        parsed.push(element);
    }
    Ast::A(parsed)
}
