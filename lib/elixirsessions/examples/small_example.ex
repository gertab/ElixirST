defmodule Examples.SmallExample do
  use ElixirSessions
  @moduledoc false

  @session "server = ?Hello(binary)"
  @spec server(pid) :: :ok
  def server(_pid) do
    receive do
      {:Hello, _h} ->
        :ok
    end
  end

  @dual "server"
  @spec client(pid) :: atom()
  def client(pid) do
    kkk = "hello"
    send(pid, {:Hello, kkk})

    :ok
  end
end

# explicitly: `mix session_check Examples.SmallExample`
