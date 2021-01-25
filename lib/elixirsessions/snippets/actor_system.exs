# iex -S mix
# c("lib/elixirsessions/snippets/actor_system.exs")
# ActorSystem.A.run
defmodule ActorSystem do
  # A = i[h!5] || j[rec X.h!6]
  # B = i[h!5.rec X.h!6]

  # ! = send, ? = receive

  defmodule A do
    def run() do
      h = spawn(__MODULE__, :actor_h, [])
      _i = spawn(__MODULE__, :actor_i, [h])
      _j = spawn(__MODULE__, :actor_j, [h])
    end

    def actor_i(h) do
      send(h, 5)
      IO.puts("i sent 5 to h")
    end

    def actor_j(h) do
      send(h, 6)
      IO.puts("j sent 6 to h")
    end

    def actor_h() do
      receive do
        message -> IO.puts("h received #{message}")
      end
      actor_h()
    end
  end

  defmodule B do
    def run() do
      h = spawn(__MODULE__, :actor_h, [])
      _i = spawn(__MODULE__, :actor_i, [h])
    end

    def actor_i(h) do
      send(h, 5)
      IO.puts("i sent 5 to h")

      rec_X(h)
    end

    def rec_X(h) do
      send(h, 6)
      IO.puts("i sent 6 to h")

      rec_X(h)
    end

    def actor_h() do
      receive do
        message -> IO.puts("h received #{message}")
      end
      actor_h()
    end
  end
end
