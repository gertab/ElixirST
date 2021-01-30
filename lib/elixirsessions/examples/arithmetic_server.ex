defmodule ElixirSessions.ArithmeticServer do
  use ElixirSessions.Checking

  @moduledoc """
  Sample module which uses concurrency and session types.
  The `run()` function is the starting point. The server (`arith_serv()`), is able to add and negate numbers. The `attempt1(server)` and `attempt2(server)` are two clients that interact with `arith_serv()`.
  """

  @doc """
  Entry point of the ArithmeticServer module. Spawns two clients that interact with `arith_serv()`.
  """
  def run() do
    server = spawn(__MODULE__, :arith_serv, [])
    attempt1(server)

    server = spawn(__MODULE__, :arith_serv, [])
    attempt2(server)
  end

  @doc """
  A simple artihmetic server that is able to do addition and negation of numbers.
  """
  @session "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"
  # def arith_serv() do
  #   receive do
  #     {:add} ->
  #       receive do
  #         {num1, num2, pid} ->
  #           IO.puts("[server] #{num1} + #{num2}")
  #           send(pid, {num1 + num2})
  #       end

  #     {:neg} ->
  #       receive do
  #         {num, pid} ->
  #           IO.puts("[server] neg of #{num}")
  #           send(pid, {-num})
  #       end
  #   end
  # end

  def arith_serv() do
    receive do
      {:add, num1, num2, pid} ->
            IO.puts("[server] #{num1} + #{num2}")
            send(pid, {num1 + num2})

      {:neg, num, pid} ->
            IO.puts("[server] neg of #{num}")
            send(pid, {-num})
    end
  end

  @doc """
  Client which interacts with `arith_serv()`.
  """
  @session "send '{label}' . choice<add: send '{number, number, pid}' . receive '{number}'>"
  def attempt1(server) when is_pid(server) do
    send(server, {:add})
    send(server, {34, 54, self()})

    receive do
      {value} ->
        IO.puts("[client] = #{value}")
    end
  end

  @doc """
  Another client which interacts with `arith_serv()`.
  """
  @session "send '{label}' . choice<neg: send '{number, pid}' . receive '{number}'>"
  def attempt2(server) when is_pid(server) do
    send(server, {:neg})
    send(server, {54, self()})

    receive do
      {value} ->
        IO.puts("[client] = #{value}")
    end
  end
end
