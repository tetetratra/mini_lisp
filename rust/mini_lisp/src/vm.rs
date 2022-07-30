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
    fn current_stack_frame_line_num_add(&self, n: usize) -> VM {
        VM {
            stack_frame_num: self.stack_frame_num,
            stack_frames: self
                .stack_frames
                .clone()
                .into_iter()
                .map(|(sf_num, sf)| {
                    let new_sf = if sf_num == self.stack_frame_num {
                        StackFrame {
                            line_num: sf.line_num + n,
                            ..sf
                        }
                    } else {
                        sf
                    };
                    (sf_num, new_sf)
                })
                .collect(),
        }
    }
    fn current_stack_frame_stack_push(&self, value: Value) -> VM {
        VM {
            stack_frame_num: self.stack_frame_num,
            stack_frames: self
                .stack_frames
                .clone()
                .into_iter()
                .map(|(sf_num, sf)| {
                    let new_sf = if sf_num == self.stack_frame_num {
                        StackFrame {
                            stack: vec![sf.stack, vec![value.clone()]].concat(),
                            ..sf
                        }
                    } else {
                        sf
                    };
                    (sf_num, new_sf)
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
                .map(|(sf_num, mut sf)| {
                    let new_sf = if sf_num == self.stack_frame_num {
                        StackFrame {
                            stack: if sf.stack.len() > 1 {
                                sf.stack.drain(0..=sf.stack.len() - 2).collect()
                            } else {
                                vec![]
                            },
                            ..sf
                        }
                    } else {
                        sf
                    };
                    (sf_num, new_sf)
                })
                .collect(),
        };
        (next_vm, value)
    }
}

#[derive(Debug, Clone)]
struct StackFrame {
    stack: Vec<Value>, // TODO: String を MiniLisp::Value のようにする
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

pub fn exec(code_table: Vec<Vec<String>>) -> String {
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
        let current_stack_frame = vm.current_stack_frame();
        if current_stack_frame.line_num == code_table[current_stack_frame.code_table_num].len() {
            break "finish!".to_string();
        }
        let code = code_table[current_stack_frame.code_table_num].clone()
            [current_stack_frame.line_num]
            .clone();
        let code_str = code.as_str();
        dbg!(code.clone());

        vm = match code_str {
            "nil" => vm
                .current_stack_frame_stack_push(Value::Null)
                .current_stack_frame_line_num_add(1),
            "true" => vm
                .current_stack_frame_stack_push(Value::True)
                .current_stack_frame_line_num_add(1),
            "false" => vm
                .current_stack_frame_stack_push(Value::False)
                .current_stack_frame_line_num_add(1),
            _ if r(r"^int@(-?\d+)").is_match(code_str) => {
                let value = Value::Num(
                    r(r"^int@(-?\d+)").captures(code_str).unwrap()[1]
                        .parse()
                        .unwrap(),
                );
                vm.current_stack_frame_stack_push(value)
                    .current_stack_frame_line_num_add(1)
            }
            _ if r(r"^get@(.+)").is_match(code_str) => {
                let op = r(r"^get@(.+)").captures(code_str).unwrap()[1].to_string();
                let value = vm.current_stack_frame().env.get(&op).unwrap();
                vm.current_stack_frame_stack_push(value.clone())
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
                    .current_stack_frame_stack_push(calced)
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
