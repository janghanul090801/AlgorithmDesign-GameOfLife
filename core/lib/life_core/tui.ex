defmodule LifeCore.TUI do

  alias LifeCore.Job.JobQueue
  alias LifeCore.Simulation.Board
  alias LifeCore.Simulation.Scheduler
  alias LifeCore.Worker.WorkerPool

  @refresh_interval 100

  @pulsar [
    {2, 0},
    {3, 0},
    {4, 0},
    {8, 0},
    {9, 0},
    {10, 0},
    {0, 2},
    {5, 2},
    {7, 2},
    {12, 2},
    {0, 3},
    {5, 3},
    {7, 3},
    {12, 3},
    {0, 4},
    {5, 4},
    {7, 4},
    {12, 4},
    {2, 5},
    {3, 5},
    {4, 5},
    {8, 5},
    {9, 5},
    {10, 5},
    {2, 7},
    {3, 7},
    {4, 7},
    {8, 7},
    {9, 7},
    {10, 7},
    {0, 8},
    {5, 8},
    {7, 8},
    {12, 8},
    {0, 9},
    {5, 9},
    {7, 9},
    {12, 9},
    {0, 10},
    {5, 10},
    {7, 10},
    {12, 10},
    {2, 12},
    {3, 12},
    {4, 12},
    {8, 12},
    {9, 12},
    {10, 12}
  ]

  def run(opts \\ []) do
    settings =
      %{
        width: Keyword.get(opts, :width) || default_width(),
        height: Keyword.get(opts, :height) || default_height(),
        pattern: Keyword.get(opts, :pattern, :glider),
        delay: Keyword.get(opts, :delay, 120),
        refresh: Keyword.get(opts, :refresh, @refresh_interval),
        generations: Keyword.get(opts, :generations, 0)
      }
      |> normalize_settings()

    board =
      initial_board(
        settings.pattern,
        settings.width,
        settings.height
      )

    :ok = Scheduler.set_delay(settings.delay)
    :ok = Scheduler.start_generation(board)

    try do
      render_loop(settings)
    after
      IO.write([IO.ANSI.reset(), "\n"])
    end
  end

  def initial_board(pattern, width, height) do
    board = Board.new(width, height)

    seed(
      board,
      pattern,
      div(width, 2),
      div(height, 2)
    )
  end

  defp normalize_settings(settings) do
    %{
      settings
      | width: max(settings.width, 3),
        height: max(settings.height, 3),
        delay: max(settings.delay, 0),
        refresh: max(settings.refresh, 10),
        generations: max(settings.generations, 0)
    }
  end

  defp render_loop(settings) do
    state = Scheduler.state()
    workers = WorkerPool.workers()

    IO.write([
      IO.ANSI.home(),
      IO.ANSI.clear(),
      build_frame(state, workers, settings)
    ])

    cond do
      not scheduler_alive?() ->
        :ok

      settings.generations > 0 and
          state.generation >= settings.generations ->
        :ok

      true ->
        Process.sleep(settings.refresh)
        render_loop(settings)
    end
  end

  defp scheduler_alive? do
    case Process.whereis(Scheduler) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  defp build_frame(%{board: nil}, _workers, settings) do
    [
      title(),
      "",
      "  Waiting for the simulation to start...",
      "  Pattern: #{settings.pattern}   Size: #{settings.width}x#{settings.height}"
    ]
    |> Enum.join("\n")
  end

  defp build_frame(state, workers, settings) do
    board = state.board
    total = board.width * board.height

    lines =
      [
        title(),
        "",
        "  Generation #{state.generation}" <>
          "   Alive #{alive_count(board)}" <>
          "   Done #{map_size(state.results)}/#{total}" <>
          "   Queue #{JobQueue.size(state.queue)}",
        "  Workers #{workers_text(workers)}" <>
          "   Pattern #{settings.pattern}" <>
          "   Delay #{settings.delay}ms",
        "  Processed #{processed_text(state.processed, workers)}" <>
          "   Total #{format_count(total_processed(state.processed))}",
        "",
        board_top(board.width)
      ] ++
        board_rows(board) ++
        [
          board_bottom(board.width),
          "",
          footer(settings)
        ]

    Enum.join(lines, "\n")
  end

  defp title do
    IO.ANSI.bright() <>
      IO.ANSI.cyan() <>
      " LIFE CORE " <>
      IO.ANSI.reset() <>
      IO.ANSI.faint() <>
      "Game of Life" <>
      IO.ANSI.reset()
  end

  defp board_top(width) do
    "  +" <>
      String.duplicate("-", width * 2) <>
      "+"
  end

  defp board_bottom(width) do
    "  +" <>
      String.duplicate("-", width * 2) <>
      "+"
  end

  defp board_rows(board) do
    Enum.map(0..(board.height - 1), fn y ->
      cells =
        0..(board.width - 1)
        |> Enum.map(fn x ->
          if Board.alive?(board, x, y) do
            cell_alive()
          else
            cell_dead()
          end
        end)
        |> Enum.join()

      "  |" <> cells <> "|"
    end)
  end

  defp cell_alive do
    IO.ANSI.bright() <>
      IO.ANSI.green_background() <>
      "  " <>
      IO.ANSI.reset()
  end

  defp cell_dead do
    IO.ANSI.faint() <>
      ".." <>
      IO.ANSI.reset()
  end

  defp alive_count(board) do
    Enum.count(
      board.cells,
      fn {_position, alive} -> alive end
    )
  end

  defp workers_text(workers) do
    if map_size(workers) == 0 do
      "none"
    else
      workers
      |> Enum.sort_by(fn {worker_id, _worker} ->
        worker_id
      end)
      |> Enum.map_join("  ", fn {worker_id, worker} ->
        color =
          if worker.status == :idle do
            IO.ANSI.green()
          else
            IO.ANSI.yellow()
          end

        "#{worker_id}:#{color}#{worker.status}#{IO.ANSI.reset()}"
      end)
    end
  end

  defp processed_text(processed, workers) do
    languages =
      workers
      |> Enum.map(fn {_worker_id, worker} ->
        worker.language
      end)
      |> Enum.concat(Map.keys(processed))
      |> Enum.uniq()
      |> Enum.sort()

    if languages == [] do
      "none"
    else
      Enum.map_join(languages, "  ", fn language ->
        count = Map.get(processed, language, 0)
        "#{language}:#{format_count(count)}"
      end)
    end
  end

  defp total_processed(processed) do
    processed
    |> Map.values()
    |> Enum.sum()
  end

  defp format_count(count) when count < 1_000 do
    Integer.to_string(count)
  end

  defp format_count(count) do
    count
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp footer(settings) do
    limit =
      if settings.generations > 0 do
        "   Stops after #{settings.generations} generations"
      else
        ""
      end

    "  Ctrl+C to stop" <> limit
  end

  defp seed(board, :blinker, cx, cy) do
    place(
      board,
      [{-1, 0}, {0, 0}, {1, 0}],
      cx,
      cy
    )
  end

  defp seed(board, :glider, cx, cy) do
    place(
      board,
      [{0, 0}, {1, 1}, {2, 0}, {2, 1}, {2, 2}],
      cx - 1,
      cy - 1
    )
  end

  defp seed(board, :r_pentomino, cx, cy) do
    place(
      board,
      [{1, 0}, {2, 0}, {0, 1}, {1, 1}, {1, 2}],
      cx - 1,
      cy - 1
    )
  end

  defp seed(board, :pulsar, cx, cy) do
    place(board, @pulsar, cx - 6, cy - 6)
  end

  defp seed(board, :random, _cx, _cy) do
    Enum.reduce(
      Board.all_cells(board),
      board,
      fn cell, acc ->
        if :rand.uniform() < 0.28 do
          Board.set_alive(acc, cell.x, cell.y)
        else
          acc
        end
      end
    )
  end

  defp seed(board, :empty, _cx, _cy) do
    board
  end

  defp seed(board, _pattern, cx, cy) do
    seed(board, :glider, cx, cy)
  end

  defp place(board, offsets, cx, cy) do
    Enum.reduce(offsets, board, fn {dx, dy}, acc ->
      Board.set_alive(
        acc,
        cx + dx,
        cy + dy
      )
    end)
  end

  defp default_width do
    {columns, _rows} = terminal_size()
    available = columns - 6

    available
    |> div(2)
    |> max(10)
    |> min(60)
  end

  defp default_height do
    {_columns, rows} = terminal_size()
    available = rows - 11

    available
    |> max(8)
    |> min(40)
  end

  defp terminal_size do
    columns =
      case :io.columns() do
        {:ok, value} when is_integer(value) and value > 0 ->
          value

        _ ->
          80
      end

    rows =
      case :io.rows() do
        {:ok, value} when is_integer(value) and value > 0 ->
          value

        _ ->
          24
      end

    {columns, rows}
  end
end
