package main

import (
	"errors"
	"fmt"
	"io/fs"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type Worker struct {
	ID         string
	Language   string
	Executable string
}

func main() {
	workerPath := "./workers"

	workers, err := os.ReadDir(workerPath)
	if err != nil {
		log.Fatal(err)
	}

	var configs []Worker

	for _, w := range workers {
		if !w.IsDir() {
			continue
		}

		workerDirPath := filepath.Join(workerPath, w.Name())
		workerfilePath := filepath.Join(workerDirPath, "Workerfile")

		if _, err := os.Stat(workerfilePath); err != nil {
			fmt.Println(workerfilePath, "is not exists")
			continue
		}

		data, err := os.ReadFile(workerfilePath)
		if err != nil {
			log.Fatal(err)
		}

		lines := strings.Split(strings.ReplaceAll(string(data), "\r\n", "\n"), "\n")

		if len(lines) < 2 {
			log.Fatal(workerfilePath + " must contain at least 2 lines")
		}

		buildCmd := strings.Fields(strings.TrimSpace(lines[0]))
		executable := strings.TrimSpace(lines[1])

		if len(buildCmd) == 0 {
			log.Fatal(workerfilePath + " build command is empty")
		}

		if executable == "" {
			log.Fatal(workerfilePath + " executable path is empty")
		}

		cmd := exec.Command(buildCmd[0], buildCmd[1:]...)
		cmd.Dir = workerDirPath
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr

		err = cmd.Run()
		if err != nil {
			log.Fatalf("[%s] build failed: %v", w.Name(), err)
		}

		executablePath := filepath.Join(workerDirPath, executable)

		if _, err := os.Stat(executablePath); errors.Is(err, fs.ErrNotExist) {
			log.Fatalf("[%s] %s is not exist", w.Name(), executablePath)
		} else if err != nil {
			log.Fatal(err)
		}

		executableForCore := filepath.Join(
			"..",
			"workers",
			w.Name(),
			executable,
		)

		executableForCore = filepath.ToSlash(executableForCore)

		configs = append(configs, Worker{
			ID:         w.Name(),
			Language:   w.Name(),
			Executable: executableForCore,
		})

		fmt.Printf("[%s] Build complete\n\n", w.Name())
	}

	if err := generateConfig(configs); err != nil {
		log.Fatal(err)
	}

	fmt.Println("All workers built successfully.")
}

func generateConfig(workers []Worker) error {
	configPath := "./core/config/workers.generated.exs"

	var builder strings.Builder

	builder.WriteString("import Config\n\n")
	builder.WriteString("config :life_core,\n")
	builder.WriteString("  workers: [\n")

	for i, worker := range workers {
		builder.WriteString("    %{\n")
		builder.WriteString(fmt.Sprintf("      id: %q,\n", worker.ID))
		builder.WriteString(fmt.Sprintf("      language: :%s,\n", worker.Language))
		builder.WriteString(fmt.Sprintf("      executable: %q\n", worker.Executable))
		builder.WriteString("    }")

		if i != len(workers)-1 {
			builder.WriteString(",")
		}

		builder.WriteString("\n")
	}

	builder.WriteString("  ]\n")

	if err := os.WriteFile(
		configPath,
		[]byte(builder.String()),
		0644,
	); err != nil {
		return err
	}

	fmt.Printf("Generated config: %s\n", configPath)

	return nil
}
