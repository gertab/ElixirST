defmodule ElixirSessions.ArithmeticServer do
  use ElixirSessions.Checking

  @moduledoc false

  def run() do
    server = spawn(__MODULE__, :arith_serv, [])
    attempt1(server)

    server = spawn(__MODULE__, :arith_serv, [])
    attempt2(server)
  end

  @session "arith_serv = &{ ?add(number, number, pid).!result(number), ?neg(number, pid).!result(number)}"
  def arith_serv() do
    receive do
      {:add, num1, num2, pid} ->
            IO.puts("[server] #{num1} + #{num2}")
            # send(pid, {:result, num1 + num2})

      {:neg, num, pid} ->
            IO.puts("[server] neg of #{num}")
            # send(pid, {:result, -num})#
    end

    send(self(), {:result, 33})
    # send_result(33, self())
  end

  @session "send_result = !result(number)"
  # def send_result(res, pid) do
  #   send(pid, {:result, res})
  # end

  @session "attempt1 = !add().!value(number, number, pid).?result(number)"
  def attempt1(server) when is_pid(server) do
    send(server, {:add})
    send(server, {:value, 34, 54, self()})

    receive do
      {:result, res} ->
        IO.puts("[client] = #{res}")
    end
  end

  @session "attempt2 = !neg(number, pid).?result(number)"
  def attempt2(server) when is_pid(server) do
    send(server, {:neg, 54, self()})

    receive do
      {:result, value} ->
        IO.puts("[client] = #{value}")
    end
  end
end
