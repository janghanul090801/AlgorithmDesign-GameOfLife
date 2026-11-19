defmodule LifeCore.Simulation.Scheduler do
  use GenServer

  alias LifeCore.Simulation.Board
  alias LifeCore.Job.CellJob
  alias LifeCore.Job.JobQueue
  alias LifeCore.Worker.WorkerPool

  defstruct [
    :board,
    :generation,
    :delay,
    :queue,
    :results,
    :processed,
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

  def set_delay(delay) when is_integer(delay) and delay >= 0 do
    GenServer.call(
      __MODULE__,
      {:set_delay, delay}
    )
  end

  @impl true
  def init(_) do
    {:ok,
     %__MODULE__{
       board: nil,
       generation: 0,
       delay: 0,
       queue: JobQueue.new(),
       results: %{},
       processed: %{},
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
        processed: %{},
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
  def handle_call({:set_delay, delay}, _from, state) do
    {:reply, :ok, %{state | delay: delay}}
  end

  @impl true
  def handle_info(
        {:worker_ready, _worker_id, _pid},
        state
      ) do
    {:noreply, dispatch_jobs(state)}
  end

  def handle_info(
        {:worker_result, worker_id, language, result},
        state
      ) do
    results =
      Map.put(
        state.results,
        result["job_id"],
        result
      )

    processed =
      Map.update(
        state.processed,
        language,
        1,
        &(&1 + 1)
      )

    WorkerPool.worker_finished(worker_id)

    state = %{
      state
      | results: results,
        processed: processed
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
        {:worker_error, worker_id, _reason},
        state
      ) do
    WorkerPool.worker_finished(worker_id)

    {:noreply, dispatch_jobs(state)}
  end

  @impl true
  def handle_info(
        {:worker_exit, _worker_id, _status},
        state
      ) do
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
    next_board =
      build_next_board(
        state.board,
        state.results
      )

    schedule_next_generation(
      next_board,
      state.delay
    )

    %{
      state
      | board: next_board,
        generation: state.generation + 1,
        results: %{}
    }
  end

  defp schedule_next_generation(board, 0) do
    send(
      self(),
      {:start_next_generation, board}
    )
  end

  defp schedule_next_generation(board, delay) when delay > 0 do
    Process.send_after(
      self(),
      {:start_next_generation, board},
      delay
    )
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
