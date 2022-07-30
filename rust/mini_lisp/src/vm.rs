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
                                stack_frame
                                    .stack
                                    .clone()
                                    .drain(0..=stack_frame.stack.len() - 2)
                                    .collect()
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

    dbg!(&vm);
    loop {
        let instruction_sequence = &code_table[vm.current_stack_frame().code_table_num];
        if vm.current_stack_frame().line_num == instruction_sequence.len() {
            break;
        }
        let instruction = &instruction_sequence[vm.current_stack_frame().line_num];
        dbg!(instruction);
        let code_str = instruction.as_str();

        vm = if instruction == "nil" {
            vm.current_stack_frame_stack_push(&Value::Null)
                .current_stack_frame_line_num_add(1)
        } else if instruction == "true" {
            vm.current_stack_frame_stack_push(&Value::True)
                .current_stack_frame_line_num_add(1)
        } else if instruction == "false" {
            vm.current_stack_frame_stack_push(&Value::False)
                .current_stack_frame_line_num_add(1)
        } else if let Some(cap) = r(r"^int@(-?\d+)").captures(instruction) {
            let value = &Value::Num(cap[1].parse().unwrap());
            vm.current_stack_frame_stack_push(value)
                .current_stack_frame_line_num_add(1)
        } else if let Some(cap) = r(r"^get@(.+)").captures(instruction) {
            let name = &cap[1].to_string();
            let value = vm.current_stack_frame().env.get(name).unwrap();
            vm.current_stack_frame_stack_push(value)
                .current_stack_frame_line_num_add(1)
        } else if let Some(cap) = r(r"^send@(\d+)").captures(instruction) {
            let argc: usize = cap[1].parse().unwrap();
            let (vm, operator) = vm.current_stack_frame_stack_pop();
            let (vm, args) = (0..argc).fold((vm, vec![]), |(vm, args), _i| {
                let (vm, arg) = vm.current_stack_frame_stack_pop();
                (vm, [args, vec![arg]].concat())
            });
            let calced = &match operator {
                Value::Function(f) => f(args),
                _ => panic!(),
            };
            vm.current_stack_frame_stack_push(calced)
                .current_stack_frame_line_num_add(1)
        } else if let Some(cap) = r(r"^set@(.+)").captures(instruction) {
            todo!();
        } else if let Some(cap) = r(r"^symbol@(.+)").captures(instruction) {
            todo!();
        } else if let Some(cap) = r(r"^jumpif@(-?\d+)").captures(instruction) {
            todo!();
        } else if let Some(cap) = r(r"^jump@(-?\d+)").captures(instruction) {
            todo!();
        } else {
            panic!();
        };
        dbg!(&vm);
    }
}
