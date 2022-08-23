use super::value::Value;
use super::vm::{StackFrame, VM};
use regex::Regex;
use std::collections::HashMap;

fn initial_vm(instruction_sequence_table: &Vec<Vec<String>>) -> VM {
    let stack_frames = HashMap::from([(
        0,
        StackFrame {
            stack: vec![],
            env: vec![
                (
                    "+".to_string(),
                    Value::Function(|vs| match (&vs[0], &vs[1]) {
                        (Value::Num(n1), Value::Num(n2)) => Value::Num(n1 + n2),
                        _ => panic!(),
                    }),
                ),
                (
                    "-".to_string(),
                    Value::Function(|vs| match (&vs[0], &vs[1]) {
                        (Value::Num(n1), Value::Num(n2)) => Value::Num(n1 - n2),
                        _ => panic!(),
                    }),
                ),
                (
                    "==".to_string(),
                    Value::Function(|vs| match (&vs[0], &vs[1]) {
                        (Value::Num(n1), Value::Num(n2)) => {
                            if n1 == n2 {
                                Value::True
                            } else {
                                Value::False
                            }
                        }
                        _ => panic!(),
                    }),
                ),
                (
                    "and".to_string(), // FIXME: 即時評価しない
                    Value::Function(|vs| {
                        if vs
                            .iter()
                            .all(|v| if let Value::True = v { true } else { false })
                        {
                            Value::True
                        } else {
                            Value::False
                        }
                    }),
                ),
                (
                    "or".to_string(), // FIXME: 即時評価しない
                    Value::Function(|vs| {
                        if vs
                            .iter()
                            .any(|v| if let Value::True = v { true } else { false })
                        {
                            Value::True
                        } else {
                            Value::False
                        }
                    }),
                ),
                (
                    "p".to_string(), // FIXME: 即時評価しない
                    Value::Function(|vs| {
                        println!("{:?}", vs[0].clone());
                        vs[0].clone()
                    }),
                ),
            ]
            .into_iter()
            .collect(),
            pc: 0,
            call_parent_num: None,
            env_parent_num: None,
            instruction_sequence_table_num: instruction_sequence_table.len() - 1,
        },
    )]);

    VM {
        stack_frame_num: 0,
        stack_frames,
    }
}

pub fn run(instruction_sequence_table: Vec<Vec<String>>) {
    let mut vm = initial_vm(&instruction_sequence_table);

    // dbg!(&vm);
    loop {
        let instruction_sequence =
            &instruction_sequence_table[vm.current_stack_frame().instruction_sequence_table_num];

        if &vm.current_stack_frame().pc == &instruction_sequence.len() {
            match &vm.current_stack_frame().call_parent_num {
                Some(n) => {
                    let return_value = vm.current_stack_frame_stack_last();
                    vm.stack_frame_num = *n;
                    vm = vm.current_stack_frame_stack_push(return_value);
                    continue;
                }
                None => {
                    // dbg!(&vm);
                    break;
                }
            };
        };

        let instruction = &instruction_sequence[vm.current_stack_frame().pc];

        // dbg!(instruction_sequence);
        // dbg!(instruction);

        vm = if instruction == "nil" {
            vm.current_stack_frame_stack_push(Value::Null)
                .current_stack_frame_pc_add(1)
        } else if instruction == "true" {
            vm.current_stack_frame_stack_push(Value::True)
                .current_stack_frame_pc_add(1)
        } else if instruction == "false" {
            vm.current_stack_frame_stack_push(Value::False)
                .current_stack_frame_pc_add(1)
        } else if let Some(cap) = r(r"^int@(-?\d+)").captures(instruction) {
            let value = Value::Num(cap[1].parse().unwrap());
            vm.current_stack_frame_stack_push(value)
                .current_stack_frame_pc_add(1)
        } else if let Some(cap) = r(r"^get@(.+)").captures(instruction) {
            let name = &cap[1].to_string();
            let value = vm.get_env(name);
            vm.current_stack_frame_stack_push(value)
                .current_stack_frame_pc_add(1)
        } else if let Some(cap) = r(r"^send@(\d+)").captures(instruction) {
            let argc: usize = cap[1].parse().unwrap();
            let (vm, operator) = vm.current_stack_frame_stack_pop();
            let (mut vm, args) = (0..argc).fold((vm, vec![]), |(vm, args), _i| {
                let (vm, arg) = vm.current_stack_frame_stack_pop();
                (vm, [args, vec![arg]].concat())
            });
            match operator {
                Value::Function(f) => {
                    let calced = f(args);
                    vm.current_stack_frame_stack_push(calced)
                        .current_stack_frame_pc_add(1)
                }
                Value::Closure {
                    instruction_sequence_table_num,
                    args: closure_args,
                    stack_frame_num,
                } => {
                    if args.len() != closure_args.len() {
                        panic!("arguments size is not equal");
                    }
                    let env = closure_args.into_iter().zip(args.into_iter()).collect();

                    let new_stack_frame_num = vm.stack_frames.len();
                    vm.stack_frames.insert(
                        new_stack_frame_num,
                        StackFrame {
                            stack: vec![],
                            env,
                            pc: 0,
                            call_parent_num: Some(vm.stack_frame_num),
                            env_parent_num: Some(stack_frame_num),
                            instruction_sequence_table_num,
                        },
                    );
                    vm = vm.current_stack_frame_pc_add(1);
                    vm.stack_frame_num = new_stack_frame_num;
                    vm
                }
                _ => panic!(),
            }
        } else if let Some(cap) = r(r"^set@(.+)").captures(instruction) {
            let name = &cap[1].to_string();
            let value = vm.current_stack_frame_stack_last();
            vm.update_env(name, &value).current_stack_frame_pc_add(1)
        } else if let Some(_cap) = r(r"^symbol@(.+)").captures(instruction) {
            todo!();
        } else if let Some(cap) = r(r"^jump@(-?\d+)").captures(instruction) {
            let n: usize = cap[1].to_string().parse().unwrap();
            vm.current_stack_frame_pc_add(n + 1)
        } else if let Some(cap) = r(r"^jumpif@(-?\d+)").captures(instruction) {
            let n: usize = cap[1].to_string().parse().unwrap();
            let value = vm.current_stack_frame_stack_last();
            match value {
                Value::True => vm.current_stack_frame_pc_add(n + 1),
                _ => vm.current_stack_frame_pc_add(1),
            }
        } else if let Some(cap) = r(r"^closure@(\d+)@(.*)").captures(instruction) {
            let instruction_sequence_table_num: usize = cap[1].to_string().parse().unwrap();
            let args: Vec<String> = cap[2]
                .to_string()
                .split(",")
                .map(|s| s.to_string())
                .filter(|s| s.as_str() != "")
                .collect();
            let closure = Value::Closure {
                instruction_sequence_table_num,
                args,
                stack_frame_num: vm.stack_frame_num,
            };
            vm.current_stack_frame_stack_push(closure)
                .current_stack_frame_pc_add(1)
        } else {
            panic!();
        };

        // dbg!(&vm);
    }
}
fn r(s: &str) -> Regex {
    Regex::new(s).unwrap()
}
