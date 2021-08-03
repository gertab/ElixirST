defmodule SessionTypecheckingTest do
  use ExUnit.Case
  doctest ElixirSessions.SessionTypechecking
  alias ElixirSessions.SessionTypechecking, as: TC

  setup_all do
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

  test "aaaaaaaaaaaa" do
    ast =
      quote do
        # @session "counter = &{?incr(number).counter,
        # ?stop().!value(number).end}"
        # @spec server(pid, number) :: atom
        # def server(client, tot) do
        abc = true
        tot = 55
        val = 55
        client = self()
        receive do
          {:incr, val} ->
            send(client, {:value, tot + val + abc})

          {:stop} ->
            send(client, {:value, tot})
            :ok
        end

        # end

        # @spec terminate(pid, number) :: atom
        # defp terminate(client, tot) do
        #   send(client, {:value, tot})
        #   :ok
        # end
      end

    env = %{env() | session_type: ST.string_to_st("counter = &{?incr(number).!value(number),?stop().!value(number).end}")}
    result = typecheck(ast, env)
    assert result[:state] == :error
    # IO.inspect(result)

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

    test "simple lists" do
      ast =
        quote do
          a = [1]
          b = [{:abc, 1, true}, {:abc, 55, true}, {:abcs, 23, false}, {:adsddbc, 12, true}]
          c = [{:abc, 1, true}]
          d = b ++ c
          a
        end

      result = typecheck(ast)
      assert result[:state] == :ok
      assert result[:type] == {:list, :number}
      assert result[:session_type] == %ST.Terminate{}

      assert result[:variable_ctx] == %{
               a: {:list, :number},
               b: {:list, {:tuple, [:atom, :number, :boolean]}},
               c: {:list, {:tuple, [:atom, :number, :boolean]}},
               d: {:list, {:tuple, [:atom, :number, :boolean]}}
             }
    end

    test "lists fail" do
      ast =
        quote do
          a = [1, 2]
          b = [true, false]
          c = a ++ b
          a
        end

      result = typecheck(ast)
      assert result[:state] == :error
    end

    test "lists in receive" do
      ast =
        quote do
          a = [1]

          receive do
            {:A, list_of_numbers} ->
              a ++ list_of_numbers
          end
        end

      env = %{env() | session_type: ST.string_to_st("?A([number])")}
      result = typecheck(ast, env)
      assert result[:state] == :ok
      assert result[:type] == {:list, :number}
      assert result[:session_type] == %ST.Terminate{}
    end

    test "lists (send)" do
      ast =
        quote do
          a = [1]
          send(self(), {:A, a})
          :ok
        end

      env = %{env() | session_type: ST.string_to_st("!A([number])")}
      result = typecheck(ast, env)
      assert result[:state] == :ok
      assert result[:type] == :atom
      assert result[:session_type] == %ST.Terminate{}
    end

    test "lists + tuples (send)" do
      ast =
        quote do
          a = [1, 2, 3, 5.3]
          send(self(), {:A, {5, a}})
          :ok
        end

      env = %{env() | session_type: ST.string_to_st("!A({number, [number]})")}
      result = typecheck(ast, env)
      assert result[:error_data] == nil
      assert result[:state] == :ok
      assert result[:type] == :atom
      assert result[:session_type] == %ST.Terminate{}
    end
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

  test "list operations" do
    ast =
      quote do
        a = []
        b = [1]
        c = [1, 2]
        d = [1, 2, 3]
        [e | f] = d
        g = [e | d]
        h = [e > 5, true, false]
        [i | [j | [k | l]]] = d
      end

    result = typecheck(ast)
    assert result[:state] == :ok
    assert result[:error_data] == nil
    assert result[:type] == {:list, :number}
    assert result[:session_type] == %ST.Terminate{}

    assert result[:variable_ctx] == %{
             a: {:list, :any},
             b: {:list, :number},
             c: {:list, :number},
             d: {:list, :number},
             e: :number,
             f: {:list, :number},
             g: {:list, :number},
             h: {:list, :boolean},
             i: :number,
             j: :number,
             k: :number,
             l: {:list, :number}
           }
  end

  test "list receive/send" do
    ast =
      quote do
        receive do
          {:A, [number1 | [number2 | _]]} ->
            send(self(), {:B, [number1 > 5, number2 * 4 >= number1 + 4, true, false]})
        end
      end

    env = %{env() | session_type: ST.string_to_st("?A([number]).!B([boolean])")}
    result = typecheck(ast, env)
    assert result[:error_data] == nil
    assert result[:state] == :ok
    assert result[:type] == {:tuple, [:atom, {:list, :boolean}]}
    assert result[:session_type] == %ST.Terminate{}
  end

  test "send/receive and tuples/lists" do
    ast =
      quote do
        receive do
          {:A, [{number1, [atom1 | _]} | other]} ->
            [{number2, [atom2 | _]} | _] = other
            send(self(), {:B, number1 + number2, atom1})
        end
      end

    env = %{env() | session_type: ST.string_to_st("?A([{number, [atom]}]).!B(number, atom)")}
    result = typecheck(ast, env)
    assert result[:error_data] == nil
    assert result[:state] == :ok
    assert result[:type] == {:tuple, [:atom, :number, :atom]}
    assert result[:session_type] == %ST.Terminate{}
  end
end
