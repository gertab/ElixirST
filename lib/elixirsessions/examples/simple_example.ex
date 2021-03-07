defmodule ElixirSessions.SmallExample do
  use ElixirSessions.Checking
  @moduledoc false
  # iex -S mix

  def run() do
    spawn(__MODULE__, :example1, [])
  end

  # @infer_session true
  @session "!ok().?something(any)"
  def example1() do
    send(self(), {:ok})

    receive do
      {:something, _} ->
        :ok
    end
  end

  @session "!ok1().!ok2().?address(any).!ok3()"
  def example2() do
    pid = self()

    send(pid, {:ok1})
    send(pid, {:ok2})

    receive do
      {:address, _pid} ->
        send(pid, {:ok3})
    end
  end

  @session "?label(any).!num(any)"
  def problem() do
    # a = 5
    receive do
      {:label, _value} ->
        :ok
    end

    send(self(), {:num, 55})
  end
end
