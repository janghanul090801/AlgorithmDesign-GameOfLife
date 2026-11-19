defmodule Mix.Tasks.Life.Tui do
  use Mix.Task

  @shortdoc "Watch the Game of Life simulation in the terminal"

  @moduledoc """
  Starts the simulation and renders it in the terminal.

      mix life.tui
      mix life.tui --pattern pulsar --delay 80
      mix life.tui --width 40 --height 20 --generations 50

  ## Options

    * `--pattern` - `glider`, `blinker`, `pulsar`, `r_pentomino`,
      `random`, or `empty`
    * `--width` / `--height` - board size (defaults to the terminal size)
    * `--delay` - milliseconds between generations (default 120)
    * `--refresh` - render interval in milliseconds (default 100)
    * `--generations` - stop after N generations (0 means run forever)
  """

  @patterns ~w(glider blinker pulsar r_pentomino random empty)

  @impl Mix.Task
  def run(args) do
    {opts, _rest, invalid} =
      OptionParser.parse(
        args,
        strict: [
          width: :integer,
          height: :integer,
          pattern: :string,
          delay: :integer,
          refresh: :integer,
          generations: :integer
        ]
      )

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    pattern =
      opts
      |> Keyword.get(:pattern, "glider")
      |> parse_pattern()

    Mix.Task.run("app.start")

    opts
    |> Keyword.put(:pattern, pattern)
    |> LifeCore.TUI.run()
  end

  defp parse_pattern(value) do
    if value in @patterns do
      String.to_atom(value)
    else
      Mix.raise(
        "Unknown pattern #{inspect(value)}. " <>
          "Use one of: #{Enum.join(@patterns, ", ")}"
      )
    end
  end
end
