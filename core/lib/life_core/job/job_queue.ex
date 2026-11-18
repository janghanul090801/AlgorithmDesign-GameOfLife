defmodule LifeCore.Job.JobQueue do
  alias LifeCore.Job.CellJob

  defstruct [
    :queue
  ]

  def new do
    %__MODULE__{
      queue: :queue.new()
    }
  end

  def push(%__MODULE__{} = queue, %CellJob{} = job) do
    %{queue | queue: :queue.in(job, queue.queue)}
  end

  def push_many(%__MODULE__{} = queue, jobs) do
    Enum.reduce(jobs, queue, &push(&2, &1))
  end

  def pop(%__MODULE__{} = queue) do
    case :queue.out(queue.queue) do
      {{:value, job}, new_queue} ->
        {:ok, job, %{queue | queue: new_queue}}
      {:empty, _queue} ->
        :empty
    end
  end

  def empty?(%__MODULE__{} = queue) do
    :queue.is_empty(queue.queue)
  end

  def size(%__MODULE__{} = queue) do
    :queue.size(queue.queue)
  end
end
