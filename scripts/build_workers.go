package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

type Worker struct {
	ID       string            `json:"id"`
	Language string            `json:"language"`
	Build    []string          `json:"build"`
	Command  []string          `json:"command"`
	Env      map[string]string `json:"env"`
}

type Config struct {
	ID       string
	Language string
	Command  []string
	CD       string
	Env      map[string]string
}

func main() {
	root, err := findRepoRoot()
	if err != nil {
		log.Fatal(err)
	}

	workerPath := filepath.Join(root, "workers")

	entries, err := os.ReadDir(workerPath)
	if err != nil {
		log.Fatal(err)
	}

	var configs []Config

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		workerDir := filepath.Join(workerPath, entry.Name())
		manifestPath := filepath.Join(workerDir, "worker.json")

		if _, err := os.Stat(manifestPath); err != nil {
			fmt.Printf("[%s] worker.json not found, skipping\n", entry.Name())
			continue
		}

		manifest, err := readManifest(manifestPath)
		if err != nil {
			log.Fatalf("[%s] %v", entry.Name(), err)
		}

		id := manifest.ID
		if id == "" {
			id = entry.Name()
		}

		language := manifest.Language
		if language == "" {
			language = entry.Name()
		}

		if len(manifest.Command) == 0 {
			log.Fatalf("[%s] command must not be empty", entry.Name())
		}

		if err := buildWorker(entry.Name(), workerDir, manifest.Build); err != nil {
			log.Fatal(err)
		}

		command, err := normalizeCommand(entry.Name(), workerDir, manifest.Command)
		if err != nil {
			log.Fatal(err)
		}

		configs = append(configs, Config{
			ID:       id,
			Language: language,
			Command:  command,
			CD:       filepath.ToSlash(filepath.Join("..", "workers", entry.Name())),
			Env:      manifest.Env,
		})

		fmt.Printf("[%s] Build complete\n\n", entry.Name())
	}

	configPath := filepath.Join(root, "core", "config", "workers.generated.exs")

	if err := generateConfig(configPath, configs); err != nil {
		log.Fatal(err)
	}

	fmt.Println("All workers built successfully.")
}

func findRepoRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}

	for {
		workersOK := isDir(filepath.Join(dir, "workers"))
		coreOK := isDir(filepath.Join(dir, "core", "config"))

		if workersOK && coreOK {
			return dir, nil
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			return "", errors.New("could not find repository root (expected workers/ and core/config/)")
		}

		dir = parent
	}
}

func isDir(path string) bool {
	info, err := os.Stat(path)

	return err == nil && info.IsDir()
}

func readManifest(path string) (Worker, error) {
	var manifest Worker

	data, err := os.ReadFile(path)
	if err != nil {
		return manifest, err
	}

	if err := json.Unmarshal(data, &manifest); err != nil {
		return manifest, fmt.Errorf("invalid worker.json: %w", err)
	}

	return manifest, nil
}

func buildWorker(name, workerDir string, build []string) error {
	if len(build) == 0 {
		return nil
	}

	cmd := exec.Command(build[0], build[1:]...)
	cmd.Dir = workerDir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("[%s] build failed: %w", name, err)
	}

	return nil
}

func normalizeCommand(name, workerDir string, command []string) ([]string, error) {
	program := command[0]

	if program == "" {
		return nil, fmt.Errorf("[%s] command program is empty", name)
	}

	if isLocalPath(program) {
		path := filepath.Join(workerDir, filepath.FromSlash(program))

		if _, err := os.Stat(path); errors.Is(err, fs.ErrNotExist) {
			return nil, fmt.Errorf("[%s] %s does not exist", name, path)
		} else if err != nil {
			return nil, err
		}

		command = append([]string(nil), command...)
		command[0] = filepath.ToSlash(program)
	}

	return command, nil
}

func isLocalPath(program string) bool {
	return strings.HasPrefix(program, ".") ||
		strings.ContainsAny(program, `/\`)
}

func generateConfig(configPath string, configs []Config) error {
	var builder strings.Builder

	builder.WriteString("import Config\n\n")
	builder.WriteString("config :life_core,\n")
	builder.WriteString("  workers: [\n")

	for i, worker := range configs {
		builder.WriteString("    %{\n")
		builder.WriteString(fmt.Sprintf("      id: %q,\n", worker.ID))
		builder.WriteString(fmt.Sprintf("      language: :%s,\n", worker.Language))
		builder.WriteString(fmt.Sprintf("      command: %s,\n", formatList(worker.Command)))
		builder.WriteString(fmt.Sprintf("      cd: %q", worker.CD))

		if len(worker.Env) > 0 {
			builder.WriteString(",\n")
			builder.WriteString(fmt.Sprintf("      env: %s", formatEnv(worker.Env)))
		}

		builder.WriteString("\n    }")

		if i != len(configs)-1 {
			builder.WriteString(",")
		}

		builder.WriteString("\n")
	}

	builder.WriteString("  ]\n")

	if err := os.WriteFile(configPath, []byte(builder.String()), 0644); err != nil {
		return err
	}

	fmt.Printf("Generated config: %s\n", configPath)

	return nil
}

func formatList(values []string) string {
	quoted := make([]string, len(values))

	for i, value := range values {
		quoted[i] = fmt.Sprintf("%q", value)
	}

	return "[" + strings.Join(quoted, ", ") + "]"
}

func formatEnv(env map[string]string) string {
	keys := make([]string, 0, len(env))

	for key := range env {
		keys = append(keys, key)
	}

	sort.Strings(keys)

	pairs := make([]string, len(keys))

	for i, key := range keys {
		pairs[i] = fmt.Sprintf("%q => %q", key, env[key])
	}

	return "%{" + strings.Join(pairs, ", ") + "}"
}
