defmodule ElixirSessions.PingPong do
  use ElixirSessions.Checking
  @moduledoc """
  Sample module which uses concurrency and session types.
  Ping pong:
  Send 'ping' and receive 'pong'.

  To run:
  `ElixirSessions.PingPong.run()`
  """

  @doc """
  Entry point for PingPong.
  """
  def run() do
    IO.puts("Spawning process")
    ponger = spawn(__MODULE__, :pong, [])
    IO.puts("Process spawned as #{inspect ponger}")

    ping(ponger)
  end

  @doc """
  Sends `:pong` when a `:ping` is received.
  """
  @session "send '{:ping, pid}' . receive '{:pong}'"
  def ping(pid) when is_pid(pid) do
    IO.puts("Sending ping to #{inspect pid}")

    send(pid, {:ping, self()})

    receive do
      {:pong} ->
        IO.puts("Received pong!")
    end

    ping(pid)
  end

  @doc """
  Receives a `:ping` and sends a `:pong`.
  """
  # @session "receive '{:ping, pid}' . send '{:pong}'"
  def pong() do
    receive do
      {:ping, pid} ->
        IO.puts("Received ping from #{inspect pid}. Replying pong from #{inspect self()} to #{inspect pid}")
        send(pid, {:pong})
    end
  end
end
