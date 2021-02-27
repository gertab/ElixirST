defmodule ElixirSessions.LargerExample do
  use ElixirSessions.Checking
  @moduledoc false
  # iex -S mix


  @session "send 'any' . receive 'any'"
  def example1() do
    send(self(), :ok)

    receive do
      {:message_type, _} ->
        :ok
    end

  end

  @session "send 'any' . send 'any' . receive 'any'"
  def example2() do
    send(self(), :ok)
    send(self(), :ok)

    receive do
      {:pid, _pid} ->
        send(self(), :ok2)
    end
  end

  @session "receive 'any' . send 'int'"
  def problem() do
    # a = 5
    receive do
      {:label, _value} ->
        :ok
    end

    send(self(), 55)
  end

  def run() do
    spawn(__MODULE__, :example1, [])
  end

end
