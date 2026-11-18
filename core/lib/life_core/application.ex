defmodule LifeCore.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {
        Registry,
        key: :unique,
        name: LifeCore.WorkerRegistry
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

    Supervisor.start_link(children, opts)
  end
end
