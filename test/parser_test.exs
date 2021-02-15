defmodule ParserTest do
  use ExUnit.Case
  doctest ElixirSessions.Parser
  alias ElixirSessions.Parser

  test "send session type" do
    source = "send 'any'"

    expected = [send: 'any']
    result = Parser.parse(source)
    assert expected == result
  end

  test "receive session type" do
    source = "receive 'any'"

    expected = [recv: 'any']
    result = Parser.parse(source)
    assert expected == result
  end

  test "simple session type" do
    source = "send '{:ping, pid}' . receive '{:pong}'"

    expected = [send: '{:ping, pid}', recv: '{:pong}']
    result = Parser.parse(source)
    assert expected == result
  end

  test "choice session type" do
    source = "choice<neg: send 'any'>"

    expected = [choice: %{neg: [send: 'any']}]
    result = Parser.parse(source)
    assert expected == result
  end

  test "branch session type" do
    source = "branch<neg: send 'any', neg2: send 'any'>"

    expected = [branch: %{neg: [send: 'any'], neg2: [send: 'any']}]
    result = Parser.parse(source)
    assert expected == result
  end

  test "recurse session type" do
    source = "rec X .(send 'any' . X)"

    expected = [{:recurse, :X, [send: 'any', call_recurse: :X]}]
    result = Parser.parse(source)
    assert expected == result
  end

  test "send receive choicde session type" do
    source = "send '{string}' . choice<neg: send '{number, pid}' . receive '{number}'>"

    expected =
      [send: '{string}', choice: %{neg: [send: '{number, pid}', recv: '{number}']}]

    result = Parser.parse(source)
    assert expected == result
  end

  test "complex session type" do
    source =
      " send 'any'.  rec X ( send 'any' . receive 'any' . rec Y. ( send '{number}' . receive '{any}' . rec Z . ( Z ) . receive '{any}' . Y ) . X )"

    expected =
       [
         {:send, 'any'},
         {:recurse, :X,
          [
            {:send, 'any'},
            {:recv, 'any'},
            {:recurse, :Y,
             [
               {:send, '{number}'},
               {:recv, '{any}'},
               {:recurse, :Z, [call_recurse: :Z]},
               {:recv, '{any}'},
               {:call_recurse, :Y}
             ]},
            {:call_recurse, :X}
          ]}
       ]

    result = Parser.parse(source)
    assert expected == result
  end
end
