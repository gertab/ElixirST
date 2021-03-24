defmodule ElixirSessions.PingPong do
  use ElixirSessions.Checking

  # def run() do
  #   IO.puts("Spawning process")
  #   ponger = spawn(__MODULE__, :pong, [])
  #   IO.puts("Process spawned as #{inspect(ponger)}")

  #   ping(ponger)
  #   pong(ponger)
  # end

  # @session "ping = !ping(any).?pong()"
  @session "ping = !ping(any).rec X.(?pong().X)"
  def ping(pid) when is_pid(pid) do
    IO.puts("Sending ping to #{inspect(pid)}")

    send(pid, {:ping, self()})

    kkk()
  end

  def kkk() do
    receive do
      {:pong} ->
        IO.puts("Received pong!")
    end

    kkk()
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

  @session "pong/0 = ?ping(any).!pong()"
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

  # def pong(hello) do
  # end

  # @session "pong/2 = ?ping(any).!pong().!helloooo()"
  # def pong(hello, _hello2) when is_atom(hello) do
  #   b = hello + 2

  #   case true do
  #     false ->
  #       receive do
  #         {:ping, pid} ->
  #           IO.puts(
  #             "Received ping from #{inspect(pid)}. Replying pong from #{inspect(self())} " <>
  #               "to #{inspect(pid)}"
  #           )

  #           send(pid, {:pong})
  #       end

  #     _ ->
  #       receive do
  #         {:ping, pid} ->
  #           IO.puts(
  #             "Received ping from #{inspect(pid)}. Replying pong from #{inspect(self())} " <>
  #               "to #{inspect(pid)}"
  #           )

  #           send(pid, {:pong})
  #       end
  #   end

  #   case true do
  #     false ->
  #       send(self(), {:helloooo})

  #     _ ->
  #       send(self(), {:helloooo})
  #   end

  #   # so_something()

  #   # ping(self())
  # end

  @session "do_something = !helloooo().!helloooo2()"
  def do_something(5555) do
    send(self(), {:helloooo})
    send(self(), {:helloooo2})

    # abc()
  end

  def do_something(number) do
    send(self(), {:helloooo})
    send(self(), {:helloooo2})

    # abc()
  end

  # @session "loop = rec X.(!hello().X)"
  # def loop() do
  #   send(self(), {:hello})

  #   loop()
  # end

  # @session "abc = rec X.(&{?hello().!aaa().X, ?stop()})"
  # def abc() do
  #   receive do
  #     {:hello} ->
  #       send(self(), {:aaa})
  #       abc()

  #     {:stop} ->
  #       :ok
  #   end
  # end
end
