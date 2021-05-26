defmodule LargeExample do
  @moduledoc false
  use ElixirSessions

  @session "!Hello().end"
  @spec do_something(pid) :: :ok
  def do_something(pid) do
    send(pid, {:Hello})
    :ok
  end

  @session """
              rec X.(&{
                        ?Option1(string),
                        ?Option2().X,
                        ?Option3()
                      })
           """
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
end
