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

    Enum.each(workers, fn worker ->
      {:ok, _pid} =
        LifeCore.Worker.WorkerPool.start_worker(
          id: worker.id,
          language: worker.language,
          executable: worker.executable,
          scheduler: LifeCore.Simulation.Scheduler
        )
    end)
  end
end
