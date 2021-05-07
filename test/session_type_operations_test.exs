defmodule ElixirSessionsOperations do
  use ExUnit.Case
  doctest ElixirSessions.Operations

  test "equal simple rec" do
    s1 = "rec X . (X)"
    s2 = "rec X . (X)"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ElixirSessions.Operations.equal?(session1, session2, %{})
    expected = true

    assert actual == expected
  end

  test "equal simple send/recv" do
    s1 = "?Hello() . !Ping(integer)"
    s2 = "?Hello() . !Ping(integer)"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ElixirSessions.Operations.equal?(session1, session2, %{})
    expected = true

    assert actual == expected
  end

  test "not equal simple rec" do
    s1 = "rec X . (Y)"
    s2 = "rec X . (X)"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ElixirSessions.Operations.equal?(session1, session2, %{})
    expected = false

    assert actual == expected
  end

  test "not equal simple send/recv" do
    s1 = "?Hello() . ?Ping(integer)"
    s2 = "?Hello() . !Ping(integer)"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ElixirSessions.Operations.equal?(session1, session2, %{})
    expected = false

    assert actual == expected
  end

  test "not equal simple send - different types" do
    s1 = "?Hello(integer)"
    s2 = "?Hello(atom)"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ElixirSessions.Operations.equal?(session1, session2, %{})
    expected = false

    assert actual == expected
  end

  test "equal branch" do
    s1 = "&{?Hello(integer), ?Hello2(integer, atom)}"
    s2 = "&{?Hello(integer), ?Hello2(integer, atom)}"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ElixirSessions.Operations.equal?(session1, session2, %{})
    expected = true

    assert actual == expected
  end

  test "not equal branch" do
    s1 = "&{?Hello(integer), ?Hello4(integer, atom)}"
    s2 = "&{?Hello(integer), ?Hello2(integer, atom)}"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ElixirSessions.Operations.equal?(session1, session2, %{})
    expected = false

    assert actual == expected
  end

  test "equal choice" do
    s1 = "+{!Hello(integer), !Hello2(integer, atom)}"
    s2 = "+{!Hello(integer), !Hello2(integer, atom)}"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ElixirSessions.Operations.equal?(session1, session2, %{})
    expected = true

    assert actual == expected
  end

  test "not equal choice" do
    s1 = "+{!Hello(integer), !Hello4(integer, atom)}"
    s2 = "+{!Hello(integer), !Hello2(integer, atom)}"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ElixirSessions.Operations.equal?(session1, session2, %{})
    expected = false

    assert actual == expected
  end

  test "equal recursion variable not same" do
    s1 = "rec X.(!Hello().X)"
    s2 = "rec Y.(!Hello().Y)"

    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ElixirSessions.Operations.equal?(session1, session2, %{})
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

    actual = ElixirSessions.Operations.equal?(session1, session2, %{})
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

    actual = ElixirSessions.Operations.equal?(session1, session2, %{})
    expected = false

    assert actual == expected
  end

  test "equality of receive and call rec" do
    s1 = "?B().X"
    s2 = "?B().X"
    session1 = ST.string_to_st(s1)
    session2 = ST.string_to_st(s2)

    actual = ElixirSessions.Operations.equal?(session1, session2, %{})
    expected = true

    assert actual == expected
  end

  test "unfold_current simple" do
    s1 = "rec X.(!A().X)"

    result = "!A().rec X.(!A().X)"

    session1 = ST.string_to_st(s1)
    session_result = ST.string_to_st(result)

    actual = ST.unfold_current(session1)

    assert ST.st_to_string(actual) == ST.st_to_string(session_result)
  end

  test "unfold_current more complex" do
    s1 = "rec X.(!A().+{!B().X, !C().?D().X})"

    result =
      "!A().+{!B().rec X.(!A().+{!B().X, !C().?D().X}), !C().?D().rec X.(!A().+{!B().X, !C().?D().X})}"

    session1 = ST.string_to_st(s1)
    session_result = ST.string_to_st(result)

    actual = ST.unfold_current(session1)

    assert ST.st_to_string(actual) == ST.st_to_string(session_result)
  end

  test "unfold_current more complex - branch" do
    s1 = "rec X.(!A().&{?B().X, ?C().?D().X})"

    result =
      "!A().&{?B().rec X.(!A().&{?B().X, ?C().?D().X}), ?C().?D().rec X.(!A().&{?B().X, ?C().?D().X})}"

    session1 = ST.string_to_st(s1)
    session_result = ST.string_to_st(result)

    actual = ST.unfold_current(session1)

    assert ST.st_to_string(actual) == ST.st_to_string(session_result)
  end

  test "unfold_current rec in rec" do
    s1 = "rec X.(!A().rec Y.(&{?B().X, ?C().Y}))"

    result = "!A().rec Y.(&{?B().rec X.(!A().rec Y.(&{?B().X, ?C().Y})), ?C().Y})"

    session1 = ST.string_to_st(s1)
    session_result = ST.string_to_st(result)

    actual = ST.unfold_current(session1)

    assert ST.st_to_string(actual) == ST.st_to_string(session_result)
  end

  test "unfold_current exception" do
    s1 = "!B().rec X.(!A().X)"

    result = "!A().rec X.(!A().X)"

    session1 = ST.string_to_st(s1)
    session_result = ST.string_to_st(result)

    try do
      ST.unfold_current(session1)
      assert false
    catch
      _ -> assert true
    end
  end

  test "unfold_unknown simple" do
    s1 = "!A().X"
    x_st = "rec X.(!B().X)"

    expected = "!A().rec X.(!B().X)"

    session_type = ST.string_to_st(s1)
    expected_session_type = ST.string_to_st(expected)
    x_session_type = ST.string_to_st(x_st)

    result_session_type = ST.unfold_unknown(session_type, %{:X => x_session_type})

    assert ST.st_to_string(expected_session_type) == ST.st_to_string(result_session_type)
  end

  test "unfold_unknown more complex" do
    s1 = "!A().rec Y(+{!B().X, !C().Y})"
    x_st = "rec X.(!okk().X)"

    expected = "!A().rec Y.(+{!B().rec X.(!okk().X), !C().Y})"

    session_type = ST.string_to_st(s1)
    expected_session_type = ST.string_to_st(expected)
    x_session_type = ST.string_to_st(x_st)

    result_session_type = ST.unfold_unknown(session_type, %{:X => x_session_type})

    assert ST.st_to_string(expected_session_type) == ST.st_to_string(result_session_type)
  end

  test "st_to_string_current complex" do
    s1 =
      "?M220(string).+{!Helo(string).?M250(string).rec X.(+{!MailFrom(string).?M250(string).rec Y.(+{!Data().?M354(string).!Content(string).?M250(string).X, !Quit().?M221(string), !RcptTo(string).?M250(string).Y}), !Quit().?M221(string)}), !Quit().?M221(string)}"

    session1 = ST.string_to_st(s1)

    actual = ElixirSessions.Operations.st_to_string_current(session1)
    expected = "?M220(string)"

    assert actual == expected
  end

  test "st_to_string complex" do
    s1 =
      "?M220(string).+{!Helo(string).?M250(string).rec X.(+{!MailFrom(string).?M250(string).rec Y.(+{!Data().?M354(string).!Content(string).?M250(string).X, !Quit().?M221(string), !RcptTo(string).?M250(string).Y}), !Quit().?M221(string)}), !Quit().?M221(string)}"

    session1 = ST.string_to_st(s1)

    actual = ElixirSessions.Operations.st_to_string(session1)
    expected = s1

    assert actual == expected

    s1 = ""
    expected = "end"
    session1 = ST.string_to_st(s1)

    actual = ElixirSessions.Operations.st_to_string(session1)
    assert actual == expected
    actual = ElixirSessions.Operations.st_to_string_current(session1)
    assert actual == expected
  end

  test "convert to structs semi complex" do
    input =
      {:recurse, :X,
       {:branch,
        [
          {:recv, :Ping, [], {:send, :Pong, [], {:call, :X}}},
          {:recv, :Quit, [], {:terminate}}
        ]}}

    expected = %ST.Recurse{
      body: %ST.Branch{
        branches: %{
          Ping: %ST.Recv{
            label: :Ping,
            next: %ST.Send{
              label: :Pong,
              next: %ST.Call_Recurse{label: :X},
              types: []
            },
            types: []
          },
          Quit: %ST.Recv{label: :Quit, next: %ST.Terminate{}, types: []}
        }
      },
      label: :X
    }

    result = ST.convert_to_structs(input)

    assert result == expected
  end

  test "Comparing session types simple" do
    s1 = "!Hello2(atom, list).!Hello(atom, list).?H11()"

    s2 = "!Hello2(atom, list).!Hello(atom, list)"

    case ST.session_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st("?H11()")
        assert expected_remaining_st == remaining_st

      {:error, _} ->
        assert false
    end
  end

  test "Comparing session types 1 choice" do
    s1 =
      "!Hello2(atom, list).+{!Hello(atom, list).?H11(), !Hello2(atom, list).?H11(), !Hello3(atom, list).?H11()}"

    s2 = "!Hello2(atom, list).!Hello(atom, list)"

    case ST.session_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st("?H11()")
        # throw("#{ST.st_to_string(remaining_st)}")
        assert expected_remaining_st == remaining_st

      {:error, _} ->
        assert false
    end

    s1 =
      "!Hello2(atom, list).+{!Hello(atom, list).?H11(), !Hello2(atom, list).?H11(), !Hello3(atom, list).?H11()}"

    s2 = "!Hello2(atom, list).+{!Hello(atom, list)}"

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
    s1 = "!Hello2(atom, list).&{?Hello(atom, list).?H11(), ?Hello2(atom, list).?H11()}"

    s2 = "!Hello2(atom, list).?Hello(atom, list)"

    case ST.session_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        assert false

      {:error, _} ->
        assert true

      x ->
        throw(x)
    end

    s1 = "!Hello2(atom, list).&{?Hello(atom, list).?H11(), ?Hello2(atom, list).?H11()}"

    s2 = "!Hello2(atom, list).&{?Hello(atom, list), ?Hello2(atom, list)}"

    case ST.session_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st("?H11()")
        # throw("#{ST.st_to_string(remaining_st)}")
        assert expected_remaining_st == remaining_st

      {:error, _} ->
        assert false
    end
  end

  test "Comparing session types recursion - but equal" do
    s1 = "!ok().rec Y.(&{?option1().rec ZZ.(!ok().rec Y.(&{?option1().ZZ, ?option2().Y})), ?option2().Y})"

    s2 = "rec XXX.(!ok().rec Y.(&{?option1().XXX, ?option2().Y}))"

    case ST.session_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st("end")
        # throw("#{ST.st_to_string(remaining_st)}")
        assert expected_remaining_st == remaining_st

      {:error, _} ->
        assert false
    end
  end

  test "Tail subtract session types simple" do
    s1 = "!Hello2(atom, list).!Hello(atom, list).?H11()"
    s2 = "?H11()"

    case ST.session_tail_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st("!Hello2(atom, list).!Hello(atom, list)")
        assert expected_remaining_st == remaining_st

      :error ->
        assert false
    end
  end

  test "Tail subtract session types 1 choice" do
    s1 =
      "!Hello2(atom, list).+{!Hello(atom, list).?H11(), !Hello2(atom, list).?H11(), !Hello3(atom, list).?H11()}"

    s2 = "?H11()"

    expected =
      "!Hello2(atom, list).+{!Hello(atom, list), !Hello2(atom, list), !Hello3(atom, list)}"

    case ST.session_tail_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        expected_remaining_st = ST.string_to_st(expected)
        # throw("#{ST.st_to_string(remaining_st)}")
        assert ST.st_to_string(expected_remaining_st) == ST.st_to_string(remaining_st)

      {:error, x} ->
        assert false
    end

    s1 =
      "!Hello2(atom, list).+{!Hello(atom, list).?H11(), !Hello2(atom, list).?H11(), !Hello3(atom, list).?H11()}"

    s2 = "?H11()"

    expected =
      "!Hello2(atom, list).+{!Hello(atom, list), !Hello2(atom, list), !Hello3(atom, list)}"

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

      {:error, x} ->
        assert false
    end
  end

  test "Tail subtract session types 1 branch fail" do
    s1 = "!A().&{?B().?C(), ?A().?C()}"

    s2 = "?AAA()"

    case ST.session_tail_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
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
      {:ok, remaining_st} ->
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
        # throw("#{ST.st_to_string(remaining_st)}")
        assert ST.st_to_string(expected_remaining_st) == ST.st_to_string(remaining_st)

      {:error, _} ->
        assert false
    end
  end

  ## Duality
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
