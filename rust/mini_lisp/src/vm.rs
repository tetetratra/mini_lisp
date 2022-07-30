use regex::Regex;
use std::collections::HashMap;

#[derive(Debug, Clone)]
struct VM {
    stack_frame_num: usize,
    stack_frames: HashMap<usize, StackFrame>,
}

impl VM {
    fn current_stack_frame(&self) -> &StackFrame {
        &self.stack_frames[&self.stack_frame_num]
    }
    fn current_stack_frame_line_num_add(&self, len: usize) -> VM {
        VM {
            stack_frame_num: self.stack_frame_num,
            stack_frames: self
                .stack_frames
                .clone()
                .into_iter()
                .map(|(n, stack_frame)| {
                    let new_stack_frame = if n == self.stack_frame_num {
                        StackFrame {
                            line_num: stack_frame.line_num + len,
                            ..stack_frame
                        }
                    } else {
                        stack_frame
                    };
                    (n, new_stack_frame)
                })
                .collect(),
        }
    }
    fn current_stack_frame_stack_push(&self, value: &Value) -> VM {
        VM {
            stack_frame_num: self.stack_frame_num,
            stack_frames: self
                .stack_frames
                .clone()
                .into_iter()
                .map(|(n, stack_frame)| {
                    let new_stack_frame = if n == self.stack_frame_num {
                        StackFrame {
                            stack: vec![stack_frame.stack, vec![value.clone()]].concat(),
                            ..stack_frame
                        }
                    } else {
                        stack_frame
                    };
                    (n, new_stack_frame)
                })
                .collect(),
        }
    }
    fn current_stack_frame_stack_pop(&self) -> (VM, Value) {
        let value = self.current_stack_frame().stack.last().unwrap().clone();

        let next_vm = VM {
            stack_frame_num: self.stack_frame_num,
            stack_frames: self
                .stack_frames
                .clone()
                .into_iter()
                .map(|(n, stack_frame)| {
                    let new_stack_frame = if n == self.stack_frame_num {
                        StackFrame {
                            stack: if stack_frame.stack.len() > 1 {
                                 stack_frame.stack.clone().drain(0..=stack_frame.stack.len() - 2).collect()
                            } else {
                                vec![]
                            },
                            ..stack_frame
                        }
                    } else {
                        stack_frame
                    };
                    (n, new_stack_frame)
                })
                .collect(),
        };
        (next_vm, value)
    }
}

#[derive(Debug, Clone)]
struct StackFrame {
    stack: Vec<Value>,
    env: HashMap<String, Value>,
    line_num: usize,
    call_parent_num: Option<usize>,
    env_parent_num: Option<usize>,
    code_table_num: usize,
}

#[derive(Debug, Clone)]
enum Value {
    Null,
    True,
    False,
    Num(usize),
    Symbol(String),
    Function(fn(Vec<Value>) -> Value),
}

fn r(s: &str) -> Regex {
    Regex::new(s).unwrap()
}

pub fn exec(code_table: Vec<Vec<String>>) {
    let stack_frames = HashMap::from([(
        0,
        StackFrame {
            stack: vec![],
            env: vec![
                ("one".to_string(), Value::Num(1)),
                (
                    "+".to_string(),
                    Value::Function(|vs| match (&vs[0], &vs[1]) {
                        (Value::Num(n1), Value::Num(n2)) => Value::Num(n1 + n2),
                        _ => panic!(),
                    }),
                ),
            ]
            .into_iter()
            .collect(),
            line_num: 0,
            call_parent_num: None,
            env_parent_num: None,
            code_table_num: code_table.len() - 1,
        },
    )]);

    let mut vm = VM {
        stack_frame_num: 0,
        stack_frames,
    };

    dbg!(vm.clone());
    loop {
        let instruction_sequence = &code_table[vm.current_stack_frame().code_table_num];
        if vm.current_stack_frame().line_num == instruction_sequence.len() {
            break;
        }
        let instruction = &instruction_sequence[vm.current_stack_frame().line_num];
        dbg!(instruction);
        let code_str = instruction.as_str();

        vm = match code_str {
            "nil" => vm
                .current_stack_frame_stack_push(&Value::Null)
                .current_stack_frame_line_num_add(1),
            "true" => vm
                .current_stack_frame_stack_push(&Value::True)
                .current_stack_frame_line_num_add(1),
            "false" => vm
                .current_stack_frame_stack_push(&Value::False)
                .current_stack_frame_line_num_add(1),
            _ if r(r"^int@(-?\d+)").is_match(code_str) => {
                let value = Value::Num(
                    r(r"^int@(-?\d+)").captures(code_str).unwrap()[1]
                        .parse()
                        .unwrap(),
                );
                vm.current_stack_frame_stack_push(&value)
                    .current_stack_frame_line_num_add(1)
            }
            _ if r(r"^get@(.+)").is_match(code_str) => {
                let op = r(r"^get@(.+)").captures(code_str).unwrap()[1].to_string();
                let value = vm.current_stack_frame().env.get(&op).unwrap();
                vm.current_stack_frame_stack_push(&value)
                    .current_stack_frame_line_num_add(1)
            }
            _ if r(r"^send@(\d+)").is_match(code_str) => {
                let argc: usize = r(r"^send@(\d+)").captures(code_str).unwrap()[1]
                    .to_string()
                    .parse()
                    .unwrap();
                let (next_vm, op) = vm.current_stack_frame_stack_pop();
                let (next_vm, args) = (0..argc).fold((next_vm, vec![]), |(vm, args), _i| {
                    let (next_vm, arg) = vm.current_stack_frame_stack_pop();
                    (next_vm, [args, vec![arg]].concat())
                });
                let calced = match op {
                    Value::Function(f) => f(args),
                    _ => panic!(),
                };
                next_vm
                    .current_stack_frame_stack_push(&calced)
                    .current_stack_frame_line_num_add(1)
            }
            _ if r(r"^set@(.+)").is_match(code_str) => vm,
            _ if r(r"^symbol@(.+)").is_match(code_str) => vm,
            _ if r(r"^jumpif@(-?\d+)").is_match(code_str) => vm,
            _ if r(r"^jump@(-?\d+)").is_match(code_str) => vm,
            _ => {
                panic!()
            }
        };
        dbg!(vm.clone());
    }
}
