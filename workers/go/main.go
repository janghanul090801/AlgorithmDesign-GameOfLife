package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
)

type CellJob struct {
	JobType    string `json:"type"`
	ID         uint64 `json:"id"`
	Generation uint64 `json:"generation"`
	X          int    `json:"x"`
	Y          int    `json:"y"`
	Current    bool   `json:"current"`
	Board      Board  `json:"board"`
}

type Board struct {
	Width  int      `json:"width"`
	Height int      `json:"height"`
	Cells  [][]bool `json:"cells"`
}

type CellResult struct {
	ResultType string `json:"type"`
	JobID      uint64 `json:"job_id"`
	Generation uint64 `json:"generation"`
	X          int    `json:"x"`
	Y          int    `json:"y"`
	Alive      bool   `json:"alive"`
}

func countNeighbors(board *Board, x, y int) int {
	count := 0

	for dy := -1; dy <= 1; dy++ {
		for dx := -1; dx <= 1; dx++ {
			if dx == 0 && dy == 0 {
				continue
			}

			nx := x + dx
			ny := y + dy

			if nx < 0 ||
				ny < 0 ||
				nx >= board.Width ||
				ny >= board.Height {
				continue
			}

			if board.Cells[ny][nx] {
				count++
			}
		}
	}

	return count
}

func calculate(current bool, neighbors int) bool {
	if current && (neighbors == 2 || neighbors == 3) {
		return true
	}

	if !current && neighbors == 3 {
		return true
	}

	return false
}

func main() {
	scanner := bufio.NewScanner(os.Stdin)
	writer := bufio.NewWriter(os.Stdout)
	defer writer.Flush()

	for scanner.Scan() {
		line := scanner.Text()

		if len(line) == 0 {
			continue
		}

		var job CellJob

		if err := json.Unmarshal([]byte(line), &job); err != nil {
			fmt.Fprintf(os.Stderr, "failed to decode job: %v\n", err)
			continue
		}

		if job.JobType != "cell" {
			continue
		}

		neighborCount := countNeighbors(
			&job.Board,
			job.X,
			job.Y,
		)

		alive := calculate(
			job.Current,
			neighborCount,
		)

		result := CellResult{
			ResultType: "result",
			JobID:      job.ID,
			Generation: job.Generation,
			X:          job.X,
			Y:          job.Y,
			Alive:      alive,
		}

		data, err := json.Marshal(result)
		if err != nil {
			continue
		}

		fmt.Fprintln(writer, string(data))
		writer.Flush()
	}
}
