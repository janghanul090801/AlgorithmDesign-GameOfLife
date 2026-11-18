defmodule LifeCore.Protocol.Decoder do
  def decode(line) when is_binary(line) do
    Jason.decode(line)
  end
end
