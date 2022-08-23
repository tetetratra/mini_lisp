#[derive(Debug, Clone)]
pub enum Value {
    Null,
    True,
    False,
    Num(i32),
    Symbol(String),
    String(String),
    Function(fn(Vec<Value>) -> Value),
    Closure {
        instruction_sequence_table_num: usize,
        args: Vec<String>,
        stack_frame_num: usize,
    },
}
