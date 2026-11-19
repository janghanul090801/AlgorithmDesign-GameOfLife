defmodule LifeCore.Worker.PortWorker do
  use GenServer

  alias LifeCore.Protocol.Encoder
  alias LifeCore.Protocol.Decoder

  defstruct [
    :id,
    :port,
    :worker
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def send_job(pid, job) do
    GenServer.cast(pid, {:send_job, job})
  end

  @impl true
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    executable = Keyword.fetch!(opts, :executable)
    worker = Keyword.fetch!(opts, :worker)

    port =
      Port.open(
        {:spawn_executable, executable},
        [
          :binary,
          :exit_status,
          {:line, 1_048_576}
        ]
      )

    {:ok,
     %__MODULE__{
       id: id,
       port: port,
       worker: worker
     }}
  end

  @impl true
  def handle_cast({:send_job, job}, state) do
    data = Encoder.encode_job(job)

    Port.command(state.port, data)

    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:data, {:eol, data}}}, %{port: port} = state) do
    case Decoder.decode(data) do
      {:ok, result} ->
        send(
          state.worker,
          {:worker_result, state.id, result}
        )

      {:error, reason} ->
        send(
          state.worker,
          {:worker_error, state.id, reason}
        )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    send(
      state.worker,
      {:worker_exit, state.id, status}
    )

    {:stop, :normal, state}
  end
end
