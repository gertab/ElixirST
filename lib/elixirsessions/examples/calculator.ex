defmodule Examples.Calculator do
  use ElixirSessions
  @moduledoc false

  def main() do
    ST.spawn(&process1/1, [], &process2/1, [])
  end

  @session "calc = &{?add(number, number).!result(number).calc, ?mult(number, number).!result(number).calc, ?stop()}"
  @spec process1(pid) :: atom
  def process1(pid) do
    receive do
      {:add, number1, number2} ->
        IO.puts("process1: 3 + 7 = ")
        send(pid, {:result, number1 + number2})
        process1(pid)
      {:mult, number1, number2} ->
        send(pid, {:result, number1 * number2})
        process1(pid)
      {:stop} ->
        :ok
    end
  end

  @dual "calc"
  @spec process2(pid) :: {atom()}
  def process2(pid) do
    send(pid, {:add, 3, 7})
    receive do
      {:result, value} ->
        IO.puts("process1: 3 + 7 = #{value}")
      end

      send(pid, {:mult, 5, 26})
      receive do
        {:result, value} ->
          IO.puts("process1: 5 * 26 = #{value}")
    end

    send(pid, {:stop})
  end
end
