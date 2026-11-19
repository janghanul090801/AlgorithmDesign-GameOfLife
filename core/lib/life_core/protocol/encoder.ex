defmodule LifeCore.Protocol.Encoder do
  alias LifeCore.Job.CellJob
  alias LifeCore.Simulation.Board

  def encode_job(%CellJob{} = job) do
    %{
      type: "cell",
      id: job.id,
      generation: job.generation,
      x: job.x,
      y: job.y,
      current: job.current,
      board: Board.to_protocol(job.board)
    }
    |> Jason.encode!()
    |> then(&(&1 <> "\n"))
  end
end
