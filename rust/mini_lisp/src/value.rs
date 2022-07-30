#[derive(Debug, Clone)]
pub enum Value {
    Null,
    True,
    False,
    Num(usize),
    Symbol(String),
    Function(fn(Vec<Value>) -> Value),
}
