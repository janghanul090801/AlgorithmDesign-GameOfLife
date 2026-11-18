defmodule LifeCore.Protocol.Encoder do
  alias LifeCore.Job.CellJob

  def encode_job(%CellJob{} = job) do
    %{
      type: "call",
      id: job.id,
      generation: job.generation,
      x: job.x,
      y: job.y,
      current: job.current,
      board: job.board
    }
    |> Jason.encode!()
    |> Kernal.<>("\n")
  end
end
