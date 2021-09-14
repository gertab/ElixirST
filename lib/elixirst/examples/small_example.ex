defmodule Examples.SmallExample do
  use STEx
  @moduledoc false

  @session "server = ?Hello()"
  @spec server(pid) :: atom
  def server(_pid) do
    receive do
      {:Hello} -> :ok
    end
  end

  @dual "server"
  @spec client(pid) :: {atom}
  def client(pid) do
    send(pid, {:Hello})
  end
end

# explicitly: `mix sessions Examples.SmallExample`
