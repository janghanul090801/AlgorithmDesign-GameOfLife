defmodule LifeCore.Worker do
  use GenServer

  defstruct [
    :id,
    :language,
    :pid,
    :status
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
      scheduler: scheduler
    )

    state = %__MODULE__{
      id: id,
      language: language,
      pid: port_worker,
      status: :idle
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

    {:noreply, %{state | status: :busy}}
  end
end
