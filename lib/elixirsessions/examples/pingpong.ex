# defmodule ElixirSessions.PingPong do
#   use ElixirSessions

#   def run() do
#     IO.puts("Spawning process")
#     pinger = spawn(__MODULE__, :ping, [])
#     _ponger = spawn(__MODULE__, :pong, [pinger])
#     IO.puts("Process spawned as #{inspect(pinger)}")
#   end

#   @session "rec X.(?ping(pid).!pong().X)"
#   def ping() do
#     receive do
#       {:ping, pid} ->
#         IO.puts(
#           "Received ping from #{inspect(pid)}. Replying pong from #{inspect(self())} " <>
#             "to #{inspect(pid)}"
#         )

#         send(pid, {:pong})
#     end

#     ping()
#   end

#   @dual &ElixirSessions.PingPong.ping/0
#   def pong(pid) do
#     send(pid, {:ping, self()})

#     receive do
#       {:pong} ->
#         IO.puts("Received pong.")
#     end

#     pong(pid)
#   end
# end
