defmodule SmallExample do
  @moduledoc false
  use ElixirSessions

  @session "server = ?Hello()"
  @spec server(pid) :: :ok
  def server(_pid) do
    receive do
      {:Hello} ->
        :ok
    end
  end

  @dual "server"
  @spec client(pid) :: {atom()}
  def client(pid) do
    send(pid, {:Hello})
  end
end

# explicitly: `mix session_check SmallExample`
