use std::env;
use std::fs;
use regex::Regex;

#[derive(Debug, Clone)]
enum Parsed {
    S(String),
    P(Vec<Parsed>)
}

fn main() {
    let filename = env::args().nth(1).unwrap();
    let code = fs::read_to_string(&filename).unwrap();
    println!("{}", &code);

    let regex = Regex::new(r"\(|\)|[\w\d\-+=*%_@^~<>?$&|!]+").unwrap();
    let mut tokens = regex.find_iter(&code).map(|m| m.as_str().to_string());

    let mut parsed: Vec<Parsed> = vec![ Parsed::S(tokens.next().unwrap()) ];
    println!("{:?}", parsed);
    let tokens_rest: Vec<String> = tokens.collect();
    println!("{:?}\n\n", tokens_rest);

    for token in tokens_rest {
        println!("token:   {:?}", token);
        println!("parsed:  {:?}", parsed);
        let element = match token.as_str() {
            ")" => {
                let mut poped: Vec<Parsed> = vec![ Parsed::S(")".to_string()) ];
                loop {
                    match [poped.first(), poped.last()] {
                        [Some(Parsed::S(fst)), Some(Parsed::S(lst))] => {
                            if fst.as_str() == "(" && lst.as_str() == ")" {
                                break Parsed::P(poped.drain(1 ..= poped.len() - 2).collect())
                            } else {
                                poped.insert(0, parsed.pop().unwrap());
                            }
                        },
                        _ => { poped.insert(0, parsed.pop().unwrap()); }
                    }
                }
            },
            _ => Parsed::S(token)
        };
        println!("element: {:?}", element);
        println!("parsed:  {:?}\n", parsed);
        parsed.push(element);
    }
    println!("{:?}", parsed);
}
