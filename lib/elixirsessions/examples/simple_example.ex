# defmodule ElixirSessions.SmallExample do
#   use ElixirSessions.Checking
#   @moduledoc false
#   # iex -S mix

#   # def run() do
#   #   spawn(__MODULE__, :example1, [])
#   # end








#   @session "function1 = rec X.(   !ok().rec Y.(   &{?option1().X, ?option2().Y}   )   )"
#   def function1(pid) do
#     send(pid, {:ok})

#     function2(pid)
#   end

#   def function2(pid) do
#     receive do
#       {:option1} -> function1(pid)
#       {:option2} -> function2(pid)
#     end
#   end






#   # send in diff function
#   @session "function1 = rec X.(   !ok().rec Y.(   &{?option1().X, ?option2().Y}   )   )"
#   def function1(pid) do
#     function_send(pid)
#     function2(pid)
#   end

#   def function_send(pid) do
#     send(pid, {:ok})
#   end

#   def function2(pid) do
#     receive do
#       {:option1} -> function1(pid)
#       {:option2} -> function2(pid)
#     end
#   end






#   @session "function1 = rec X.(   !ok().rec Y.(   &{?option1().X, ?option2().Y, ?option3().!finish()}   )   )"
#   def function1(pid) do
#     send(pid, {:ok})

#     function2(pid)

#     send(pid, {:finish})
#   end

#   def function2(pid) do
#     receive do
#       {:option1} -> function1(pid)
#       {:option2} -> function2(pid)
#       {:finish} -> nil
#     end
#   end


#   # @session "dooo = rec X.(&{?A().rec Z.(!C().Z),   ?B().rec Y.(+{!D(), !E().Y, !F().X}),   ?C() })"
#   # def dooo() do
#   #   pid = self()
#   #   receive do
#   #     {:A} ->
#   #       firstRec(pid)
#   #     {:B} ->
#   #       secondRec(pid)
#   #     {:C} -> :ok
#   #   end

#   # end

#   # # @session "firstRec = rec Y.(!C().Y)"
#   # def firstRec(pid) do
#   #   send(pid, {:C})

#   #   firstRec(pid)
#   # end

#   # @session "secondRec = rec Y.(+{!D(), !E().Y, !F()})"
#   # def secondRec(pid) do
#   #   case true do
#   #     false ->
#   #       send(pid, {:D})

#   #     2 ->
#   #       send(pid, {:E})
#   #       secondRec(pid)

#   #     true ->
#   #       send(pid, {:F})
#   #       dooo()
#   #   end
#   # end

#   @session "example1 = rec X.(!okkkkk().?something(any).X)"
#   def example1() do
#     send(self(), {:okkkkk})

#     receive do
#       {:something, _} ->
#         :ok
#     end

#     example1()
#   end

#   @session "example2 = !ok().?something(any)"
#   def example2() do
#     send_call()

#     receive do
#       {:something, _} ->
#         :ok
#     end
#   end

#   @session "send_call = !ok()"
#   def send_call() do
#     send(self(), {:ok})
#   end

#   @session "S_1 = !ok3().!ok4()"
#   @session "example3 = !ok1().!ok2().S_1"
#   def example3() do
#     pid = self()

#     send(pid, {:ok1})
#     send(pid, {:ok2})
#     send(pid, {:ok3})
#     send(pid, {:ok4})
#   end

#   # @session "problem = ?label(any).!num(any)"
#   # def problem() do
#   #   # a = 5
#   #   receive do
#   #     {:label, _value} ->
#   #       :ok
#   #   end

#   #   send(self(), {:num, 55})
#   # end
# end
