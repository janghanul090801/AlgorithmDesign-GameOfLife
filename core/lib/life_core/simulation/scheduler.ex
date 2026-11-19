defmodule LifeCore.Simulation.Scheduler do
  use GenServer

  alias LifeCore.Simulation.Board
  alias LifeCore.Job.CellJob
  alias LifeCore.Job.JobQueue
  alias LifeCore.Worker.WorkerPool

  defstruct [
    :board,
    :generation,
    :queue,
    :results,
    :next_job_id
  ]

  def start_link(_opts) do
    GenServer.start_link(
      __MODULE__,
      [],
      name: __MODULE__
    )
  end

  def start_generation(board) do
    GenServer.call(
      __MODULE__,
      {:start_generation, board}
    )
  end

  def state do
    GenServer.call(
      __MODULE__,
      :state
    )
  end

  @impl true
  def init(_) do
    {:ok,
     %__MODULE__{
       board: nil,
       generation: 0,
       queue: JobQueue.new(),
       results: %{},
       next_job_id: 0
     }}
  end

  @impl true
  def handle_call(
        {:start_generation, board},
        _from,
        state
      ) do
    {queue, next_job_id} =
      create_jobs(
        board,
        state.generation,
        state.next_job_id
      )

    new_state = %{
      state
      | board: board,
        queue: queue,
        results: %{},
        next_job_id: next_job_id
    }

    new_state =
      dispatch_jobs(new_state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(
        {:worker_ready, _worker_id, _pid},
        state
      ) do
    {:noreply, dispatch_jobs(state)}
  end

  def handle_info(
      {:worker_result, worker_id, result},
      state
    ) do
    results =
      Map.put(
        state.results,
        result["job_id"],
        result
      )

    WorkerPool.worker_finished(worker_id)

    state = %{
      state
      | results: results
    }

    state = dispatch_jobs(state)

    if generation_complete?(state) do
      {:noreply, finish_generation(state)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(
        {:worker_error, worker_id, reason},
        state
      ) do
    IO.inspect(
      reason,
      label: "Worker #{worker_id} error"
    )

    WorkerPool.worker_finished(worker_id)

    {:noreply, dispatch_jobs(state)}
  end

  @impl true
  def handle_info(
        {:worker_exit, worker_id, status},
        state
      ) do
    IO.puts(
      "Worker #{worker_id} exited with status #{status}"
    )

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:start_next_generation, board},
        state
      ) do
    {queue, next_job_id} =
      create_jobs(
        board,
        state.generation,
        state.next_job_id
      )

    new_state = %{
      state
      | board: board,
        queue: queue,
        results: %{},
        next_job_id: next_job_id
    }

    {:noreply, dispatch_jobs(new_state)}
  end

  defp create_jobs(
         board,
         generation,
         next_job_id
       ) do
    cells = Board.all_cells(board)

    Enum.reduce(
      cells,
      {JobQueue.new(), next_job_id},
      fn cell, {queue, id} ->
        job = %CellJob{
          id: id,
          generation: generation,
          x: cell.x,
          y: cell.y,
          current: cell.alive,
          board: board
        }

        {
          JobQueue.push(queue, job),
          id + 1
        }
      end
    )
  end

  defp dispatch_jobs(state) do
    case JobQueue.pop(state.queue) do
      :empty ->
        state

      {:ok, job, queue} ->
        case WorkerPool.assign_job(job) do
          :ok ->
            dispatch_jobs(%{
              state
              | queue: queue
            })

          :no_worker ->
            state
        end
    end
  end

  defp generation_complete?(state) do
    JobQueue.empty?(state.queue) and
      map_size(state.results) ==
        state.board.width * state.board.height
  end

  defp finish_generation(state) do
    IO.puts(
      "Generation #{state.generation} completed"
    )

    next_board =
      build_next_board(
        state.board,
        state.results
      )

    IO.puts(
      "Starting generation #{state.generation + 1}"
    )

    send(
      self(),
      {:start_next_generation, next_board}
    )

    %{
      state
      | board: next_board,
        generation: state.generation + 1,
        results: %{}
    }
  end

  defp build_next_board(
         board,
         results
       ) do
    Enum.reduce(
      results,
      Board.new(
        board.width,
        board.height
      ),
      fn {_job_id, result}, new_board ->
        Board.set_alive(
          new_board,
          result["x"],
          result["y"],
          result["alive"]
        )
      end
    )
  end
end
