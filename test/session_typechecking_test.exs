defmodule SessionTypecheckingTest do
  use ExUnit.Case
  doctest ElixirSessions.SessionTypechecking
  alias ElixirSessions.SessionTypechecking, as: TC

  setup_all do
    # Logger.configure(level: :error)
    Logger.remove_backend(:console)

    :ok
  end

  def env do
    %{
      :state => :ok,
      :error_data => nil,
      :variable_ctx => %{},
      :session_type => %ST.Terminate{},
      :type => :any,
      :functions => %{},
      :function_session_type_ctx => %{}
    }
  end

  def typecheck(ast) do
    typecheck(ast, env())
  end

  def typecheck(ast, env) do
    ElixirSessions.Helper.expanded_quoted(ast)
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

    assert typecheck(ast)[:type] == :atom
    assert typecheck(ast)[:state] == :ok
  end

  test "literal - binary operations" do
    ast =
      quote do
        7 + 3
      end

    assert typecheck(ast)[:type] == :number
    assert typecheck(ast)[:state] == :ok

    ast =
      quote do
        7.5 + 3
      end

    assert typecheck(ast)[:type] == :number
    assert typecheck(ast)[:state] == :ok

    ast =
      quote do
        7.6 - 8923
      end

    assert typecheck(ast)[:type] == :number
    assert typecheck(ast)[:state] == :ok

    ast =
      quote do
        7 * 8923
      end

    assert typecheck(ast)[:type] == :number
    assert typecheck(ast)[:state] == :ok

    ast =
      quote do
        7 / 8923.6
      end

    assert typecheck(ast)[:type] == :number
    assert typecheck(ast)[:state] == :ok
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

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:type] == :boolean

    ast =
      quote do
        7.6 != true
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:type] == :boolean

    ast =
      quote do
        7.6 === true
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:type] == :boolean

    ast =
      quote do
        7.6 !== true
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:type] == :boolean

    ast =
      quote do
        7.6 < true
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:type] == :boolean

    ast =
      quote do
        7.6 > true
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:type] == :boolean

    ast =
      quote do
        7.6 <= true
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:type] == :boolean

    ast =
      quote do
        7.6 >= true
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:type] == :boolean

    ast =
      quote do
        not 6
      end

    assert typecheck(ast)[:state] == :error

    ast =
      quote do
        not true
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:type] == :boolean
  end

  test "binding variable" do
    ast =
      quote do
        a = 7
        b = a < 99
        c = true
        a
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:variable_ctx] == %{a: :number, b: :boolean, c: :boolean}
    assert result[:type] == :number

    ast =
      quote do
        a = 7
        b = a + 99 + 9.9
        c = a
        a + b
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:variable_ctx] == %{a: :number, b: :number, c: :number}
    assert result[:type] == :number
  end

  test "tuples" do
    ast =
      quote do
        {1, 2, true, :abc, 6.6}
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:type] == {:tuple, [:number, :number, :boolean, :atom, :number]}

    ast =
      quote do
        {1, 2}
      end

    assert result[:state] == :ok
    result = typecheck(ast)
    assert result[:type] == {:tuple, [:number, :number]}

    ast =
      quote do
        a = 323
        b = true
        c = a
        d = c
        a = {a, b, c, d}
        z = {a, {a, b}}
        z
      end

    result = typecheck(ast)

    assert result[:state] == :ok

    assert result[:type] ==
             {:tuple,
              [
                tuple: [:number, :boolean, :number, :number],
                tuple: [{:tuple, [:number, :boolean, :number, :number]}, :boolean]
              ]}
  end

  test "send" do
    ast =
      quote do
        self()
      end

    assert typecheck(ast)[:type] == :pid

    ast =
      quote do
        a = 4
        a = true
        p = self()
        send(p, {:hello, a, false})
      end

    env = %{env() | session_type: ST.string_to_st("!hello(boolean, boolean)")}
    result = typecheck(ast, env)
    assert result[:state] == :ok
    assert result[:type] == {:tuple, [:atom, :boolean, :boolean]}
    assert result[:session_type] == %ST.Terminate{}

    ast =
      quote do
        a = 4
        send(a, a)
      end

    assert typecheck(ast)[:state] == :error

    ast =
      quote do
        a = 4
        a = true
        p = self()
        send(p, {:hello, a})
      end

    env = %{env() | session_type: ST.string_to_st("!hello(boolean, boolean)")}
    assert typecheck(ast, env)[:state] == :error

    ast =
      quote do
        a = 4
        a = true
        p = self()
        b = :abc
        send(p, {:hello, a, b})
      end

    env = %{env() | session_type: ST.string_to_st("!hello(boolean, boolean)")}
    assert typecheck(ast, env)[:state] == :error

    ast =
      quote do
        a = 4
        a = true
        p = self()
        b = :abc
        send(p, {6, a, b})
      end

    env = %{env() | session_type: ST.string_to_st("!hello(boolean, boolean)")}
    assert typecheck(ast, env)[:state] == :error

    ast =
      quote do
        a = 4
        p = self()
        b = :abc
        send(p, {:A, a})
        send(p, {:B, b})
      end

    env = %{env() | session_type: ST.string_to_st("!A(number).!B(atom)")}
    result = typecheck(ast, env)
    assert result[:state] == :ok
    assert result[:type] == {:tuple, [:atom, :atom]}
    assert result[:session_type] == %ST.Terminate{}
  end

  test "send - choice" do
    ast =
      quote do
        self()
      end

    assert typecheck(ast)[:type] == :pid

    ast =
      quote do
        a = 4
        a = true
        p = self()
        send(p, {:hello, a, false})
      end

    env = %{env() | session_type: ST.string_to_st("+{!hello(boolean, boolean)}")}
    result = typecheck(ast, env)
    assert result[:state] == :ok
    assert result[:type] == {:tuple, [:atom, :boolean, :boolean]}
    assert result[:session_type] == %ST.Terminate{}

    ast =
      quote do
        a = 4
        send(a, a)
      end

    assert typecheck(ast)[:state] == :error

    ast =
      quote do
        a = 4
        a = true
        p = self()
        send(p, {:hello, a})
      end

    env = %{env() | session_type: ST.string_to_st("+{!otheroption(), !hello(boolean, boolean)}")}
    assert typecheck(ast, env)[:state] == :error

    ast =
      quote do
        a = 4
        a = true
        p = self()
        b = :abc
        send(p, {:hello, a, b})
      end

    env = %{env() | session_type: ST.string_to_st("+{!A(), !hello(boolean, boolean)}")}
    assert typecheck(ast, env)[:state] == :error

    ast =
      quote do
        a = 4
        a = true
        p = self()
        b = :abc
        send(p, {6, a, b})
      end

    env = %{env() | session_type: ST.string_to_st("+{!A(number), !B(), !hello(boolean, boolean)}")}
    assert typecheck(ast, env)[:state] == :error

    ast =
      quote do
        a = 4
        p = self()
        b = :abc
        send(p, {:A, a})
        send(p, {:B, b})
      end

    env = %{env() | session_type: ST.string_to_st("+{!A(number).!B(atom), !C(atom)}")}
    result = typecheck(ast, env)
    assert result[:state] == :ok
    assert result[:type] == {:tuple, [:atom, :atom]}
    assert result[:session_type] == %ST.Terminate{}
  end

  test "receive" do
    ast =
      quote do
        receive do
          {:A, value} ->
            value

          {:B, value1, value2} ->
            value2 + value2
        end
      end

    env = %{env() | session_type: ST.string_to_st("&{?A(number), ?B(number, float)}")}
    result = typecheck(ast, env)
    assert result[:state] == :ok
    assert result[:type] == :number
    assert result[:session_type] == %ST.Terminate{}

    ast =
      quote do
        value = 5

        receive do
          {:A, value2} ->
            value + value2

          {:B, value1, value2} ->
            value2 + value2
        end
      end

    env = %{env() | session_type: ST.string_to_st("&{?A(float), ?B(number, float)}")}
    result = typecheck(ast, env)
    assert result[:state] == :ok
    assert result[:type] == :number
    assert result[:session_type] == %ST.Terminate{}

    ast =
      quote do
        value = 5

        receive do
          {:A, value2} ->
            value + value2
            true

          {:B, value1, value2} ->
            value2 + value2
        end
      end

    env = %{env() | session_type: ST.string_to_st("&{?A(float), ?B(number, float)}")}
    assert typecheck(ast, env)[:state] == :error

    ast =
      quote do
        value = true

        receive do
          {:A, value2, value3} ->
            value and value2

          {:B, value1, value2} ->
            value1 < value2
        end
      end

    env = %{env() | session_type: ST.string_to_st("&{?A(float, boolean), ?B(number, float)}")}
    result = typecheck(ast, env)
    assert result[:state] == :error
    # assert result[:state] == :ok
    # assert result[:type] == :boolean
    # assert result[:session_type] == %ST.Terminate{}

    ast =
      quote do
        value = true

        new_value =
          receive do
            {:A, othervalue} ->
              othervalue
          end

        new_value
      end

    env = %{env() | session_type: ST.string_to_st("&{?A(number)}")}
    result = typecheck(ast, env)
    assert result[:state] == :ok
    assert result[:type] == :number
    assert result[:session_type] == %ST.Terminate{}

    ast =
      quote do
        value = true

        new_value =
          receive do
            {:A, othervalue} ->
              othervalue
          end

        value
      end

    env = %{env() | session_type: ST.string_to_st("&{?A(float)}")}
    result = typecheck(ast, env)
    assert result[:state] == :ok
    assert result[:type] == :boolean
    assert result[:session_type] == %ST.Terminate{}
  end

  test "receive & send" do
    ast =
      quote do
        a = 4

        receive do
          {:hello, value} ->
            x = not value
            a = a < 4
            send(self(), {:abc, a, x})
        end

        a
      end

    env = %{env() | session_type: ST.string_to_st("?hello(boolean).!abc(boolean, boolean)")}
    result = typecheck(ast, env)
    assert result[:type] == :number
    assert result[:state] == :ok
    assert result[:session_type] == %ST.Terminate{}

    ast =
      quote do
        a = 4

        receive do
          {:hello, value} ->
            x = not value
            send(self(), {:abc, a < 4, not value, a + 9.6})
        end
      end

    env = %{env() | session_type: ST.string_to_st("?hello(boolean).!abc(boolean, boolean, number)")}
    result = typecheck(ast, env)
    assert result[:state] == :ok
    assert result[:type] == {:tuple, [:atom, :boolean, :boolean, :number]}
    assert result[:session_type] == %ST.Terminate{}

    ast =
      quote do
        receive do
          {:A} -> :ok
          {:B} -> 7
        end
      end

    env = %{env() | session_type: ST.string_to_st("&{?A(), ?B()}")}
    result = typecheck(ast, env)
    assert result[:state] == :error
  end

  test "case" do
    ast =
      quote do
        a = 4

        case a do
          x when is_number(x) and x > 5 ->
            :ok

          _ ->
            :ok_ok
        end
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:type] == :atom
    assert result[:session_type] == %ST.Terminate{}

    ast =
      quote do
        a = 4

        case a do
          x when is_number(x) and x > 5 ->
            :ok

          _ ->
            9
        end
      end

    result = typecheck(ast)
    assert result[:state] == :error

    ast =
      quote do
        x = 6
        a = send(self(), {:Hello, x})

        case a do
          {:Hello, 8} ->
            7

          {_var, num} ->
            num

          _ ->
            9
        end
      end

    env = %{env() | session_type: ST.string_to_st("!Hello(number)")}
    result = typecheck(ast, env)
    assert result[:state] == :ok
    assert result[:type] == :number
    assert result[:session_type] == %ST.Terminate{}

    ast =
      quote do
        x = 6
        a = send(self(), {:Hello, x})

        case a do
          {:Hello, 8} ->
            send(self(), {:Option1, x})
            x

          {_var, num} ->
            y = x * 2
            a = send(self(), {:Option2, y})
            y

          _ ->
            send(self(), {:Option3, x * 3})
            x * 3
        end

        send(self(), {:Terminate})
      end

    env = %{
      env
      | session_type:
          ST.string_to_st("!Hello(number).+{!Option1(number).!Terminate(), !Option2(number).!Terminate(), !Option3(number).!Terminate()}")
    }

    result = typecheck(ast, env)
    assert result[:state] == :ok
    assert result[:type] == {:tuple, [:atom]}
    assert result[:session_type] == %ST.Terminate{}
  end

  test "if" do
    ast =
      quote do
        x = 7

        y =
          if x do
            :ok
          end

        y
        # y is either an atom or nil
      end

    result = typecheck(ast)
    assert result[:state] == :error

    ast =
      quote do
        x = 7

        if x do
          :ok
        else
          :not_ok
        end
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:type] == :atom
    assert result[:session_type] == %ST.Terminate{}
  end

  def env_function_demo do
    %{
      error_data: nil,
      function_session_type_ctx: %{},
      functions: %{
        {:test_call, 1} => %ST.Function{
          arity: 1,
          bodies: [
            {:__block__, [],
             [
               {{:., [], [:erlang, :send]}, [line: 53], [{:pid, [line: 53], nil}, {:{}, [line: 53], [:B]}]},
               {:receive, [line: 55],
                [
                  [
                    do: [
                      {:->, [line: 56],
                       [
                         [Option1: {:atom, [line: 56], nil}],
                         {:atom, [line: 57], nil}
                       ]},
                      {:->, [line: 59],
                       [
                         [{:{}, [line: 59], [:Option2]}],
                         {:test_call, [line: 60], [{:pid, [line: 60], nil}]}
                       ]}
                    ]
                  ]
                ]}
             ]}
          ],
          case_metas: [[line: 52]],
          cases: 1,
          def_p: :defp,
          guards: [[]],
          meta: [line: 52],
          name: :test_call,
          param_types: [:pid],
          parameters: [[:pid]],
          return_type: :atom,
          types_known?: true
        }
      },
      session_type: %ST.Terminate{},
      state: :ok,
      type: :atom,
      variable_ctx: %{pid: :pid}
    }
  end

  test "function call - recursion" do
    # test_call/1 has session type: rec X.(!B()&{?Option1(atom), ?Option2().X})

    # @spec test_call(pid) :: :atom
    # defp test_call(pid) do
    #   send(pid, {:B})

    #   receive do
    #     {:Option1, atom} ->
    #       atom

    #     {:Option2} ->
    #       test_call(pid)
    #   end
    # end

    ast =
      quote do
        pid = self()

        send(pid, {:A})

        test_call(pid)
      end

    env = %{env_function_demo() | session_type: ST.string_to_st("!A().rec X.(!B()&{?Option1(atom), ?Option2().X})")}
    result = typecheck(ast, env)
    assert result[:state] == :ok
    assert result[:type] == :atom
    assert result[:session_type] == %ST.Terminate{}
  end

  describe "session type with tuples and lists" do
    test "tuples" do
      ast =
        quote do
          receive do
            {:A, {a, b}} -> a + b
            {:B} -> 7
          end
        end

      env = %{env() | session_type: ST.string_to_st("&{?A({number, number}), ?B()}")}
      result = typecheck(ast, env)
      assert result[:state] == :ok
      assert result[:type] == :number
      assert result[:session_type] == %ST.Terminate{}
    end

    test "tuples 2" do
      ast =
        quote do
          receive do
            {:A, {a, {b, {c, d}}}} -> a + b + c + d
            {:B} -> 7
          end
        end

      env = %{env() | session_type: ST.string_to_st("&{?A({number, {number, {number, number}}}), ?B()}")}
      result = typecheck(ast, env)
      assert result[:state] == :ok
      assert result[:type] == :number
      assert result[:session_type] == %ST.Terminate{}
    end

    test "lists" do
      ast =
        quote do
          receive do
            {:A, a} -> 9
            {:B} -> 7
          end
        end

      env = %{env() | session_type: ST.string_to_st("&{?A([number]), ?B()}")}
      result = typecheck(ast, env)
      assert result[:state] == :ok
      assert result[:type] == :number
      assert result[:session_type] == %ST.Terminate{}
    end

    test "lists + tuples" do
      ast =
        quote do
          receive do
            {:A, {a, b}} -> a + 2
            {:B} -> 7
          end
        end

      env = %{env() | session_type: ST.string_to_st("&{?A({number, [number]}), ?B()}")}
      result = typecheck(ast, env)
      assert result[:state] == :ok
      assert result[:type] == :number
      assert result[:session_type] == %ST.Terminate{}
    end

    test "tuples (send)" do
      ast =
        quote do
          a = 4
          send(self(), {:A, {a, 44}})
          :ok
        end

      env = %{env() | session_type: ST.string_to_st("!A({number, number})")}
      result = typecheck(ast, env)
      assert result[:state] == :ok
      assert result[:type] == :atom
      assert result[:session_type] == %ST.Terminate{}
    end

    test "tuples 2 (send)" do
      ast =
        quote do
          a = 5
          b = 9
          c = 12
          d = 3.3
          send(self(), {:A, {a, {b, {c, d}}}})
          :ok
        end

      env = %{env() | session_type: ST.string_to_st("!A({number, {number, {number, number}}})")}
      result = typecheck(ast, env)
      assert result[:state] == :ok
      assert result[:type] == :atom
      assert result[:session_type] == %ST.Terminate{}
    end

    # test "lists (send)" do
    #   ast =
    #     quote do
    #       a = [1]
    #       send(self(), {:A, a})
    #       :ok
    #     end

    #   env = %{env() | session_type: ST.string_to_st("!A([number])")}
    #   result = typecheck(ast, env)
    #   assert result[:error_data] == nil
    #   assert result[:state] == :ok
    #   assert result[:type] == :atom
    #   assert result[:session_type] == %ST.Terminate{}
    # end

    # test "lists + tuples (send)" do
    #   ast =
    #     quote do
    #       send(self(), {:A, {a, b}})
    #       :ok
    #     end

    #   env = %{env() | session_type: ST.string_to_st("!A({number, [number]})")}
    #   result = typecheck(ast, env)
    #   assert result[:error_data] == nil
    #   assert result[:state] == :ok
    #   assert result[:type] == :atom
    #   assert result[:session_type] == %ST.Terminate{}
    # end
  end

  describe "session type with tuples and lists - failure" do
    test "tuples" do
      ast =
        quote do
          receive do
            {:A, a, b} -> a + b
            {:B} -> 7
          end
        end

      env = %{env() | session_type: ST.string_to_st("&{?A({number, number}), ?B()}")}
      result = typecheck(ast, env)
      assert result[:state] == :error
    end

    test "tuples 2" do
      ast =
        quote do
          receive do
            {:A, {a, {b, {c, d}}}} -> a + b + c + d
            {:B} -> 7
          end
        end

      env = %{env() | session_type: ST.string_to_st("&{?A({number, {number, number}}), ?B()}")}
      result = typecheck(ast, env)
      assert result[:state] == :error
    end

    test "lists" do
      ast =
        quote do
          receive do
            {:A, {a}} -> 9
            {:B} -> 7
          end
        end

      env = %{env() | session_type: ST.string_to_st("&{?A([number]), ?B()}")}
      result = typecheck(ast, env)
      assert result[:state] == :error
    end

    test "lists + tuples" do
      ast =
        quote do
          receive do
            {:A, {[a], b}} -> 2
            {:B} -> 7
          end
        end

      env = %{env() | session_type: ST.string_to_st("&{?A({number, [number]}), ?B()}")}
      result = typecheck(ast, env)
      assert result[:state] == :error
    end
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
