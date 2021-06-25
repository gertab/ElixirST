defmodule STTest do
  use ExUnit.Case
  doctest ST

  test "equal simple rec" do
    s1 = "rec X . (X)"
    s2 = "rec X . (X)"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ST.equal?(session1, session2)
    expected = true

    assert actual == expected
  end

  test "equal simple send/recv" do
    s1 = "?Hello() . !Ping(integer)"
    s2 = "?Hello() . !Ping(integer)"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ST.equal?(session1, session2)
    expected = true

    assert actual == expected
  end

  test "not equal simple rec" do
    s1 = "rec X . (Y)"
    s2 = "rec X . (X)"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ST.equal?(session1, session2)
    expected = false

    assert actual == expected
  end

  test "not equal simple send/recv" do
    s1 = "?Hello() . ?Ping(integer)"
    s2 = "?Hello() . !Ping(integer)"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ST.equal?(session1, session2)
    expected = false

    assert actual == expected
  end

  test "not equal simple send - different types" do
    s1 = "?Hello(integer)"
    s2 = "?Hello(atom)"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ST.equal?(session1, session2)
    expected = false

    assert actual == expected
  end

  test "equal branch" do
    s1 = "&{?Hello(integer), ?Hello2(integer, atom)}"
    s2 = "&{?Hello(integer), ?Hello2(integer, atom)}"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ST.equal?(session1, session2)
    expected = true

    assert actual == expected
  end

  test "not equal branch" do
    s1 = "&{?Hello(integer), ?Hello4(integer, atom)}"
    s2 = "&{?Hello(integer), ?Hello2(integer, atom)}"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ST.equal?(session1, session2)
    expected = false

    assert actual == expected
  end

  test "equal choice" do
    s1 = "+{!Hello(integer), !Hello2(integer, atom)}"
    s2 = "+{!Hello(integer), !Hello2(integer, atom)}"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ST.equal?(session1, session2)
    expected = true

    assert actual == expected
  end

  test "not equal choice" do
    s1 = "+{!Hello(integer), !Hello4(integer, atom)}"
    s2 = "+{!Hello(integer), !Hello2(integer, atom)}"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ST.equal?(session1, session2)
    expected = false

    assert actual == expected
  end

  test "equal recursion variable not same" do
    s1 = "rec X.(!Hello().X)"
    s2 = "rec Y.(!Hello().Y)"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ST.equal?(session1, session2)
    expected = true

    assert actual == expected
  end

  test "equal complex" do
    s1 =
      "?M220(string).+{!Helo(string).?M250(string).rec X.(+{!MailFrom(string).?M250(string).rec Y.(+{!Data().?M354(string).!Content(string).?M250(string).X, !Quit().?M221(string), !RcptTo(string).?M250(string).Y}), !Quit().?M221(string)}), !Quit().?M221(string)}"

    s2 =
      "?M220(string).+{!Helo(string).?M250(string).rec X.(+{!MailFrom(string).?M250(string).rec Y.(+{!Data().?M354(string).!Content(string).?M250(string).X, !Quit().?M221(string), !RcptTo(string).?M250(string).Y}), !Quit().?M221(string)}), !Quit().?M221(string)}"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ST.equal?(session1, session2)
    expected = true

    assert actual == expected
  end

  test "not equal complex" do
    s1 =
      "?M220(string).+{!Helo(string).?M250(string).rec X.(+{!MailFrom(string).?M250(string).rec Y.(+{!Data().?M354(string).!Content(string).?M250(string).X, !Quit().?M221(string), !RcptTo(string).?M250(string).Y}), !Quit().?M221(string)}), !Quit().?M221(string)}"

    s2 =
      "?M220(string).+{!Helo(string).?M250(string).rec X.(+{!MailFrom(string).rec Y.(+{!Data().?M354(string).!Content(string).?M250(string).X, !Quit().?M221(string), !RcptTo(string).?M250(string).Y}), !Quit().?M221(string)}), !Quit().?M221(string)}"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ST.equal?(session1, session2)
    expected = false

    assert actual == expected
  end

  test "equality of receive and call rec" do
    s1 = "?B().X"
    s2 = "?B().X"
    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ST.equal?(session1, session2)
    expected = true

    assert actual == expected
  end

  test "unfold simple" do
    s1 = "rec X.(!A().X)"

    result = "!A().rec X.(!A().X)"

    session1 = ST.string_to_st(s1)
    session_result = ST.string_to_st(result)

    actual = ST.unfold(session1)

    assert ST.st_to_string(actual) == ST.st_to_string(session_result)
  end

  test "unfold more complex" do
    s1 = "rec X.(!A().+{!B().X, !C().?D().X})"

    result = "!A().+{!B().rec X.(!A().+{!B().X, !C().?D().X}), !C().?D().rec X.(!A().+{!B().X, !C().?D().X})}"

    session1 = ST.string_to_st(s1)
    session_result = ST.string_to_st(result)

    actual = ST.unfold(session1)

    assert ST.st_to_string(actual) == ST.st_to_string(session_result)
  end

  test "unfold more complex - branch" do
    s1 = "rec X.(!A().&{?B().X, ?C().?D().X})"

    result = "!A().&{?B().rec X.(!A().&{?B().X, ?C().?D().X}), ?C().?D().rec X.(!A().&{?B().X, ?C().?D().X})}"

    session1 = ST.string_to_st(s1)
    session_result = ST.string_to_st(result)

    actual = ST.unfold(session1)

    assert ST.st_to_string(actual) == ST.st_to_string(session_result)
  end

  test "unfold rec in rec" do
    s1 = "rec X.(!A().rec Y.(&{?B().X, ?C().Y}))"

    result = "!A().rec Y.(&{?B().rec X.(!A().rec Y.(&{?B().X, ?C().Y})), ?C().Y})"

    session1 = ST.string_to_st(s1)
    session_result = ST.string_to_st(result)

    actual = ST.unfold(session1)

    assert ST.st_to_string(actual) == ST.st_to_string(session_result)
  end

  test "unfold exception" do
    s1 = "!B().rec X.(!A().X)"

    result = "!B().rec X.(!A().X)"

    session1 = ST.string_to_st(s1)
    session_result = ST.string_to_st(result)

    actual = ST.unfold(session1)

    assert ST.st_to_string(actual) == ST.st_to_string(session_result)
  end

  # todo fix multiple unfolds; unfold
  test "unfold multiple" do
    _s1 = "rec X.(rec Y.(&{?A().X, ?B.Y}))"

    _result = "&{?A().rec X.(rec Y.(&{?A().X, ?B.Y})), ?B.rec Y.(&{?A().X, ?B.Y})}"

    # session1 = ST.string_to_st(s1)
    # session_result = ST.string_to_st(result)

    # actual = ST.unfold(session1)

    # assert ST.st_to_string(actual) == ST.st_to_string(session_result)
  end

  # todo reject recursion without any actions
  test "unfold multiple no infill" do
    s1 = "rec X.(rec Y.(X))"

    # result = "!A().rec X.(!A().X)"

    _session1 = ST.string_to_st(s1)
    # _session_result = ST.string_to_st(result)

    # try do
    #   ST.unfold(session1)
    #   assert false
    # catch
    #   _ -> assert true
    # end
  end

  test "st_to_string_current complex" do
    s1 =
      "?M220(string).+{!Helo(string).?M250(string).rec X.(+{!MailFrom(string).?M250(string).rec Y.(+{!Data().?M354(string).!Content(string).?M250(string).X, !Quit().?M221(string), !RcptTo(string).?M250(string).Y}), !Quit().?M221(string)}), !Quit().?M221(string)}"

    session1 = ST.string_to_st(s1)

    actual = ST.st_to_string_current(session1)
    expected = "?M220(string)"

    assert actual == expected
  end

  test "st_to_string complex" do
    s1 =
      "?M220(string).+{!Helo(string).?M250(string).rec X.(+{!MailFrom(string).?M250(string).rec Y.(+{!Data().?M354(string).!Content(string).?M250(string).X, !Quit().?M221(string), !RcptTo(string).?M250(string).Y}), !Quit().?M221(string)}), !Quit().?M221(string)}"

    session1 = ST.string_to_st(s1)

    actual = ST.st_to_string(session1)
    expected = s1

    assert actual == expected

    s1 = ""
    expected = "end"
    session1 = ST.string_to_st(s1)

    actual = ST.st_to_string(session1)
    assert actual == expected
    actual = ST.st_to_string_current(session1)
    assert actual == expected
  end

  test "st_to_string outer label" do
    s1 = "A = !B().A"

    session1 = ST.string_to_st(s1)

    actual = ST.st_to_string(session1)
    expected = s1

    assert actual == expected

    s1 = "A = !B()"
    expected = "A = !B()"
    session1 = ST.string_to_st(s1)

    actual = ST.st_to_string(session1)
    assert actual == expected
    actual = ST.st_to_string_current(session1)
    assert actual == expected
  end

  test "Comparing session types simple" do
    s1 = "!Hello2(atom, number).!Hello(atom, number).?H11()"

    s2 = "!Hello2(atom, number).!Hello(atom, number)"

    case ST.session_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st("?H11()")
        assert expected_remaining_st == remaining_st

      {:error, _} ->
        assert false
    end
  end

  test "Comparing session types 1 choice" do
    s1 = "!Hello2(atom, number).+{!Hello(atom, number).?H11(), !Hello2(atom, number).?H11(), !Hello3(atom, number).?H11()}"

    s2 = "!Hello2(atom, number).!Hello(atom, number)"

    case ST.session_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st("?H11()")
        # throw("#{ST.st_to_string(remaining_st)}")
        assert expected_remaining_st == remaining_st

      {:error, _} ->
        assert false
    end

    s1 = "!Hello2(atom, number).+{!Hello(atom, number).?H11(), !Hello2(atom, number).?H11(), !Hello3(atom, number).?H11()}"

    s2 = "!Hello2(atom, number).+{!Hello(atom, number)}"

    case ST.session_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st("?H11()")
        # throw("#{ST.st_to_string(remaining_st)}")
        assert expected_remaining_st == remaining_st

      {:error, _} ->
        assert false
    end
  end

  test "Comparing session types 1 branch fail" do
    s1 = "!Hello2(atom, number).&{?Hello(atom, number).?H11(), ?Hello2(atom, number).?H11()}"

    s2 = "!Hello2(atom, number).?Hello(atom, number)"

    case ST.session_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, _remaining_st} ->
        assert false

      {:error, _} ->
        assert true

      x ->
        throw(x)
    end

    s1 = "!Hello2(atom, number).&{?Hello(atom, number).?H11(), ?Hello2(atom, number).?H11()}"

    s2 = "!Hello2(atom, number).&{?Hello(atom, number), ?Hello2(atom, number)}"

    case ST.session_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st("?H11()")
        # throw("#{ST.st_to_string(remaining_st)}")
        assert expected_remaining_st == remaining_st

      {:error, _} ->
        assert false
    end
  end

  test "Tail subtract session types simple" do
    s1 = "!Hello2(atom, number).!Hello(atom, number).?H11()"
    s2 = "?H11()"

    case ST.session_tail_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st("!Hello2(atom, number).!Hello(atom, number)")
        assert expected_remaining_st == remaining_st

      :error ->
        assert false
    end
  end

  test "Tail subtract session types 1 choice" do
    s1 = "!Hello2(atom, number).+{!Hello(atom, number).?H11(), !Hello2(atom, number).?H11(), !Hello3(atom, number).?H11()}"

    s2 = "?H11()"

    expected = "!Hello2(atom, number).+{!Hello(atom, number), !Hello2(atom, number), !Hello3(atom, number)}"

    case ST.session_tail_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st(expected)
        # throw("#{ST.st_to_string(remaining_st)}")
        assert ST.st_to_string(expected_remaining_st) == ST.st_to_string(remaining_st)

      {:error, _x} ->
        assert false
    end

    s1 = "!Hello2(atom, number).+{!Hello(atom, number).?H11(), !Hello2(atom, number).?H11(), !Hello3(atom, number).?H11()}"

    s2 = "?H11()"

    expected = "!Hello2(atom, number).+{!Hello(atom, number), !Hello2(atom, number), !Hello3(atom, number)}"

    case ST.session_tail_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st(expected)
        # throw("#{ST.st_to_string(remaining_st)}")
        assert ST.st_to_string(expected_remaining_st) == ST.st_to_string(remaining_st)

      :error ->
        assert false
    end
  end

  test "Tail subtract session types choice" do
    s1 = "+{!A().X, !B().Y, !C().!ok()}"

    s2 = "!ok()"

    expected = "+{!A().X, !B().Y, !C()}"

    case ST.session_tail_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st(expected)
        assert ST.st_to_string(expected_remaining_st) == ST.st_to_string(remaining_st)

      {:error, _x} ->
        assert false
    end
  end

  test "Tail subtract session types 1 branch fail" do
    s1 = "!A().&{?B().?C(), ?A().?C()}"

    s2 = "?AAA()"

    case ST.session_tail_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, _remaining_st} ->
        assert false

      {:error, _} ->
        # Test should fail. No reduction
        assert true
    end

    s1 = "!A().&{?B().?C(), ?A().?C()}"

    s2 = "?C()"

    case ST.session_tail_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st("!A().&{?B(), ?A()}")
        # throw("#{ST.st_to_string(remaining_st)}")
        assert ST.st_to_string(expected_remaining_st) == ST.st_to_string(remaining_st)

      {:error, _} ->
        assert false
    end
  end

  test "Tail subtract session types empty branch" do
    s1 = "!A().&{?B().?C(), ?A().?C()}"

    s2 = "?B().?C()"

    case ST.session_tail_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, _remaining_st} ->
        assert false

      {:error, _} ->
        # Test should fail, empty branch
        assert true
    end
  end

  test "Tail subtract session types - prolematic - tail is empty" do
    s1 = "?pong().rec X.(?pong().X)"
    s2 = "end"

    case ST.session_tail_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st("end")
        assert ST.st_to_string(expected_remaining_st) == ST.st_to_string(remaining_st)

      {:error, _} ->
        assert false
    end
  end

  describe "Duality" do
    test "send dual" do
      s = "!Hello(any)"
      expected = "?Hello(any)"

      session = ST.string_to_st(s)

      dual = ST.dual(session)
      assert ST.st_to_string(dual) == expected
    end

    test "receive dual" do
      s = "?Hello(any)"
      expected = "!Hello(any)"

      session = ST.string_to_st(s)

      dual = ST.dual(session)
      assert ST.st_to_string(dual) == expected
    end

    test "sequence dual" do
      s = "?Hello(any).?Hello2(any).!Hello3(any)"
      expected = "!Hello(any).!Hello2(any).?Hello3(any)"

      session = ST.string_to_st(s)

      dual = ST.dual(session)
      assert ST.st_to_string(dual) == expected
    end

    test "branching choice dual" do
      s = "&{?Neg(number, pid).?Hello(number)}"
      expected = "+{!Neg(number, pid).!Hello(number)}"

      session = ST.string_to_st(s)

      dual = ST.dual(session)
      assert ST.st_to_string(dual) == expected
    end

    test "sequence and branching choice dual = all need to match (incorrect) dual" do
      s = "!Hello().+{!Neg(number, pid).!Hello(number)}"
      expected = "?Hello().&{?Neg(number, pid).?Hello(number)}"

      session = ST.string_to_st(s)

      dual = ST.dual(session)
      assert ST.st_to_string(dual) == expected
    end

    test "sequence and branching choice dual = all need to match (correct) dual" do
      s = "!Hello().&{?Neg(number, pid).!Hello(number), ?Neg2(number, pid).!Hello(number)}"
      expected = "?Hello().+{!Neg(number, pid).?Hello(number), !Neg2(number, pid).?Hello(number)}"

      session = ST.string_to_st(s)

      dual = ST.dual(session)
      assert ST.st_to_string(dual) == expected
    end

    test "dual?" do
      s1 = "rec X . (?Hello() . +{!Hello(). X, !Hello2(). X})"
      s2 = "rec X . (!Hello() . &{?Hello(). X})"

      session1 = ST.string_to_st(s1)
      session2 = ST.string_to_st(s2)

      actual = ST.dual?(session1, session2)
      expected = false

      assert actual == expected
    end

    test "dual? 2" do
      s1 = "rec X . (?Hello() . +{!Hello(). X})"
      s2 = "rec X . (!Hello() . &{?Hello(). X, ?Hello2(). X})"

      session1 = ST.string_to_st(s1)
      session2 = ST.string_to_st(s2)

      actual = ST.dual?(session1, session2)
      expected = true

      assert actual == expected
    end

    test "dual? complex" do
      s1 =
        "?M220(msg: String).+{ !Helo(hostname: String).?M250(msg: String). rec X.(+{ !MailFrom(addr: String). ?M250(msg: String) . rec Y.(+{ !RcptTo(addr: String).?M250(msg: String).Y, !Data().?M354(msg: String).!Content(txt: String).?M250(msg: String).X, !Quit().?M221(msg: String) }), !Quit().?M221(msg: String)}), !Quit().?M221(msg: String) }"

      session1 = ST.string_to_st(s1)
      session2 = ST.dual(session1)

      actual = ST.dual?(session1, session2)
      expected = true

      assert actual == expected
    end
  end
end
