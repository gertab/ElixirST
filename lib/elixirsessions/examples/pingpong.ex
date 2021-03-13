defmodule ElixirSessions.PingPong do
  use ElixirSessions.Checking

  def run() do
    IO.puts("Spawning process")
    ponger = spawn(__MODULE__, :pong, [])
    IO.puts("Process spawned as #{inspect(ponger)}")

    ping(ponger)
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
          "Received ping from #{inspect(pid)}. Replying pong from #{inspect(self())} to #{
            inspect(pid)
          }"
        )

        send(pid, {:pong})
    end
  end

  @session "a = ?ping(any).!pong()"
  @session "s = ?ping(any).!pong()"
  @session "pong/1 = ?ping(any).!pong().!helloooo().!helloooo2().ping"
  def pong(hello) do
    b = 1
    a = b

    receive do
      {:ping, pid} ->
        IO.puts(
          "Received ping from #{inspect(pid)}. Replying pong from #{inspect(self())} to #{
            inspect(pid)
          }"
        )

        send(pid, {:pong})
    end

    # pong()

    jkhnsdfjknds()

    ping(self())
  end

  # @session "jkhnsdfjknds = !helloooo().!helloooo2()"
  def jkhnsdfjknds() do
    send(self(), {:helloooo})

    abc()
  end

  def abc() do
    a = 3
    send(self(), {:helloooo2})
    # jkhnsdfjknds()
    a + 3
  end

  # @session "loop = rec X.(+{!abc().X, !def().X})"
  # @session "loop = rec X.(&{?abc().X, ?def().X})"
  # def loop() do
    # receive do
    #   {:abc} ->
    #     :ok

    #   {:def} ->
    #     :ok
    # end
    # receive do
    #   {:abc} ->
    #     :ok

    #   {:def} ->
    #     :ok
    # end

    # case true do
    #   true ->
    #     send(self(), {:abc})

    #   true ->
    #     send(self(), {:def})
    # end

    # send(self(), {:hello})

    # case true do
    #   true ->
    #     send(self(), {:abc})

    #   true ->
    #     send(self(), {:def})
    # end

  #   loop()
  # end



  # def abc() do
  #   send(self(), {:hello})
  # end
end
