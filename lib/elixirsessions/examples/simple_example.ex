defmodule ElixirSessions.SmallExample do
  use ElixirSessions.Checking
  @moduledoc false
  # iex -S mix

  def run() do
    spawn(__MODULE__, :example1, [])
  end

  @session "rec X.(   !ok().rec Y.(  !ok2().&{?option1().X, ?option2().Y}   )   )"
  def function1(pid) do
    send(pid, {:ok})

    function2(pid)
  end

  defp function2(pid) do
    send(pid, {:ok2})

    receive do
      {:option1} -> function1(pid)
      {:option2} -> function2(pid)
    end
  end

  # send in diff function
  @session "rec X.(   !ok().rec Y.(   &{?option1().X, ?option2().Y}   )   )"
  def function3(pid) do
    function_send(pid)
    function4(pid)
  end

  def function_send(pid) do
    send(pid, {:ok})
  end

  def function4(pid) do
    receive do
      {:option1} -> function3(pid)
      {:option2} -> function4(pid)
    end
  end

  # @session "rec X.(   !ok().rec Y.(   &{?option1().X, ?option2().Y, ?option3().!finish()}   )   )"
  # def function5(pid) do
  #   send(pid, {:ok})

  #   function6(pid)

  #   send(pid, {:finish})
  # end

  # def function6(pid) do
  #   receive do
  #     {:option1} -> function5(pid)
  #     {:option2} -> function6(pid)
  #     {:option3} -> nil
  #   end
  # end

  @session """
  rec X.(
          &{
               ?A().rec Z.(  !C().Z  ),
               ?B().rec Y.(  +{!D(), !E().Y, !F().X}  ),
               ?C()
            }
        )
  """
  def dooo() do
    pid = self()

    receive do
      {:A} ->
        firstRec(pid)

      {:B} ->
        secondRec(pid, 5)

      {:C} ->
        :ok
    end
  end

  def firstRec(pid) do
    send(pid, {:C})

    firstRec(pid)
  end

  def secondRec(pid, a) do
    case a do
      a when a < 2 ->
        send(pid, {:D})

      a when is_number(a) ->
        send(pid, {:E})
        secondRec(pid, a)

      _ ->
        send(pid, {:F})
        dooo()
    end
  end

  @session "rec X.(!okkkkk().?something(any).X)"
  def example1() do
    send(self(), {:okkkkk})

    receive do
      {:something, _} ->
        :ok
    end

    example1()
  end

  @session "!ok().?something(any)"
  def example2() do
    send_call()

    receive do
      {:something, _} ->
        :ok
    end
  end

  @session "!ok()"
  def send_call() do
    send(self(), {:ok})
  end

  @session "!ok1().!ok2().!ok3().!ok4()"
  def example3() do
    pid = self()

    send(pid, {:ok1})
    send(pid, {:ok2})
    send(pid, {:ok3})
    send(pid, {:ok4})
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
