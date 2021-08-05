defmodule Examples.PingPong do
  use STEx
  @moduledoc false

  def run() do
    # IO.puts("Spawning process")
    # pinger = spawn(__MODULE__, :ping, [])
    # _ponger = spawn(__MODULE__, :pong, [pinger])
    # IO.puts("Process spawned as #{inspect(pinger)}")
    STEx.spawn(&ping/1, [], &pong/1, [])
  end

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
end
