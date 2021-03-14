defmodule ElixirSessions.PingPong do
  use ElixirSessions.Checking

  def run() do
    IO.puts("Spawning process")
    ponger = spawn(__MODULE__, :pong, [])
    IO.puts("Process spawned as #{inspect(ponger)}")

    ping(ponger)
    pong(ponger)
  end

  @session "ping = !ping(any).?pong().end"
  def ping(pid) when is_pid(pid) do
    IO.puts("Sending ping to #{inspect(pid)}")

    send(pid, {:ping, self()})

    receive do
      {:pong} ->
        IO.puts("Received pong!")
    end
  end

  # @session "end"
  # defp ppp() do
  #   if 2 + 3 < 2 do
  #     :ok
  #   end

  #   with a <- :ok do
  #     a
  #   end

  #   a = 3

  #   cond do
  #     3 + 2 < 2 ->
  #       :ok
  #     a ->
  #       :okk
  #   end
  # end

  # @session "pong/0 = ?ping(any).!pong()"
  def pong() do
    receive do
      {:ping, pid} ->
        IO.puts(
          "Received ping from #{inspect(pid)}. Replying pong from #{inspect(self())} " <>
            "to #{inspect(pid)}"
        )

        send(pid, {:pong})
    end
  end

  @session "S_1 = !helloooo().!helloooo2().ping"
  @session "pong/1 = ?ping(any).!pong().S_1"
  def pong(hello) do
    b = 1
    _a = b

    receive do
      {:ping, pid} ->
        IO.puts(
          "Received ping from #{inspect(pid)}. Replying pong from #{inspect(self())} " <>
            "to #{inspect(pid)}"
        )

        send(pid, {:pong})
    end

    so_something()

    ping(self())
  end

  def so_something() do
    send(self(), {:helloooo})
    send(self(), {:helloooo2})

    # abc()
  end

  @session "loop = rec X.(!hello().X)"
  def loop() do
    send(self(), {:hello})

    loop()
  end

  @session "abc = rec X.(&{?hello().!aaa().X, ?stop()})"
  def abc() do
    receive do
      {:hello} ->
        send(self(), {:aaa})
        abc()

      {:stop} ->
        :ok
    end
  end
end
