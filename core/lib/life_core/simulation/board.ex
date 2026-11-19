defmodule LifeCore.Simulation.Board do
  alias LifeCore.Simulation.Cell

  defstruct [
    :width,
    :height,
    :cells
  ]

  @type t :: %__MODULE__{
    width: pos_integer(),
    height: pos_integer(),
    cells: %{optional({non_neg_integer(), non_neg_integer()}) => boolean()}
  }

  def new(width, height) do
    cells =
      for x <- 0..(width-1),
          y <- 0..(height-1),
          into: %{} do
            {{x,y}, false}
      end

      %__MODULE__{
          width: width,
          height: height,
          cells: cells
      }
  end

  def set_alive(board, x, y, alive \\ true) do
    if valid_position?(board,x,y) do
      %{board | cells: Map.put(board.cells, {x,y}, alive)}
    else
      board
    end
  end

  def alive?(board, x, y) do
    Map.get(board.cells, {x,y}, false)
  end

  def cell(board, x, y) do
    %Cell{
      x: x,
      y: y,
      alive: alive?(board,x,y)
    }
  end

  def all_cells(board) do
    for x <- 0..(board.width-1),
        y <- 0..(board.height-1) do
      cell(board, x, y)
    end
  end

  def valid_position?(board, x, y) do
    x >= 0 and x < board.width and y >= 0 and y < board.height
  end

  def to_protocol(board) do
    cells =
      for y <- 0..(board.height - 1) do
        for x <- 0..(board.width - 1) do
          alive?(board, x, y)
        end
      end

    %{
      width: board.width,
      height: board.height,
      cells: cells
    }
  end
end
