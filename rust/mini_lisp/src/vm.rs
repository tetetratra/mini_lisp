use super::value::Value;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct VM {
    pub stack_frame_num: usize,
    pub stack_frames: HashMap<usize, StackFrame>,
}

impl VM {
    pub fn current_stack_frame(&self) -> &StackFrame {
        &self.stack_frames[&self.stack_frame_num]
    }
    pub fn current_stack_frame_pc_add(&self, len: usize) -> VM {
        VM {
            stack_frame_num: self.stack_frame_num,
            stack_frames: self
                .stack_frames
                .clone()
                .into_iter()
                .map(|(n, stack_frame)| {
                    let new_stack_frame = if n == self.stack_frame_num {
                        StackFrame {
                            pc: stack_frame.pc + len,
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
    pub fn current_stack_frame_stack_push(&self, value: &Value) -> VM {
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
    pub fn current_stack_frame_stack_last(&self) -> Value {
        self.current_stack_frame().stack.last().unwrap().clone()
    }
    pub fn current_stack_frame_stack_pop(&self) -> (VM, Value) {
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
    pub fn update_env(&self, name: &String, value: &Value) -> VM {
        let mut num = &self.stack_frame_num;
        num = loop {
            if let Some(_) = &self.stack_frames[num].env.get(name) {
                break num;
            } else if let Some(env_parent_num) = &self.stack_frames[num].env_parent_num {
                num = env_parent_num;
            } else {
                break &self.stack_frame_num;
            }
        };
        VM {
            stack_frame_num: self.stack_frame_num,
            stack_frames: self
                .stack_frames
                .clone()
                .into_iter()
                .map(|(n, stack_frame)| {
                    let new_stack_frame = if &n == num {
                        let mut env = stack_frame.env.clone();
                        env.insert(name.clone(), value.clone());
                        StackFrame { env, ..stack_frame }
                    } else {
                        stack_frame
                    };
                    (n, new_stack_frame)
                })
                .collect(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct StackFrame {
    pub stack: Vec<Value>,
    pub env: HashMap<String, Value>,
    pub pc: usize,
    pub call_parent_num: Option<usize>,
    pub env_parent_num: Option<usize>,
    pub instruction_sequence_table_num: usize,
}
