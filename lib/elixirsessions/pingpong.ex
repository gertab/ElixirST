defmodule ElixirSessions.PingPong do
  use ElixirSessions.Checking
  @moduledoc """
  Ping pong:
  Send 'ping' and receive 'pong'.

  ElixirSessions.PingPong.run()
  """

  def run() do
    IO.puts("Spawning process")
    ponger = spawn(__MODULE__, :pong, [])
    IO.puts("Process spawned as #{inspect ponger}")

    ping(ponger)
  end

  @session "send {:ping, pid} . receive {:pong}"
  def ping(pid) when is_pid(pid) do
    IO.puts("Sending ping to #{inspect pid}")
    send(pid, {:ping, self()})

    receive do
      {:pong} ->
        IO.puts("Received pong!")
    end
  end

  @session "receive {:ping, pid} . send {:pong}"
  def pong() do
    receive do
      {:ping, pid} ->
        IO.puts("Received ping from #{inspect pid}. Replying pong from #{inspect self()} to #{inspect pid}")
        send(pid, {:pong})
    end
  end
end
