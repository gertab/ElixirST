# defmodule ElixirSessions.ArithmeticServer do
#   use ElixirSessions.Checking

#   @moduledoc """
#   Sample module which uses concurrency and session types.
#   The `run()` function is the starting point. The server (`arith_serv()`), is able to add and negate numbers. The `attempt1(server)` and `attempt2(server)` are two clients that interact with `arith_serv()`.
#   """

#   @doc """
#   Entry point of the ArithmeticServer module. Spawns two clients that interact with `arith_serv()`.
#   """
#   def run() do
#     server = spawn(__MODULE__, :arith_serv, [])
#     attempt1(server)

#     server = spawn(__MODULE__, :arith_serv, [])
#     attempt2(server)
#   end

#   @doc """
#   A simple artihmetic server that is able to do addition and negation of numbers.
#   """
#   @session "&{ ?add(number, number, pid).!result(number), ?neg(number, pid).!result(number)}"
#   def arith_serv() do
#     receive do
#       {:add, num1, num2, pid} ->
#             IO.puts("[server] #{num1} + #{num2}")
#             send(pid, {:result, num1 + num2})

#       {:neg, num, pid} ->
#             IO.puts("[server] neg of #{num}")
#             send(pid, {:result, -num})#
#     end

#     # send(self(), {:result, 33})
#   end

#   @doc """
#   Client which interacts with `arith_serv()`.
#   """
#   @session "+{!add(number, number, pid).?result(number), !neg(number, pid).?result(number)}"
#   def attempt1(server) when is_pid(server) do


#     a = 3
#     case a do
#       3 ->
#         send(server, {:add, 34, 54, self()})

#         receive do
#           {:result, res} ->
#             IO.puts("[client] = #{res}")
#         end
#       # _ ->
#       #   send(server, {:neg, 54, self()})

#       #   receive do
#       #     {:result, res} ->
#       #       IO.puts("[client] = #{res}")
#       #   end
#     end
#   end

#   @doc """
#   Client which interacts with `arith_serv()`.
#   """
#   @session "!add().!value(number, number, pid).?result(number)"
#   def attempt1(server) when is_pid(server) do
#     send(server, {:add})
#     send(server, {:value, 34, 54, self()})

#     receive do
#       {:result, res} ->
#         IO.puts("[client] = #{res}")
#     end
#   end

#   @doc """
#   Another client which interacts with `arith_serv()`.
#   """
#   @session "!neg(number, pid).?result(number)"
#   def attempt2(server) when is_pid(server) do
#     send(server, {:neg, 54, self()})

#     receive do
#       {:result, value} ->
#         IO.puts("[client] = #{value}")
#     end
#   end
# end
