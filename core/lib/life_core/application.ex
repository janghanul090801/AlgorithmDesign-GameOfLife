defmodule LifeCore.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      %{
        id: LifeCore.WorkerRegistry,
        start:
          {Registry, :start_link,
           [
             [
               keys: :unique,
               name: LifeCore.WorkerRegistry
             ]
           ]}
      },

      {
        DynamicSupervisor,
        strategy: :one_for_one,
        name: LifeCore.WorkerSupervisor
      },

      LifeCore.Worker.WorkerPool,
      LifeCore.Simulation.Scheduler
    ]

    opts = [
      strategy: :one_for_one,
      name: LifeCore.Supervisor
    ]

    {:ok, pid} = Supervisor.start_link(children, opts)

    register_workers()

    {:ok, pid}
  end

  defp register_workers do
    workers = Application.get_env(:life_core, :workers, [])

    Enum.each(workers, &start_worker/1)
  end

  defp start_worker(worker) do
    command = Map.fetch!(worker, :command)
    cd = resolve_cd(Map.get(worker, :cd, "."))
    {program, args} = resolve_command(command, cd)

    {:ok, _pid} =
      LifeCore.Worker.WorkerPool.start_worker(
        id: worker.id,
        language: worker.language,
        program: program,
        args: args,
        cd: cd,
        env: Map.get(worker, :env, %{}),
        scheduler: LifeCore.Simulation.Scheduler
      )
  end

  defp resolve_command([program | args], cd) when is_binary(program) do
    unless Enum.all?(args, &is_binary/1) do
      raise ArgumentError,
            "worker command arguments must be strings, got: #{inspect(args)}"
    end

    {resolve_program(program, cd), args}
  end

  defp resolve_command(command, _cd) do
    raise ArgumentError,
          "worker command must be a non-empty list of strings, got: #{inspect(command)}"
  end

  defp resolve_program(program, cd) do
    cond do
      Path.type(program) == :absolute ->
        program

      String.contains?(program, ["/", "\\"]) ->
        Path.expand(program, cd)

      true ->
        System.find_executable(program) ||
          raise "could not find executable #{inspect(program)} in PATH"
    end
  end

  defp resolve_cd(cd) do
    path = Path.expand(cd)

    unless File.dir?(path) do
      raise "worker working directory does not exist: #{path}"
    end

    path
  end
end
