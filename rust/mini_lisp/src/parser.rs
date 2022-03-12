use regex::Regex;
use std::fmt;

#[derive(Clone)]
pub enum Ast {
    S(String),
    A(Vec<Ast>),
}

impl Ast {
    fn inspect(&self, depth: i32) {
        let mut indent = "".to_string();
        for _ in 0..depth {
            indent.push_str("  ");
        }
        match self {
            Ast::S(s) => {
                print!("{}", s);
            }
            Ast::A(pv) => {
                print!("\n{}(", indent);
                for (i, p) in pv.into_iter().enumerate() {
                    p.inspect(depth + 1);
                    if i != pv.len() - 1 {
                        print!(" ")
                    };
                }
                print!(")");
            }
        };
    }
}

impl fmt::Debug for Ast {
    fn fmt(&self, _f: &mut fmt::Formatter) -> fmt::Result {
        self.inspect(0);
        Ok(())
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

    let mut parsed: Vec<Ast> = vec![];
    parsed.push(Ast::S(tokens.next().unwrap()));
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
