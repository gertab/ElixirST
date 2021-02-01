defmodule CodeTest do
  use ExUnit.Case
  doctest ElixirSessions.Code
  alias ElixirSessions.Duality
  alias ElixirSessions.Parser
  alias ElixirSessions.Code

  test "send - infer" do

    fun = :ping
    body =
      quote do
        send(pid, {:ping, self()})
      end

    expected_session_type = [send: 'type']
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

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

    expected_session_type = [send: 'type', send: 'type', send: 'type', send: 'type', recv: 'type']
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

    assert inferred_session_type == expected_session_type
  end

  test "atom infer" do

    fun = :ping
    body =
      quote do
        :ok
      end

    expected_session_type = []
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

    assert inferred_session_type == expected_session_type
  end

  test "number infer" do

    fun = :ping
    body =
      quote do
        123
      end

    expected_session_type = []
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

    assert inferred_session_type == expected_session_type
  end

  test "binary infer" do

    fun = :ping
    body =
      quote do
        "binary"
      end

    expected_session_type = []
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

    assert inferred_session_type == expected_session_type
  end


  test "tuple send infer" do

    fun = :ping
    body =
      quote do
        {123, "abc"}
      end

    expected_session_type = []
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

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
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

    assert inferred_session_type == expected_session_type
  end

  test "block items infer" do

    fun = :ping
    body =
      quote do
        send(self(), :ok)
        send(self(), :ok)
        send(self(), :ok)
      end

    expected_session_type = [send: 'type', send: 'type', send: 'type']
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

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
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

    assert inferred_session_type == expected_session_type
  end


  test "pattern matching -  infer" do

    fun = :ping
    body =
      quote do
        {:abc, 123} = send(self(), {:abc, 123})
        {:abc, 123} = send(self(), {:abc, 123})
      end

    expected_session_type = [send: 'type', send: 'type']
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

    assert inferred_session_type == expected_session_type
  end

  test "receive infer" do

    fun = :ping
    body =
      quote do
        send(self(), :okkk)

        receive do
          {:message_type, _value} ->
            send(self(), :okkk)

          {:message_type2, _value} ->
            send(self(), :okkk)
        end
      end

    expected_session_type = [{:send, 'type'}, {:branch, %{message_type: [recv: 'type', send: 'type'], message_type2: [recv: 'type', send: 'type']}}]
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

    assert inferred_session_type == expected_session_type
  end

  test "receive 3 tuple infer" do

    fun = :ping
    body =
      quote do
        send(self(), :okkk)

        receive do
          {:message_type, _value, _other_value} ->
            send(self(), :okkk)

          {:message_type2, _value} ->
            send(self(), :okkk)
        end
      end

    expected_session_type = [{:send, 'type'}, {:branch, %{message_type: [recv: 'type', send: 'type'], message_type2: [recv: 'type', send: 'type']}}]
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

    assert inferred_session_type == expected_session_type
  end

  test "recursion infer" do

    fun = :ping
    body =
      quote do
        send(self(), :okkk)

        ping()
      end

    expected_session_type = [{:recurse, X, [send: 'type', call_recurse: :X]}]
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

    assert inferred_session_type == expected_session_type
  end

  test "pipe infer" do

    fun = :ping
    body =
      quote do
        send(self(), :okkk)
        |> send(self(), :okkk)
        |> send(self(), :okkk)
        |> send(self(), :okkk)

      end

    expected_session_type = [{:send, 'type'}, {:send, 'type'}, {:send, 'type'}, {:send, 'type'}]
    inferred_session_type = ElixirSessions.Code.infer_session_type_incl_recursion(fun, body, expected_session_type)

    assert inferred_session_type == expected_session_type
  end


  test "ensure_send - ok" do

    cases = [[{:send, 'type'}, {:send, 'type'}, {:send, 'type'}], [{:send, 'type'}, {:send, 'type'}, {:send, 'type'}], [{:send, 'type'}, {:send, 'type'}, {:send, 'type'}]]

    result = ElixirSessions.Code.ensure_send(cases)
    expected_result = :ok

    assert result == expected_result
  end

  test "ensure_send - error" do

    cases = [[{:branch, %{message_type: [recv: 'type', send: 'type'], message_type2: [recv: 'type', send: 'type']}}, {:send, 'type'}, {:send, 'type'}], [{:send, 'type'}, {:send, 'type'}, {:send, 'type'}], [{:send, 'type'}, {:send, 'type'}, {:send, 'type'}]]

    result = ElixirSessions.Code.ensure_send(cases)
    expected_result = :error

    assert result == expected_result
  end
end
