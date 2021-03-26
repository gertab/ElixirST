defmodule DualityTest do
  use ExUnit.Case
  doctest ElixirSessions.Duality
  alias ElixirSessions.Duality
  alias ElixirSessions.Parser

  test "send dual" do
    s = "!Hello(any)"
    expected = "?Hello(any)"

    session = ST.string_to_st(s)

    dual = Duality.dual(session)
    assert ST.st_to_string(dual) == expected
  end

  test "receive dual" do
    s = "?Hello(any)"
    expected = "!Hello(any)"

    session = ST.string_to_st(s)

    dual = Duality.dual(session)
    assert ST.st_to_string(dual) == expected
  end

  test "sequence dual" do
    s = "?Hello(any).?Hello2(any).!Hello3(any)"
    expected = "!Hello(any).!Hello2(any).?Hello3(any)"

    session = ST.string_to_st(s)

    dual = Duality.dual(session)
    assert ST.st_to_string(dual) == expected
  end

  test "branching choice dual" do
    s = "&{?Neg(number, pid).?Hello(number)}"
    expected = "+{!Neg(number, pid).!Hello(number)}"

    session = ST.string_to_st(s)

    dual = Duality.dual(session)
    assert ST.st_to_string(dual) == expected
  end

  test "sequence and branching choice dual = all need to match (incorrect) dual" do
    s = "!Hello().+{!Neg(number, pid).!Hello(number)}"
    expected = "?Hello().&{?Neg(number, pid).?Hello(number)}"

    session = ST.string_to_st(s)

    dual = Duality.dual(session)
    assert ST.st_to_string(dual) == expected
  end

  test "sequence and branching choice dual = all need to match (correct) dual" do
    s = "!Hello().&{?Neg(number, pid).!Hello(number), ?Neg2(number, pid).!Hello(number)}"
    expected = "?Hello().+{!Neg(number, pid).?Hello(number), !Neg2(number, pid).?Hello(number)}"

    session = ST.string_to_st(s)

    dual = Duality.dual(session)
    assert ST.st_to_string(dual) == expected
  end

  test "dual?" do
    s1 = "rec X . (?Hello() . +{!Hello(). X, !Hello2(). X})"
    s2 = "rec X . (!Hello() . &{?Hello(). X})"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ElixirSessions.Duality.dual?(session1, session2)
    expected = false

    assert actual == expected
  end

  test "dual? 2" do
    s1 = "rec X . (?Hello() . +{!Hello(). X})"
    s2 = "rec X . (!Hello() . &{?Hello(). X, ?Hello2(). X})"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ElixirSessions.Duality.dual?(session1, session2)
    expected = true

    assert actual == expected
  end

  test "dual? complex" do
    s1 =
      "?M220(msg: String).+{ !Helo(hostname: String).?M250(msg: String). rec X.(+{ !MailFrom(addr: String). ?M250(msg: String) . rec Y.(+{ !RcptTo(addr: String).?M250(msg: String).Y, !Data().?M354(msg: String).!Content(txt: String).?M250(msg: String).X, !Quit().?M221(msg: String) }), !Quit().?M221(msg: String)}), !Quit().?M221(msg: String) }"

    session1 = ST.string_to_st(s1)
    session2 = ST.dual(session1)

    actual = ElixirSessions.Duality.dual?(session1, session2)
    expected = true

    assert actual == expected
  end
end
