defmodule DualityTest do
  use ExUnit.Case
  doctest ElixirSessions.Duality
  alias ElixirSessions.Duality
  alias ElixirSessions.Parser

  test "send dual" do
    s1 = "send 'any'"
    s2 = "receive 'any'"

    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    assert Duality.dual?(session1, session2) == true
  end

  test "receive dual" do
    s1 = "receive 'any'"
    s2 = "send 'any'"

    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    assert Duality.dual?(session1, session2) == true
  end

  test "sequence dual" do
    s1 = "send 'any' . send 'any' . receive 'any'"
    s2 = "receive 'any' . receive 'any' . send 'any'"

    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    assert Duality.dual?(session1, session2) == true
  end

  test "branching choice dual" do
    s1 = "branch<neg: receive '{number, pid}' . send '{number}'>"
    s2 = "choice<neg: send '{number, pid}' . receive '{number}'>"

    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    assert Duality.dual?(session1, session2) == true
  end

  test "sequence and branching choice dual = all need to match (incorrect)" do
    s1 = "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"
    s2 = "send '{label}' . choice<neg: send '{number, pid}' . receive '{number}'>"

    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    assert Duality.dual?(session1, session2) == false
  end

  test "sequence and branching choice dual = all need to match (correct)" do
    s1 = "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"
    s2 = "send '{label}' . choice<add: send '{number, number, pid}' . receive '{number}', neg: send '{number, pid}' . receive '{number}'>"

    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    assert Duality.dual?(session1, session2) == true
  end
end
