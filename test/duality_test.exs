defmodule DualityTest do
  use ExUnit.Case
  doctest ElixirSessions.Duality
  alias ElixirSessions.Duality
  alias ElixirSessions.Parser

  # test "send dual?" do
  #   s1 = "!Hello(any)"
  #   s2 = "?Hello(any)"

  #   session1 = Parser.parse(s1)
  #   session2 = Parser.parse(s2)

  #   assert Duality.dual?(session1, session2) == true
  # end

  # test "receive dual?" do
  #   s1 = "receive 'any'"
  #   s2 = "send 'any'"

  #   session1 = Parser.parse(s1)
  #   session2 = Parser.parse(s2)

  #   assert Duality.dual?(session1, session2) == true
  # end

  # test "sequence dual?" do
  #   s1 = "send 'any' . send 'any' . receive 'any'"
  #   s2 = "receive 'any' . receive 'any' . send 'any'"

  #   session1 = Parser.parse(s1)
  #   session2 = Parser.parse(s2)

  #   assert Duality.dual?(session1, session2) == true
  # end

  # test "branching choice dual?" do
  #   s1 = "branch<neg: receive '{number, pid}' . send '{number}'>"
  #   s2 = "choice<neg: send '{number, pid}' . receive '{number}'>"

  #   session1 = Parser.parse(s1)
  #   session2 = Parser.parse(s2)

  #   assert Duality.dual?(session1, session2) == true
  # end

  # test "sequence and branching choice dual = all need to match (incorrect) dual?" do
  #   s1 = "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"
  #   s2 = "receive '{label}' "

  #   session1 = Parser.parse(s1)
  #   session2 = Parser.parse(s2)

  #   assert Duality.dual?(session1, session2) == false
  # end

  # test "sequence and branching choice dual = all need to match (correct) dual?" do
  #   s1 = "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"
  #   s2 = "send '{label}' . choice<add: send '{number, number, pid}' . receive '{number}', neg: send '{number, pid}' . receive '{number}'>"

  #   session1 = Parser.parse(s1)
  #   session2 = Parser.parse(s2)

  #   assert Duality.dual?(session1, session2) == true
  # end

  # # test "duality of recursive types" do

  # #   s1 = "rec X .(send 'any' . X)"
  # #   s2 = "receive 'any' . receive 'any' . receive 'any' . receive 'any'"

  # #   session1 = Parser.parse(s1)
  # #   session2 = Parser.parse(s2)

  # #   assert Duality.dual?(session1, session2) == true
  # # end


  test "send dual" do
    s = "!Hello(any)"

    session = Parser.parse(s)
    actual = [{:recv, :Hello, [:any]}]

    assert Duality.dual(session) == actual
  end

  test "receive dual" do
    s = "?Hello(any)"

    session = Parser.parse(s)
    actual = [{:send, :Hello, [:any]}]

    assert Duality.dual(session) == actual
  end

  test "sequence dual" do
    s = "?Hello(any).?Hello2(any).!Hello3(any)"

    session = Parser.parse(s)
    actual = [{:send, :Hello, [:any]}, {:send, :Hello2, [:any]}, {:recv, :Hello3, [:any]}]

    assert Duality.dual(session) == actual
  end

  test "branching choice dual" do
    s = "&{?Neg(number, pid).?Hello(number)}"

    session = Parser.parse(s)
    actual = [choice: [[{:send, :Neg, [:number, :pid]}, {:send, :Hello, [:number]}]]]

    assert Duality.dual(session) == actual
  end

  test "sequence and branching choice dual = all need to match (incorrect) dual" do
    s = "!Hello().+{!Neg(number, pid).!Hello(number)}"

    session = Parser.parse(s)
    actual = [
      {:recv, :Hello, []},
      {:branch, [[{:recv, :Neg, [:number, :pid]}, {:recv, :Hello, [:number]}]]}
    ]
    assert Duality.dual(session) == actual
  end

  test "sequence and branching choice dual = all need to match (correct) dual" do
    s = "!Hello().&{?Neg(number, pid).!Hello(number), ?Neg(number, pid).!Hello(number)}"

    session = Parser.parse(s)
    actual = [
      {:recv, :Hello, []},
      {:choice,
       [
         [{:send, :Neg, [:number, :pid]}, {:recv, :Hello, [:number]}],
         [{:send, :Neg, [:number, :pid]}, {:recv, :Hello, [:number]}]
       ]}
    ]

    assert Duality.dual(session) == actual
  end
end
