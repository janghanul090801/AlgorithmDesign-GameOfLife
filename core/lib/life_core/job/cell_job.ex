defmodule LifeCore.Job.CellJob do
  alias LifeCore.Simulation.Board

  @type t :: %__MODULE__{
    id: integer(),
    generation: non_neg_integer(),
    x: non_neg_integer(),
    y: non_neg_integer(),
    current: boolean(),
    board: Board.t()
  }

  defstruct [
    :id,
    :generation,
    :x,
    :y,
    :current
  ]
end
