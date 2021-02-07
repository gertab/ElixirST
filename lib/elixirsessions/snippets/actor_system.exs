# iex -S mix
# c("lib/elixirsessions/snippets/actor_system.exs")
# ActorSystem.A.run
defmodule ActorSystem do
  # Caroline Ch 5
  # A = i[h!5] || j[rec X.h!6]
  # B = i[h!5.rec X.h!6]
  # T = h[rcv{5 -> rec X.rcv{6 -> nil}}]

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

  defmodule Actor do

    defstruct action: :root, args: [], next: []

    def run() do
      i = Actor.init_actor()

      actor_send(i, self(), :ok)
      |> actor_send(self(), :okk)
      # |> actor_receive(:x)
    end

    def init_actor() do
      %Actor{}
    end

    def actor_send(actor, dest, message) do

      # send(dest, message)

      current = %Actor{action: :send, args: [dest: dest, message: message]}
      %Actor{actor | next: [current]}
    end

    def actor_receive(actor, case1) do
      # receive do
      #   {^case1, value} ->
      #     value
      # end

      current = %Actor{action: :recv, args: [case: case1]}
      %Actor{actor | next: [current]}
    end

    # todo rec, branch,
  end
end
