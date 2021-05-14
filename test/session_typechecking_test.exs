defmodule SessionTypecheckingTest do
  use ExUnit.Case
  doctest ElixirSessions.SessionTypechecking
  alias ElixirSessions.SessionTypechecking, as: TC

  def env do
    %{
      :state => :ok,
      :error_data => nil,
      :variable_ctx => %{},
      :session_type => %ST.Terminate{},
      :type => :any,
      :functions => %{},
      :function_session_type__ctx => %{}
    }
  end

  def typecheck(ast) do
    typecheck(ast, env())
  end

  def typecheck(ast, env) do
    ElixirSessions.Helper.expanded_quoted(ast)
    |> IO.inspect()
    |> Macro.prewalk(env, &TC.typecheck/2)
    |> elem(1)
  end

  test "literal - atom" do
    ast =
      quote do
        :hello1
        :hello2
        :hello3
      end

    assert typecheck(ast)[:type] == :hello3
  end

  test "literal - binary operations" do
    ast =
      quote do
        7 + 3
      end

    assert typecheck(ast)[:type] == :integer

    ast =
      quote do
        7.5 + 3
      end

    assert typecheck(ast)[:type] == :float

    ast =
      quote do
        7.6 - 8923
      end

    assert typecheck(ast)[:type] == :float

    ast =
      quote do
        7 * 8923
      end

    assert typecheck(ast)[:type] == :integer

    ast =
      quote do
        7 / 8923.6
      end

    assert typecheck(ast)[:type] == :float
  end

  test "literal - binary operations - error state" do
    ast =
      quote do
        7.6 + true
      end

    assert typecheck(ast)[:state] == :error
  end

  test "comparators" do
    # Elixir format: [==, !=, ===, !==, >, <, <=, >=]

    ast =
      quote do
        7.6 == true
      end

    assert typecheck(ast)[:type] == :boolean

    ast =
      quote do
        7.6 != true
      end

    assert typecheck(ast)[:type] == :boolean

    ast =
      quote do
        7.6 === true
      end

    assert typecheck(ast)[:type] == :boolean

    ast =
      quote do
        7.6 !== true
      end

    assert typecheck(ast)[:type] == :boolean

    ast =
      quote do
        7.6 < true
      end

    assert typecheck(ast)[:type] == :boolean

    ast =
      quote do
        7.6 > true
      end

    assert typecheck(ast)[:type] == :boolean

    ast =
      quote do
        7.6 <= true
      end

    assert typecheck(ast)[:type] == :boolean

    ast =
      quote do
        7.6 >= true
      end

    assert typecheck(ast)[:type] == :boolean

    ast =
      quote do
        not 6
      end

    assert typecheck(ast)[:state] == :error

    ast =
      quote do
        not true
      end

    assert typecheck(ast)[:type] == :boolean
  end

  test "binding variable" do
    ast =
      quote do
        a = 7
        b = a < 99
        c = true
        a
      end

    assert typecheck(ast)[:variable_ctx] == %{a: :integer, b: :boolean, c: :boolean}
    assert typecheck(ast)[:type] == :integer

    ast =
      quote do
        a = 7
        b = a + 99 + 9.9
        c = a
        a + b
      end

    assert typecheck(ast)[:variable_ctx] == %{a: :integer, b: :float, c: :integer}
    assert typecheck(ast)[:type] == :float
  end
end

# defmodule SessionTypecheckingTest do
#   use ExUnit.Case
#   doctest ElixirSessions.SessionTypechecking
#   alias ElixirSessions.SessionTypechecking

#   test "receive - not branch [throws error - Found a receive/branch, but expected]" do
#     fun = :func_name

#     body =
#       quote do
#         send(pid, {:value, 2432})

#         receive do
#           {:Number2} ->
#             :ok
#         end
#       end

#     st = "!value(integer).!Ping2()"
#     session_type = ST.string_to_st(st)

#     try do
#       ElixirSessions.SessionTypechecking.session_typecheck(fun, 0, body, session_type)
#       assert false
#     catch
#       _ -> assert true
#     end
#   end

#   test "receive - branch [throws error] - Mismatch in number of receive and & branches" do
#     fun = :func_name

#     body =
#       quote do
#         send(pid, {:value, 2432})

#         receive do
#           {:option1} ->
#             :ok

#           {:option2, value} ->
#             :ok
#         end
#       end

#     st = "!value(integer).&{?option1().!do_something(), ?option2(), ?option3()}"

#     session_type = ST.string_to_st(st)

#     try do
#       ElixirSessions.SessionTypechecking.session_typecheck(fun, 0, body, session_type)
#       assert false
#     catch
#       # x ->
#       # throw(x)
#       # assert true
#       _ -> assert true
#     end
#   end

#   test "receive - branch [throws error - Session type parameter length mismatch.]" do
#     fun = :func_name

#     body =
#       quote do
#         send(pid, {:value, 2432})

#         receive do
#           {:option1, num} ->
#             :ok
#         end
#       end

#     st = "!value(integer).&{?option1(number, string)}"

#     session_type = ST.string_to_st(st)

#     try do
#       ElixirSessions.SessionTypechecking.session_typecheck(fun, 0, body, session_type)
#       assert false
#     catch
#       _ -> assert true
#     end
#   end

#   test "receive - branch [throws error - Receive branch with label]" do
#     fun = :func_name

#     body =
#       quote do
#         send(pid, {:value, 2432})

#         receive do
#           {:UnknownOption, num} ->
#             :ok
#         end
#       end

#     st = "!value(integer).&{?option1(number)}"

#     session_type = ST.string_to_st(st)

