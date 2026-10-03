use std::collections::VecDeque;
use std::sync::{Condvar, Mutex};
use std::thread;
use std::time::Duration;

const SIZE: usize = 3;

struct Buffer {
    queue: Mutex<VecDeque<u32>>,
    not_full: Condvar,
    not_empty: Condvar,
}

impl Buffer {
    fn put(&self, who: u32, item: u32) {
        let queue = self.queue.lock().unwrap();
        let mut queue = self.not_full.wait_while(queue, |q| q.len() == SIZE).unwrap();
        queue.push_back(item);
        println!("Производитель {who} положил {item}   [в буфере {} из {SIZE}]", queue.len());
        self.not_empty.notify_one();
    }

    fn get(&self, who: u32) -> Option<u32> {
        let queue = self.queue.lock().unwrap();
        let (mut queue, _) = self
            .not_empty
            .wait_timeout_while(queue, Duration::from_secs(1), |q| q.is_empty())
            .unwrap();
        let item = queue.pop_front()?;
        println!("    Потребитель {who} взял {item}   [в буфере {} из {SIZE}]", queue.len());
        self.not_full.notify_one();
        Some(item)
    }
}

fn main() {
    let buffer = &Buffer {
        queue: Mutex::new(VecDeque::new()),
        not_full: Condvar::new(),
        not_empty: Condvar::new(),
    };
    thread::scope(|s| {
        for id in 1..=3 {
            s.spawn(move || {
                for i in 1..=5 {
                    thread::sleep(Duration::from_millis(100) * id);
                    buffer.put(id, id * 100 + i);
                }
            });
        }
        for id in 1..=2 {
            s.spawn(move || {
                while buffer.get(id).is_some() {
                    thread::sleep(Duration::from_millis(400));
                }
                println!("    Потребитель {id} больше не ждёт");
            });
        }
    });
}
