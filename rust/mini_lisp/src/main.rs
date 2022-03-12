mod parser;
mod compiler;

use std::env;
use std::fs;

fn main() {
    let filename = env::args().nth(1).unwrap();
    let raw_code = fs::read_to_string(&filename).unwrap();
    println!("{}", &raw_code);
    let ast = if let parser::Ast::A(v) = parser::parse(raw_code) {
        let mut vc = v.clone();
        vc.insert(0, parser::Ast::S("~".to_string()));
        parser::Ast::A(vc)
    } else {
        parser::Ast::A(vec![])
    };
    println!("{:?}", ast);
    let (first_bytecode, ref mut rest_bytecodes) = compiler::compile(ast, vec![]);
    rest_bytecodes.push(first_bytecode);
    println!("{:#?}", rest_bytecodes);
}