#     try do
#       ElixirSessions.SessionTypechecking.session_typecheck(fun, 0, body, session_type)
#       assert false
#     catch
#       _ -> assert true
#     end
#   end

#   test "receive - branch [throws error - Mismatch in session type following the branch]" do
#     fun = :func_name

#     body =
#       quote do
#         send(pid, {:value, 2432})

#         receive do
#           {:Option1, num} ->
#             send(pid, {:SendSomething, abc})

#           {:Option2, num} ->
#             :ok
#         end

#         send(pid, {:ThenSendSomethingElse})
#       end

#     st =
#       "!value(any).&{?Option1(any).!SendSomething(any), ?Option2(any).!ThenSendSomethingElse()}"

#     session_type = ST.string_to_st(st)

#     try do
#       ElixirSessions.SessionTypechecking.session_typecheck(fun, 0, body, session_type)
#       assert false
#     catch
#       _ -> assert true
#     end
#   end

#   test "case - choice [no error]" do
#     fun = :func_name

#     body =
#       quote do
#         send(pid, {:value, 2432})

#         check = 233

#         case check do
#           44 ->
#             send(pid, {:Option1})
#             send(pid, {:SendSomething, abc})

#           _ ->
#             send(pid, {:Option2, :xyz})
#             :ok
#         end

#         send(pid, {:ThenSendSomethingElse})
#       end

#     st = "!value(any).+{!Option1().!SendSomething(any).!ThenSendSomethingElse(),
#                         !Option2(atom).!ThenSendSomethingElse()}"

#     session_type = ST.string_to_st(st)

#     try do
#       ElixirSessions.SessionTypechecking.session_typecheck(fun, 0, body, session_type)
#       assert true
#     catch
#       _ ->
#         assert false
#     end
#   end

#   test "case - choice by send [no error]" do
#     fun = :func_name

#     body =
#       quote do
#         send(pid, {:value, 2432})

#         check = 233

#         send(pid, {:Option1})

#         send(pid, {:ThenSendSomethingElse})
#       end

#     st = "!value(any).+{!Option1().!ThenSendSomethingElse(),
#                         !Option2(atom).!ThenSendSomethingElse()}"

#     session_type = ST.string_to_st(st)

#     try do
#       ElixirSessions.SessionTypechecking.session_typecheck(fun, 0, body, session_type)
#       assert true
#     catch
#       _ ->
#         assert false
#     end
#   end

#   test "case - choice [throws error] - Found a choice, but expected" do
#     fun = :func_name

#     body =
#       quote do
#         send(pid, {:value, 2432})

#         check = 233

#         case check do
#           44 ->
#             send(pid, {:Option1})
#             send(pid, {:SendSomething, abc})

#           _ ->
#             send(pid, {:Option2, :xyz})
#             :ok
#         end

#         send(pid, {:ThenSendSomethingElse})
#       end

#     st = "!value(any).&{?Option1()}"

#     session_type = ST.string_to_st(st)

#     try do
#       ElixirSessions.SessionTypechecking.session_typecheck(fun, 0, body, session_type)
#       assert false
#     catch
#       _ ->
#         assert true
#     end
#   end

#   test "case - choice [throws error - More cases found]" do
#     fun = :func_name

#     body =
#       quote do
#         send(pid, {:value, 2432})

#         check = 233

#         case check do
#           44 ->
#             send(pid, {:Option1})
#             send(pid, {:SendSomething, abc})

#           _ ->
#             send(pid, {:Option2, :xyz})
#             :ok
#         end

#         send(pid, {:ThenSendSomethingElse})
#       end

#     st = "!value(any).+{!Option1().!SendSomething(any).!ThenSendSomethingElse()}"

#     session_type = ST.string_to_st(st)

#     try do
#       ElixirSessions.SessionTypechecking.session_typecheck(fun, 0, body, session_type)
#       assert false
#     catch
#       _ ->
#         assert true
#     end
#   end

#   test "case - choice [throws error - Couldn't match case with session type]" do
#     fun = :func_name

#     body =
#       quote do
#         send(pid, {:value, 2432})

#         check = 233

#         case check do
#           44 ->
#             send(pid, {:Option1})
#             send(pid, {:BlaBlaBla, abc})

#           _ ->
#             send(pid, {:Option2, :xyz})
#             :ok
#         end

#         send(pid, {:ThenSendSomethingElse})
#       end

#     st = "!value(any).+{!Option1().!SendSomething(any).!ThenSendSomethingElse(),
#                         !Option2(atom).!ThenSendSomethingElse()}"

#     session_type = ST.string_to_st(st)

#     try do
#       ElixirSessions.SessionTypechecking.session_typecheck(fun, 0, body, session_type)
#       assert false
#     catch
#       _ ->
#         assert true
#     end
#   end

#   test "case - choice [throws error - Mismatch in session type following the choice]" do
#     fun = :func_name

#     body =
#       quote do
#         send(pid, {:value, 2432})

#         check = 233

#         case check do
#           44 ->
#             send(pid, {:Option1})
#             send(pid, {:SendSomething, abc})
#             send(pid, {:ThenSendSomethingElse})

#           _ ->
#             send(pid, {:Option2, :xyz})
#             :ok
#         end

#         # send(pid, {:ThenSendSomethingElse})
#       end

#     st = "!value(any).+{!Option1().!SendSomething(any).!ThenSendSomethingElse(),
#                       !Option2(atom).!ThenSendSomethingElse()}"

#     session_type = ST.string_to_st(st)

#     try do
#       ElixirSessions.SessionTypechecking.session_typecheck(fun, 0, body, session_type)
#       assert false
#     catch
#       _ ->
#         assert true
#     end
#   end
# end
