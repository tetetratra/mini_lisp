mod compiler;
mod parser;

use std::env;
use std::fs;

fn main() {
    let filename = env::args().nth(1).unwrap();
    let raw_code = fs::read_to_string(&filename).unwrap();
    let code = format!("(~\n{})", raw_code);
    println!("{}", code);
    let ast = parser::parse(code);
    println!("{:?}", ast);
    let bytecodes = compiler::compile(ast);
    println!("{:#?}", bytecodes);
}
