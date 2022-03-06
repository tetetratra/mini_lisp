use regex::Regex;
use std::env;
use std::fs;

#[derive(Debug)]
enum Parsed {
    S(String),
    P(Vec<Parsed>),
}

fn main() {
    let filename = env::args().nth(1).unwrap();
    let raw_code = fs::read_to_string(&filename).unwrap();
    println!("{}", &raw_code);
    let raw_code2 = Regex::new(r"[#;].*")
        .unwrap()
        .replace_all(raw_code.as_str(), "");
    let owned = raw_code2.into_owned();
    let code = Regex::new(r"\s+").unwrap().replace_all(owned.as_str(), " ");

    let regex = Regex::new(r"\(|\)|[\w\d\-+=*%_@^~<>?$&|!]+").unwrap();
    let mut tokens = regex.find_iter(&code).map(|m| m.as_str().to_string());

    let mut parsed: Vec<Parsed> = vec![];
    parsed.push(Parsed::S(tokens.next().unwrap()));
    let tokens_rest: Vec<String> = tokens.collect();

    for token in tokens_rest {
        let element = match token.as_str() {
            ")" => {
                let mut poped: Vec<Parsed> = vec![Parsed::S(")".to_string())];
                loop {
                    match [poped.first(), poped.last()] {
                        [Some(Parsed::S(fst)), Some(Parsed::S(lst))]
                            if fst.as_str() == "(" && lst.as_str() == ")" =>
                        {
                            break Parsed::P(poped.drain(1..=poped.len() - 2).collect())
                        }
                        _ => {
                            poped.insert(0, parsed.pop().unwrap());
                        }
                    }
                }
            }
            _ => Parsed::S(token),
        };
        parsed.push(element);
    }
    println!("{:?}", parsed);
}
