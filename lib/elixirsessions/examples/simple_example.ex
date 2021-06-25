defmodule Examples.SimpleExample do
  use ElixirSessions

  # Acts as an adder/counter

  # iex -S mix
  # recompile && Examples.SimpleExample.run

  def run() do
    ST.spawn(&server/2, [0], &client/1, [])
  end

  @session "counter = &{?num(number).counter, ?result().!total(number)}"
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

  @dual "counter"
  @spec client(pid()) :: atom()
  def client(pid) do
    IO.puts("Client")
    send(pid, {:num, 2})
    send(pid, {:num, 5})
    send(pid, {:num, 3})
    send(pid, {:result})

    receive do
      {:total, value} ->
        IO.puts("Total value = " <> inspect(value))
        :ok
    end
  end
end
