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

    expected = [branch: [[{:recv, :neg, [:Number]}], [{:recv, :add, [:Number, :Number]}]]]
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
      {:send, :Hello, [:Integer]},
      {:choice, [[{:send, :neg, [:number, :pid]}, {:recv, :Num, [:Number]}]]}
    ]
    result = Parser.parse(source)
    assert expected == result
  end

    # todo fix
  # test "complex session type" do
  #   source =
  #     "!ABC(any).rec X.(!Hello(any), ?HelloBack(any). rec Y.(!Num(number).rec Z.(Z)))"

  #   expected =
  #      [
  #        {:send, 'any'},
  #        {:recurse, :X,
  #         [
  #           {:send, 'any'},
  #           {:recv, 'any'},
  #           {:recurse, :Y,
  #            [
  #              {:send, '{number}'},
  #              {:recv, '{any}'},
  #              {:recurse, :Z, [call_recurse: :Z]},
  #              {:recv, '{any}'},
  #              {:call_recurse, :Y}
  #            ]},
  #           {:call_recurse, :X}
  #         ]}
  #      ]

  #   result = Parser.parse(source)
  #   assert expected == result
  # end
end
