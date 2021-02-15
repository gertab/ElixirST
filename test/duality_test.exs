defmodule DualityTest do
  use ExUnit.Case
  doctest ElixirSessions.Duality
  alias ElixirSessions.Duality
  alias ElixirSessions.Parser

  test "send dual?" do
    s1 = "send 'any'"
    s2 = "receive 'any'"

    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    assert Duality.dual?(session1, session2) == true
  end

  test "receive dual?" do
    s1 = "receive 'any'"
    s2 = "send 'any'"

    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    assert Duality.dual?(session1, session2) == true
  end

  test "sequence dual?" do
    s1 = "send 'any' . send 'any' . receive 'any'"
    s2 = "receive 'any' . receive 'any' . send 'any'"

    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    assert Duality.dual?(session1, session2) == true
  end

  test "branching choice dual?" do
    s1 = "branch<neg: receive '{number, pid}' . send '{number}'>"
    s2 = "choice<neg: send '{number, pid}' . receive '{number}'>"

    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    assert Duality.dual?(session1, session2) == true
  end

  test "sequence and branching choice dual = all need to match (incorrect) dual?" do
    s1 = "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"
    s2 = "receive '{label}' "

    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    assert Duality.dual?(session1, session2) == false
  end

  test "sequence and branching choice dual = all need to match (correct) dual?" do
    s1 = "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"
    s2 = "send '{label}' . choice<add: send '{number, number, pid}' . receive '{number}', neg: send '{number, pid}' . receive '{number}'>"

    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    assert Duality.dual?(session1, session2) == true
  end

  # test "duality of recursive types" do

  #   s1 = "rec X .(send 'any' . X)"
  #   s2 = "receive 'any' . receive 'any' . receive 'any' . receive 'any'"

  #   session1 = Parser.parse(s1)
  #   session2 = Parser.parse(s2)

  #   assert Duality.dual?(session1, session2) == true
  # end


  test "send dual" do
    s = "send 'any'"

    session = Parser.parse(s)
    actual = [recv: 'any']

    assert Duality.dual(session) == actual
  end

  test "receive dual" do
    s = "receive 'any'"

    session = Parser.parse(s)
    actual = [send: 'any']

    assert Duality.dual(session) == actual
  end

  test "sequence dual" do
    s = "send 'any' . send 'any' . receive 'any'"

    session = Parser.parse(s)
    actual = [recv: 'any', recv: 'any', send: 'any']

    assert Duality.dual(session) == actual
  end

  test "branching choice dual" do
    s = "branch<neg: receive '{number, pid}' . send '{number}'>"

    session = Parser.parse(s)
    actual = [choice: %{neg: [send: '{number, pid}', recv: '{number}']}]

    assert Duality.dual(session) == actual
  end

  test "sequence and branching choice dual = all need to match (incorrect) dual" do
    s = "send '{label}' . choice<neg: send '{number, pid}' . receive '{number}'>"

    session = Parser.parse(s)
    actual = [recv: '{label}', branch: %{neg: [recv: '{number, pid}', send: '{number}']}]
    assert Duality.dual(session) == actual
  end

  test "sequence and branching choice dual = all need to match (correct) dual" do
    s = "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"

    session = Parser.parse(s)
    actual = [send: '{label}', choice: %{add: [send: '{number, number, pid}', recv: '{number}'], neg: [send: '{number, pid}', recv: '{number}']}]

    assert Duality.dual(session) == actual
  end
end
