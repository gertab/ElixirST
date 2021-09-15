defmodule Examples.PingPong do
  use ElixirST
  @moduledoc false
  # Send ping pong indefinitely

  @session "ping = ?ping().!pong().ping"
  @spec ping(pid) :: no_return
  def ping(pid) do
    receive do
      {:ping} ->
        IO.puts(
          "Received ping from #{inspect(pid)}. Replying pong from #{inspect(self())} " <>
            "to #{inspect(pid)}"
        )

        send(pid, {:pong})
    end

    ping(pid)
  end

  @dual "ping"
  @spec pong(pid) :: no_return
  def pong(pid) do
    send(pid, {:ping})

    receive do
      {:pong} ->
        IO.puts("Received pong.")
    end

    pong(pid)
  end

  def main() do
    ElixirST.spawn(&ping/1, [], &pong/1, [])
  end
end
