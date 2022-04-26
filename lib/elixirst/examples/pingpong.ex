defmodule Examples.PingPong do
  use ElixirST
  @moduledoc false
  # Send ping pong indefinitely

  @session "X = !ping().?pong().X"
  @spec pinger(pid) :: no_return
  def pinger(pid) do
    send(pid, {:ping})

    receive do
      {:pong} -> IO.puts("Received pong.")
    end

    pinger(pid)
  end

  @dual "X"
  @spec ponger(pid) :: no_return
  def ponger(pid) do
    receive do
      {:ping} ->
        IO.puts(
          "Received ping from #{inspect(pid)}. Replying pong from #{inspect(self())} " <>
            "to #{inspect(pid)}"
        )
    end
    send(pid, {:pong})

    ponger(pid)
  end

  def main() do
    ElixirST.spawn(&pinger/1, [], &ponger/1, [])
  end
end
