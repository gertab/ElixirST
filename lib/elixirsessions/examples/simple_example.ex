defmodule ElixirSessions.SimpleExample do
  use ElixirSessions
  # @dialyzer {:nowarn_function, ['server/2', 'client/1']}

  # iex -S mix
  # recompile && ElixirSessions.SimpleExample.run

  def run() do
    # ST.spawn(&server/2, [0], &client/1, [])
    server =
      spawn(fn ->
        receive do
          {:pid, pid} ->
            send(pid, {:pid, self()})
            server(pid, 0)
        end
      end)

    spawn(fn ->
      send(server, {:pid, self()})

      receive do
        {:pid, pid} ->
          client(pid)
      end
    end)
  end

  # add lists

  @session "rec X.(&{?num(number).X, ?result().!total(number)})"
  @spec server(pid(), number()) :: :ok
  def server(pid, acc) do
    IO.puts("Server")

    receive do
      {:num, value} ->
        server(pid, acc + value)

      {:result} ->
        send(pid, {:total, acc})
        :ok
    end
  end

  @dual &ElixirSessions.SimpleExample.server/2
  @spec client(pid()) :: atom()
  def client(pid) do
    IO.puts("Client")
    send(pid, {:num, 2})
    send(pid, {:num, 5})
    send(pid, {:num, 3})
    send(pid, {:result})

    total =
      receive do
        {:total, value} ->
          value
      end

    IO.puts("Total value = " <> inspect(total))
  end





  @moduledoc false
  # iex -S mix
  # mix session_check SimpleExample

  # @session ""
  # @spec example() :: :ok
  # def example() do
  #   # ab = 700 + 55
  #   # _ = ab + 8
  #   # _ = ab + true

  #   :ok
  # end

  # # Types from spec
  # @session ""
  # @spec example2(number) :: :ok
  # def example2(num) do
  #   # _ = 700 + num
  #   _ = not num

  #   :ok
  # end

  # # Variable types bound from session types
  # @session "?Hi(number).!Hello(boolean)"
  # @spec example3(pid) :: :ok
  # def example3(pid) do
  #   receive do
  #     {:Hi, value} ->
  #       # send(pid, {:Hello, value < 9})
  #       send(pid, {:Hello, value})
  #   end

  #   :ok
  # end

  # # Types of branches
  # @session "!A().rec X.(!B().&{?Option1(atom), ?Option2().X})"
  # @spec example4(pid()) :: atom()
  # def example4(pid) do
  #   send(pid, {:A})

  #   test_call(pid)
  # end

  # @spec test_call(pid) :: :ok
  # defp test_call(pid) do
  #   send(pid, {:B})

  #   receive do
  #     {:Option1, atom} ->
  #       atom

  #     {:Option2} ->
  #       test_call(pid)
  #   end
  # end

  # @dual &ElixirSessions.SimpleExample.example4/1
  # @spec example4dual(pid()) :: atom()
  # def example4dual(pid) do
  #   receive do
  #     {:A} ->
  #       :ok
  #   end

  #   receive do
  #     {:B} ->
  #       :ok
  #   end

  #   send(pid, {:Option2})

  #   receive do
  #     {:B} ->
  #       :ok
  #   end

  #   send(pid, {:Option1, :hello})

  #   :ok
  # end

  # @dual &ElixirSessions.SimpleExample.example4/1
  # def other() do
  #   send(self(), {:Bjsjds})
  # end

  # def adddddd(1111, 443434) do
  #   48343893
  # end

  # def adddddd(5555, num) do
  #   num
  # end

  # def adddddd(num, 443434) do
  #   num
  # end

  # def adddddd(num1, num2) do
  #   num1 + num2
  #   |> IO.inspect()
  # end
  # def run() do
  #   spawn(__MODULE__, :example1, [])
  # end

  # @session "rec X.(!A().!B().X)"
  # @session ""
  # @spec example(pid) :: no_return
  # def example(pid) do
  #   ab = 77_777_777_777 + 55
  #   _abbb = ab + 55
  #   _ = pid
  #   # # xxx = 76
  #   # # _ = xxx and false
  #   # # @session "!A().rec X.(!A().X)"
  #   # send(pid, {:A})
  #   # # @session "rec X.(!A().X)"
  #   # # @session "!A().rec X.(!A().X)"
  #   # aaa = 11111 + 2222 * 33333 + 44444 + 55555
  #   # _ = aaa * 7
  #   # example(pid)
  # end

  # @session ""
  # @spec abccccccc(55, number()) :: any
  # def abccccccc(ds, 553) do
  #   ds
  # end
  # def abccccccc(ds, _abc) when is_list(ds) do
  #   ds
  # end
  # def abccccccc(ds, _) do
  #   ds
  # end

  # @session "rec X.(!A().!sum(integer).!hello(string).X)"
  # # @spec example2(pid) :: no_return
  # def example2(pid) do
  #   send(pid, {:A})

  #   IO.puts("Adding numbers")
  #   numbers = [1, 4, 5, 7, 882]
  #   sum = Enum.reduce(numbers, &+/2)
  #   send(pid, {:sum, sum})

  #   IO.puts("Sending hello")
  #   string = get_hello()
  #   send(pid, {:hello, string})

  #   example2(pid)
  # end

  # defp get_hello() do
  #   "hello"
  # end

  # @session "rec X.(!A().!sum(integer).!hello(string).X)"
  # @spec example3(pid) :: no_return
  # def example3(pid) do
  #   send(pid, {:A})

  #   # IO.puts("Adding numbers")
  #   # numbers = [1, 4, 5, 7, 882]
  #   # sum = Enum.reduce(numbers, &+/2)
  #   sum = 5
  #   send(pid, {:sum, sum})

  #   # IO.puts("Sending hello")
  #   # string = get_hello()
  #   string = "hello"
  #   send(pid, {:hello, string})

  #   example3(pid)
  # end

  # @session "rec X.(&{?option1().X, ?option2()})"
  # # @session "rec X.(&{?option1().X, ?option2().!ok()})"
  # def f1() do
  #   receive do
  #     {:option1} -> f1()
  #     {:option2} -> :ok
  #   end
  #   # send(self(), {:ok})
  # end

  # @session "!ok().!ok2().!ok2().!ok111() "
  # def function1(pid) when is_pid(pid) do
  #   send(pid, {:ok})

  #   function2(pid)
  #   function2(pid)
  #   send(pid, {:ok111})
  # end

  # defp function2(pid) do
  #   send(pid, {:ok2})
  # end

  # @session "rec X.(   !ok().rec Y.(  !ok2().&{?option1().X, ?option2().Y}   )   )"
  # def function1(pid) do
  #   send(pid, {:ok})

  #   function2(pid)
  # end

  # defp function2(pid) do
  #   send(pid, {:ok2})

  #   receive do
  #     {:option1} -> function1(pid)
  #     {:option2} -> function2(pid)
  #   end
  # end

  # send in diff function
  # @session "rec X.(   !ok().rec Y.(   &{?option1().X, ?option2().Y}   )   )"
  # def function3(pid) do
  #   function_send(pid)
  #   function4(pid)
  # end

  # def function_send(pid) do
  #   send(pid, {:ok})
  # end

  # def function4(pid) do
  #   receive do
  #     {:option1} -> function3(pid)
  #     {:option2} -> function4(pid)
  #   end
  # end

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

  # @session """
  # rec X.(
  #         &{
  #              ?A().rec Z.(  !C().Z  ),
  #              ?B().rec Y.(  +{!D(), !E().Y, !F().X}  ),
  #              ?C()
  #           }
  #       )
  # """
  # def dooo() do
  #   pid = self()

  #   receive do
  #     {:A} ->
  #       firstRec(pid)

  #     {:B} ->
  #       secondRec(pid, 5)

  #     {:C} ->
  #       :ok
  #   end
  # end

  # def firstRec(pid) do
  #   send(pid, {:C})

  #   firstRec(pid)
  # end

  # def secondRec(pid, a) do
  #   case a do
  #     a when a < 2 ->
  #       send(pid, {:D})

  #     a when is_number(a) ->
  #       send(pid, {:E})
  #       secondRec(pid, a)

  #     _ ->
  #       send(pid, {:F})
  #       dooo()
  #   end
  # end

  # @session "rec X.(!okkkkk().?something(any).X)"
  # def example1() do
  #   send(self(), {:okkkkk})

  #   receive do
  #     {:something, _} ->
  #       :ok
  #   end

  #   example1()
  # end

  # @session "!ok().?something(any)"
  # def example2() do
  #   send_call()

  #   receive do
  #     {:something, _} ->
  #       :ok
  #   end
  # end

  # @session "!ok()"
  # def send_call() do
  #   send(self(), {:ok})
  # end

  # @session "!ok1().!ok2().!ok3().!ok4()"
  # def example3() do
  #   pid = self()

  #   send(pid, {:ok1})
  #   send(pid, {:ok2})
  #   send(pid, {:ok3})
  #   send(pid, {:ok4})
  # end

  # @session "?label(any).!num(any)"
  # def problem() do
  #   # a = 5
  #   receive do
  #     {:label, _value} ->
  #       :ok
  #   end

  #   send(self(), {:num, 55})
  # end
end
