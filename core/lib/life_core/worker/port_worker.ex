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
    program = Keyword.fetch!(opts, :program)
    args = Keyword.get(opts, :args, [])
    cd = Keyword.get(opts, :cd)
    env = Keyword.get(opts, :env, %{})
    worker = Keyword.fetch!(opts, :worker)

    port_opts =
      [:binary, :exit_status, {:line, 1_048_576}, {:args, args}] ++
        cd_option(cd) ++ env_option(env)

    port = Port.open({:spawn_executable, program}, port_opts)

    {:ok,
     %__MODULE__{
       id: id,
       port: port,
       worker: worker
     }}
  end

  defp cd_option(nil), do: []

  defp cd_option(cd) when is_binary(cd) do
    [{:cd, cd}]
  end

  defp env_option(env) when map_size(env) == 0, do: []

  defp env_option(env) do
    pairs =
      Enum.map(env, fn {key, value} ->
        {to_charlist(key), to_charlist(value)}
      end)

    [{:env, pairs}]
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
