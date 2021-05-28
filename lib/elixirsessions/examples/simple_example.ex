defmodule ElixirSessions.SimpleExample do
  use ElixirSessions

  # iex -S mix
  # recompile && ElixirSessions.SimpleExample.run

  def run() do
    ST.spawn(&server/2, [0], &client/1, [])
  end

  @session "rec X.(&{?num(number).X, ?result().!total(number)})"
  @spec server(pid(), number()) :: :ok
  def server(pid, acc) do
    IO.puts("Server")

    receive do
      {:num, value} ->
        server(pid, acc + value)

      {:result} ->
        send(pid, {:total, acc})
        :ok
    end
  end

  @dual &ElixirSessions.SimpleExample.server/2
  @spec client(pid()) :: atom()
  def client(pid) do
    IO.puts("Client")
    send(pid, {:num, 2})
    send(pid, {:num, 5})
    send(pid, {:num, 3})
    send(pid, {:result})

    total =
      receive do
        {:total, value} ->
          value
      end

    IO.puts("Total value = " <> inspect(total))
  end
end
