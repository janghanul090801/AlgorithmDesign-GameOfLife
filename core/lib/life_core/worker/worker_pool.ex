defmodule LifeCore.Worker.WorkerPool do
  use GenServer

  defstruct workers: %{}

  def start_link(_opts) do
    GenServer.start_link(
      __MODULE__,
      %__MODULE__{},
      name: __MODULE__
    )
  end

  def start_worker(opts) do
    GenServer.call(__MODULE__, {:start_worker, opts})
  end

  def assign_job(job) do
    GenServer.call(__MODULE__, {:assign_job, job})
  end

  def worker_finished(worker_id) do
    GenServer.cast(__MODULE__, {:worker_finished, worker_id})
  end

  def workers do
    GenServer.call(__MODULE__, :workers)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:start_worker, opts}, _from, state) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        LifeCore.WorkerSupervisor,
        {LifeCore.Worker, opts}
      )

    worker_id = Keyword.fetch!(opts, :id)
    language = Keyword.fetch!(opts, :language)
    ref = Process.monitor(pid)

    workers =
      Map.put(state.workers, worker_id, %{
        pid: pid,
        language: language,
        status: :idle,
        monitor: ref
      })

    {:reply, {:ok, pid}, %{state | workers: workers}}
  end

  @impl true
  def handle_call({:assign_job, job}, _from, state) do
    case find_idle_worker(state.workers) do
      {:ok, {worker_id, worker}} ->
        LifeCore.Worker.assign(worker.pid, job)

        state =
          put_in(
            state.workers[worker_id].status,
            :busy
          )

        {:reply, :ok, state}

      :none ->
        {:reply, :no_worker, state}
    end
  end

  @impl true
  def handle_call(:workers, _from, state) do
    {:reply, state.workers, state}
  end

  @impl true
  def handle_cast({:worker_finished, worker_id}, state) do
    workers =
      case Map.get(state.workers, worker_id) do
        nil ->
          state.workers

        worker ->
          Map.put(
            state.workers,
            worker_id,
            %{worker | status: :idle}
          )
      end

    {:noreply, %{state | workers: workers}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    workers =
      state.workers
      |> Enum.reject(fn {_worker_id, worker} ->
        worker.monitor == ref
      end)
      |> Map.new()

    {:noreply, %{state | workers: workers}}
  end

  defp find_idle_worker(workers) do
    Enum.find_value(workers, :none, fn {worker_id, worker} ->
      if worker.status == :idle do
        {:ok, {worker_id, worker}}
      end
    end)
  end
end
