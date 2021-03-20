defmodule ElixirSessions.SmallExample do
  use ElixirSessions.Checking
  @moduledoc false
  # iex -S mix

  # def run() do
  #   spawn(__MODULE__, :example1, [])
  # end

  # @session "dooo = rec X.(&{?A().rec Y.(!C().Y),   ?B().rec Y.(+{!D(), !E().Y, !F().X}),   ?C() })"
  # def dooo() do
  #   pid = self()
  #   receive do
  #     {:A} ->
  #       firstRec(pid)
  #     {:B} ->
  #       secondRec(pid)
  #     {:C} -> :ok
  #   end

  # end

  # # @session "firstRec = rec Y.(!C().Y)"
  # def firstRec(pid) do
  #   send(pid, {:C})

  #   firstRec(pid)
  # end

  # # @session "secondRec = rec Y.(+{!D(), !E().Y, !F()})"
  # def secondRec(pid) do
  #   case true do
  #     false ->
  #       send(pid, {:D})

  #     2 ->
  #       send(pid, {:E})
  #       secondRec(pid)

  #     true ->
  #       send(pid, {:F})
  #       dooo()
  #   end
  # end

  @session "example1 = rec X.(!okkkkk().?something(any).X)"
  def example1() do
    send(self(), {:okkkkk})

    receive do
      {:something, _} ->
        :ok
    end

    example1()
  end

  @session "example2 = !ok().?something(any)"
  def example2() do
    send_call()

    receive do
      {:something, _} ->
        :ok
    end
  end

  @session "send_call = !ok()"
  def send_call() do
    send(self(), {:ok})
  end

  @session "S_1 = !ok3().!ok4()"
  @session "example3 = !ok1().!ok2().S_1"
  def example3() do
    pid = self()

    send(pid, {:ok1})
    send(pid, {:ok2})
    send(pid, {:ok3})
    send(pid, {:ok4})
  end

  # @session "problem = ?label(any).!num(any)"
  # def problem() do
  #   # a = 5
  #   receive do
  #     {:label, _value} ->
  #       :ok
  #   end

  #   send(self(), {:num, 55})
  # end
end
