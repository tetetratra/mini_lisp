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

    dbg!(&vm);
    loop {
        let instruction_sequence = &instruction_sequence_table[vm.current_stack_frame().instruction_sequence_table_num];
        if vm.current_stack_frame().pc == instruction_sequence.len() {
            break;
        }
        let instruction = &instruction_sequence[vm.current_stack_frame().pc];
        dbg!(instruction);

        vm = if instruction == "nil" {
            vm.current_stack_frame_stack_push(&Value::Null)
                .current_stack_frame_pc_add(1)
        } else if instruction == "true" {
            vm.current_stack_frame_stack_push(&Value::True)
                .current_stack_frame_pc_add(1)
        } else if instruction == "false" {
            vm.current_stack_frame_stack_push(&Value::False)
                .current_stack_frame_pc_add(1)
        } else if let Some(cap) = r(r"^int@(-?\d+)").captures(instruction) {
            let value = &Value::Num(cap[1].parse().unwrap());
            vm.current_stack_frame_stack_push(value)
                .current_stack_frame_pc_add(1)
        } else if let Some(cap) = r(r"^get@(.+)").captures(instruction) {
            let name = &cap[1].to_string();
            let value = vm.current_stack_frame().env.get(name).unwrap();
            vm.current_stack_frame_stack_push(value)
                .current_stack_frame_pc_add(1)
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
                .current_stack_frame_pc_add(1)
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
fn r(s: &str) -> Regex {
    Regex::new(s).unwrap()
}
