defmodule Examples.Calculator do
  use STEx
  @moduledoc false

  def main() do
    STEx.spawn(&server/1, [], &client/1, [])
  end

  @session "calc = &{?add(number, number).!result(number).calc, ?mult(number, number).!result(number).calc, ?stop()}"
  @spec server(pid) :: atom
  def server(pid) do
    receive do
      {:add, number1, number2} ->
        send(pid, {:result, number1 + number2})
        server(pid)
      {:mult, number1, number2} ->
        send(pid, {:result, number1 * number2})
        server(pid)
      {:stop} ->
        :ok
    end
  end

  @dual "calc"
  @spec client(pid) :: {atom()}
  def client(pid) do
    send(pid, {:add, 3, 7})
    receive do
      {:result, value} ->
        IO.puts("client: 3 + 7 = #{value}")
      end

      send(pid, {:mult, 5, 8})
      receive do
        {:result, value} ->
          IO.puts("client: 5 * 8 = #{value}")
    end

    send(pid, {:stop})
  end
end
