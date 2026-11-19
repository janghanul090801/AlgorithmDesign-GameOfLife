use serde::{Deserialize, Serialize};
use std::io::{self, BufRead, Write};

#[derive(Debug, Deserialize)]
struct CellJob {
    #[serde(rename = "type")]
    job_type: String,

    id: u64,
    generation: u64,
    x: usize,
    y: usize,
    current: bool,

    board: Board,
}

#[derive(Debug, Deserialize)]
struct Board {
    width: usize,
    height: usize,
    cells: Vec<Vec<bool>>,
}

#[derive(Debug, Serialize)]
struct CellResult {
    #[serde(rename = "type")]
    result_type: &'static str,

    job_id: u64,
    generation: u64,
    x: usize,
    y: usize,
    alive: bool,
}

fn count_neighbors(board: &Board, x: usize, y: usize) -> usize {
    let mut count = 0;

    for dy in -1i32..=1 {
        for dx in -1i32..=1 {
            if dx == 0 && dy == 0 {
                continue;
            }

            let nx = x as i32 + dx;
            let ny = y as i32 + dy;

            if nx < 0
                || ny < 0
                || nx >= board.width as i32
                || ny >= board.height as i32
            {
                continue;
            }

            if board.cells[ny as usize][nx as usize] {
                count += 1;
            }
        }
    }

    count
}

fn calculate(current: bool, neighbors: usize) -> bool {
    match (current, neighbors) {
        (true, 2 | 3) => true,
        (false, 3) => true,
        _ => false,
    }
}

fn main() {
    let stdin = io::stdin();
    let mut stdout = io::BufWriter::new(io::stdout());

    for line in stdin.lock().lines() {
        let line = match line {
            Ok(line) => line,
            Err(_) => break,
        };

        if line.trim().is_empty() {
            continue;
        }

        let job: CellJob = match serde_json::from_str(&line) {
            Ok(job) => job,
            Err(error) => {
                eprintln!("failed to decode job: {error}");
                continue;
            }
        };

        if job.job_type != "cell" {
            continue;
        }

        let neighbor_count =
            count_neighbors(&job.board, job.x, job.y);

        let alive =
            calculate(job.current, neighbor_count);

        let result = CellResult {
            result_type: "result",
            job_id: job.id,
            generation: job.generation,
            x: job.x,
            y: job.y,
            alive,
        };

        let json = serde_json::to_string(&result)
            .unwrap();

        writeln!(stdout, "{json}").unwrap();
        stdout.flush().unwrap();
    }
}