mod parser;

use std::env;
use std::fs;

fn main() {
    let filename = env::args().nth(1).unwrap();
    let raw_code = fs::read_to_string(&filename).unwrap();
    println!("{}", &raw_code);
    parser::parse(raw_code);
}
