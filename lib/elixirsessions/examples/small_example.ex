defmodule SmallExample do
  @moduledoc false
  use ElixirSessions

  @session "!Hello()"
  @spec client(pid) :: {atom()}
  def client(pid) do
    send(pid, {:Hello})
  end

  @dual &SmallExample.client/1
  @spec server() :: :ok
  def server() do
    receive do
      {:Hello} ->
        :ok
    end
  end
end
# explicitly: `mix session_check SmallExample`
