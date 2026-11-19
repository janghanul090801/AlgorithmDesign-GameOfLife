# Core

Elixir orchestration for the Game of Life simulation.

## TUI

Run the terminal UI from `core`:

```bash
mix life.tui
```

Options:

| Option | Description | Default |
| --- | --- | --- |
| `--pattern` | `glider`, `blinker`, `pulsar`, `r_pentomino`, `random`, `empty` | `glider` |
| `--width` / `--height` | board size | terminal size |
| `--delay` | milliseconds between generations | `120` |
| `--refresh` | render interval in milliseconds | `100` |
| `--generations` | stop after N generations (`0` = forever) | `0` |

Examples:

```bash
mix life.tui --pattern pulsar --delay 80
mix life.tui --width 40 --height 18 --generations 100
```

## Workers

Each worker lives in `workers/<id>/` and is described by a `worker.json`
manifest:

```json
{
  "build": ["go", "build", "-o", "go.exe", "."],
  "command": ["./go.exe"]
}
```

- `build` is optional. When present it is executed in the worker directory.
- `command` is the argv list used to spawn the worker. The first element is
  either a local path (`./go.exe`, resolved against `cd`) or a program name
  looked up in `PATH` (`python`, `node`, `java`).
- `env` is an optional object of environment variables.
- `id` and `language` default to the directory name.

Interpreter workers can rely on `cd` being set to their own directory:

```json
{
  "command": ["python", "-u", "main.py"],
  "env": { "PYTHONUNBUFFERED": "1" }
}
```

Regenerate `config/workers.generated.exs` after adding or changing a worker:

```bash
go run ./scripts/build_workers.go
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `core` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:core, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/core>.

