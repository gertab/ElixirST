# defmodule ElixirSessions.LargerExample do
#   use ElixirSessions.Checking

#   def run() do
#     spawn(__MODULE__, :example1, [])
#   end

#   @session "send 'any'"
#   def example1() do
#     pid =
#       receive do
#         {:pid, pid} ->
#           pid
#       end

#     receive do
#       {:option1} ->
#         a = 1
#         send(pid, {a})
#         send(pid, {a + 1})

#       {:option2} ->
#         b = 2
#         send(pid, {b})

#       {:option3, value} ->
#         b = 3
#         send(pid, {b})
#         case value do
#           true -> send(pid, {:hello})
#           false -> send(pid, {:hello2})
#           _ -> send(pid, {:not_hello, 3})
#         end
#     end

#     # case true do
#     #   true ->
#     #     :ok
#     #   false ->
#     #     :error
#     # end

#     # example1()
#   end
# end
