defmodule LifeCore.Worker do
  use GenServer

  defstruct [
    :id,
    :language,
    :pid,
    :scheduler
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def assign(pid, job) do
    GenServer.cast(pid, {:assign, job})
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  @impl true
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    language = Keyword.fetch!(opts, :language)
    executable = Keyword.fetch!(opts, :executable)
    scheduler = Keyword.fetch!(opts, :scheduler)

    {:ok, port_worker} = LifeCore.Worker.PortWorker.start_link(
      id: id,
      executable: executable,
      worker: self()
    )

    state = %__MODULE__{
      id: id,
      language: language,
      pid: port_worker,
      scheduler: scheduler
    }

    send(scheduler, {
      :worker_ready,
      id,
      self()
    })

    {:ok, state}
  end

  @impl true
  def handle_cast({:assign, job}, state) do
    LifeCore.Worker.PortWorker.send_job(state.pid, job)

    {:noreply, state}
  end

  @impl true
  def handle_info({:worker_result, worker_id, result}, state) do
    send(
      state.scheduler,
      {:worker_result, worker_id, result}
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:worker_error, worker_id, reason}, state) do
    send(
      state.scheduler,
      {:worker_error, worker_id, reason}
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:worker_exit, worker_id, status}, state) do
    send(
      state.scheduler,
      {:worker_exit, worker_id, status}
    )

    {:stop, :normal, state}
  end
end
