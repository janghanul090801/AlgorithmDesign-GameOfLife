defmodule LifeCore.Simulation.Cell do
  @type t :: %__MODULE__{
               x: non_neg_integer(),
               y: non_neg_integer(),
               alive: boolean()
             }
  defstruct [
    :x,
    :y,
    :alive
  ]
end
