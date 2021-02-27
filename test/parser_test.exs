defmodule ParserTest do
  use ExUnit.Case
  doctest ElixirSessions.Parser
  alias ElixirSessions.Parser

  test "send session type" do
    source = "!Label(any)"

    expected = [{:send, :Label, [:any]}]
    result = Parser.parse(source)
    assert expected == result
  end

  test "receive session type" do
    source = "?Receive(any)"

    expected = [{:recv, :Receive, [:any]}]
    result = Parser.parse(source)
    assert expected == result
  end

  test "simple session type" do
    source = "!Ping(pid).?Pong()"

    expected = [{:send, :Ping, [:pid]}, {:recv, :Pong, []}]
    result = Parser.parse(source)
    assert expected == result
  end

  test "choice session type" do
    source = "+{!neg(any)}"

    expected = [choice: [[{:send, :neg, [:any]}]]]
    result = Parser.parse(source)
    assert expected == result
  end

  test "branch session type" do
    source = "&{?neg(Number), ?add(Number, Number)}"

    expected = [branch: [[{:recv, :neg, [:number]}], [{:recv, :add, [:number, :number]}]]]
    result = Parser.parse(source)
    assert expected == result
  end

  test "recurse session type" do
    source = "rec X .(!Hello() . X)"

    expected = [{:recurse, :X, [{:send, :Hello, []}, {:call_recurse, :X}]}]
    result = Parser.parse(source)
    assert expected == result
  end

  test "send receive choicde session type" do
    source = "!Hello(Integer).+{!neg(number, pid).?Num(Number)}"

    expected = [
      {:send, :Hello, [:integer]},
      {:choice, [[{:send, :neg, [:number, :pid]}, {:recv, :Num, [:number]}]]}
    ]

    result = Parser.parse(source)
    assert expected == result
  end

  # todo fix
  test "complex session type" do
    source = "!ABC(any).rec X.(!Hello(any) . ?HelloBack(any) . rec Y.(!Num(number).rec Z.(Z)))"

    expected = [
      {:send, :ABC, [:any]},
      {:recurse, :X,
       [
         {:send, :Hello, [:any]},
         {:recv, :HelloBack, [:any]},
         {:recurse, :Y, [{:send, :Num, [:number]}, {:recurse, :Z, [call_recurse: :Z]}]}
       ]}
    ]

    result = Parser.parse(source)
    assert expected == result
  end
end
