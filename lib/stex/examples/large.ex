defmodule Examples.LargeExample do
  @moduledoc false
  use STEx

  @session "!Hello().end"
  @spec do_something(pid) :: :ok
  def do_something(pid) do
    send(pid, {:Hello})
    :ok
  end

  @session "X =  &{
                    ?Option1(binary),
                    ?Option2().X,
                    ?Option3()
                  }"
  @spec do_something_else :: :ok
  def do_something_else() do
    receive do
      {:Option1, value} ->
        IO.puts(value)

      {:Option2} ->
        do_something_else()

      {:Option3} ->
        :ok
    end
  end

  @dual "X"
  @spec do_something_else_dual(pid) :: :ok
  def do_something_else_dual(pid) do
    send(pid, {:Option2})
    send(pid, {:Option1, "Hello"})
    :ok
  end
end
