defmodule CodeTest do
  use ExUnit.Case
  doctest ElixirSessions.Inference

  test "send - infer" do
    fun = :ping

    body =
      quote do
        send(pid, {:ping, self()})
      end

    expected_session_type = [{:send, :ping, [:any]}]

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "send send send send receive - infer" do
    fun = :ping

    body =
      quote do
        send(pid, {:ping, self()})
        send(pid, {:ping, self()})
        send(pid, {:ping, self()})
        send(pid, {:ping, self()})

        receive do
          {:valie, _value} ->
            :ok
        end
      end

    expected_session_type = [
      {:send, :ping, [:any]},
      {:send, :ping, [:any]},
      {:send, :ping, [:any]},
      {:send, :ping, [:any]},
      {:recv, :valie, [:any]}
    ]

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "atom infer" do
    fun = :ping

    body =
      quote do
        :ok
      end

    expected_session_type = []

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "number infer" do
    fun = :ping

    body =
      quote do
        123
      end

    expected_session_type = []

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "binary infer" do
    fun = :ping

    body =
      quote do
        "binary"
      end

    expected_session_type = []

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "tuple send infer" do
    fun = :ping

    body =
      quote do
        {123, "abc"}
      end

    expected_session_type = []

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "list two items infer" do
    fun = :ping

    body =
      quote do
        123
        :ok
      end

    expected_session_type = []

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "block items infer" do
    fun = :ping

    body =
      quote do
        send(self(), {:label1, :ok})
        send(self(), {:label2, :ok})
        send(self(), {:label3, :ok})
      end

    expected_session_type = [
      {:send, :label1, [:any]},
      {:send, :label2, [:any]},
      {:send, :label3, [:any]}
    ]

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "case - no send/receive -  infer" do
    fun = :ping

    body =
      quote do
        a = 4

        case a do
          x when is_number(x) -> :ok
          _ -> :not_ok
        end
      end

    expected_session_type = []

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "pattern matching -  infer" do
    fun = :ping

    body =
      quote do
        {:abc, 123} = send(self(), {:abc, 123})
        {:abc, 123} = send(self(), {:abc, 123})
      end

    expected_session_type = [{:send, :abc, [:any]}, {:send, :abc, [:any]}]

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "receive infer" do
    fun = :ping

    body =
      quote do
        send(self(), {:okkk})

        receive do
          {:message_type, _value} ->
            send(self(), {:label1, :okkk})

          {:message_type2, _value} ->
            send(self(), {:label2, :okkk})
        end
      end

    expected_session_type = [
      {:send, :okkk, []},
      {:branch,
       [
         [{:recv, :message_type, [:any]}, {:send, :label1, [:any]}],
         [{:recv, :message_type2, [:any]}, {:send, :label2, [:any]}]
       ]}
    ]

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "receive 3 tuple infer" do
    fun = :ping

    body =
      quote do
        send(self(), {:okkk})

        receive do
          {:message_type, _value, _other_value} ->
            send(self(), {:okkk})

          {:message_type2, _value} ->
            send(self(), {:okkk})
        end
      end

    expected_session_type = [
      {:send, :okkk, []},
      {:branch,
       [
         [{:recv, :message_type, [:any, :any, :any]}, {:send, :okkk, []}],
         [{:recv, :message_type2, [:any]}, {:send, :okkk, []}]
       ]}
    ]

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "receive 1 case infer" do
    fun = :ping

    body =
      quote do
        receive do
          {:ping, pid} ->
            IO.puts(
              "Received ping from #{inspect(pid)}. Replying pong from #{inspect(self())} to #{
                inspect(pid)
              }"
            )

            send(pid, {:pong})
        end
      end

    expected_session_type = [{:recv, :ping, [:any]}, {:send, :pong, []}]

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "recursion infer" do
    fun = :ping

    body =
      quote do
        send(self(), {:okkk})

        ping()
      end

    expected_session_type = [{:recurse, :X, [{:send, :okkk, []}, {:call_recurse, :X}]}]

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "pipe infer" do
    fun = :ping

    body =
      quote do
        send(self(), {:okkk})
        |> send(self(), {:okkk})
        |> send(self(), {:okkk})
        |> send(self(), {:okkk})
      end

    expected_session_type = [
      {:send, :okkk, []},
      {:send, :okkk, []},
      {:send, :okkk, []},
      {:send, :okkk, []}
    ]

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "function infer" do
    fun = :ping

    body =
      quote do
        def ping() do
          send(self(), {:ok})
          :done
        end
      end

    expected_session_type = [{:send, :ok, []}]

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "case with no send/receive" do
    fun = :ping

    body =
      quote do
        send(self(), {:okkk})

        a = true

        case a do
          true -> 1 + 3
          false -> 1..3 |> Enum.map(&(&1 * 2))
        end
      end

    expected_session_type = [{:send, :okkk, []}]

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end

  test "ensure_send - ok" do
    cases = [
      [{:send, :ok1, [:any]}, {:send, :ok1, [:any]}, {:send, :ok1, [:any]}],
      [{:send, :ok1, [:any]}, {:send, :ok1, [:any]}, {:send, :ok1, [:any]}],
      [{:send, :ok1, [:any]}, {:send, :ok1, [:any]}, {:send, :ok1, [:any]}]
    ]

    result = ElixirSessions.Inference.ensure_send(cases)
    expected_result = :ok

    assert result == expected_result
  end

  ##

  test "ensure_send - error" do
    cases = [
      [
        {:branch,
         [
           [{:recv, :ok1, [:any]}, {:send, :ok1, [:any]}],
           [{:recv, :ok2, [:any]}, {:send, :ok1, [:any]}]
         ]},
        {:send, :ok1, [:any]}
      ],
      [{:send, :ok1, [:any]}, {:send, :ok1, [:any]}],
      [{:send, :ok1, [:any]}]
    ]

    result = ElixirSessions.Inference.ensure_send(cases)
    expected_result = :error

    assert result == expected_result
  end

  test "receive session type structure not correct" do
    fun = :ping

    body =
      quote do
        send(self(), {:okkk})

        receive do
          {:message_type, _value} ->
            send(self(), {:label1, :okkk})

          {:message_type2, _value} ->
            send(self(), {:label2, :okkk})
        end

        receive do
          {:message_type, _value} ->
            send(self(), {:label1, :okkk})

          {:message_type2, _value} ->
            send(self(), {:label2, :okkk})
        end
      end

    expected_session_type = [
      {:send, :okkk, []},
      {:branch,
       [
         [{:recv, :message_type, [:any]}, {:send, :label1, [:any]}],
         [{:recv, :message_type2, [:any]}, {:send, :label2, [:any]}]
       ]},
      {:branch,
       [
         [{:recv, :message_type, [:any]}, {:send, :label1, [:any]}],
         [{:recv, :message_type2, [:any]}, {:send, :label2, [:any]}]
       ]}
    ]

    inferred_session_type = ElixirSessions.Inference.infer_session_type_incl_recursion(fun, body)

    assert inferred_session_type == expected_session_type
  end
end
