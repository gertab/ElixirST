defmodule ParserTest do
  use ExUnit.Case
  doctest ElixirSessions.Parser
  alias ElixirSessions.Parser
  alias STEx.ST

  test "send session type" do
    source = "!Label(any)"

    expected = %ST.Send{label: :Label, next: %ST.Terminate{}, types: [:any]}
    result = Parser.parse(source)
    assert expected == result
  end

  test "receive session type" do
    source = "?Receive(any)"

    expected = %ST.Recv{label: :Receive, next: %ST.Terminate{}, types: [:any]}
    result = Parser.parse(source)
    assert expected == result
  end

  test "simple session type" do
    source = "!Ping(pid).?Pong()"

    expected = %ST.Send{label: :Ping, next: %ST.Recv{label: :Pong, next: %ST.Terminate{}, types: []}, types: [:pid]}
    result = Parser.parse(source)
    assert expected == result
  end

  test "choice session type" do
    source = "+{!neg(any)}"

    expected = %ST.Choice{choices: %{neg: %ST.Send{label: :neg, next: %ST.Terminate{}, types: [:any]}}}
    result = Parser.parse(source)
    assert expected == result
  end

  test "branch session type" do
    source = "&{?neg(Number), ?add(Number, Number)}"

    expected = %ST.Branch{
      branches: %{
        add: %ST.Recv{label: :add, next: %ST.Terminate{}, types: [:number, :number]},
        neg: %ST.Recv{label: :neg, next: %ST.Terminate{}, types: [:number]}
      }
    }

    result = Parser.parse(source)
    assert expected == result
  end

  test "recurse session type" do
    source = "rec X .(!Hello() . X)"

    expected = %ST.Recurse{body: %ST.Send{label: :Hello, next: %ST.Call_Recurse{label: :X}, types: []}, label: :X}
    result = Parser.parse(source)
    assert expected == result
  end

  test "send receive choicde session type" do
    source = "!Hello(Number).+{!neg(number, pid).?Num(Number)}"

    expected = %ST.Send{
      label: :Hello,
      types: [:number],
      next: %ST.Choice{
        choices: %{neg: %ST.Send{label: :neg, next: %ST.Recv{label: :Num, next: %ST.Terminate{}, types: [:number]}, types: [:number, :pid]}}
      }
    }

    result = Parser.parse(source)
    assert expected == result
  end

  test "send tuples / lists" do
    source = "!Hello(atom, {Number}, [boolean]).+{!neg(number, pid).?Num(Number)}"

    expected = %ST.Send{
      label: :Hello,
      types: [:atom, {:tuple, [:number]}, {:list, :boolean}],
      next: %ST.Choice{
        choices: %{neg: %ST.Send{label: :neg, next: %ST.Recv{label: :Num, next: %ST.Terminate{}, types: [:number]}, types: [:number, :pid]}}
      }
    }

    result = Parser.parse(source)
    assert expected == result
  end

  test "send tuples within lists" do
    source = "!Hello(atom, {Number, atom, atom})"

    expected = %ST.Send{label: :Hello, next: %ST.Terminate{}, types: [:atom, {:tuple, [:number, :atom, :atom]}]}

    result = Parser.parse(source)
    assert expected == result

    source = "!Hello([{atom, atom, atom}], {atom, [Number], {atom, atom, atom}})"

    expected = %ST.Send{
      label: :Hello,
      types: [{:list, {:tuple, [:atom, :atom, :atom]}}, {:tuple, [:atom, {:list, :number}, {:tuple, [:atom, :atom, :atom]}]}],
      next: %ST.Terminate{}
    }

    result = Parser.parse(source)
    assert expected == result
  end

  test "complex session type" do
    source = "!ABC(any).rec X.(!Hello(any) . ?HelloBack(any) . rec Y.(!Num(number).rec Z.(Z)))"

    expected = %ST.Send{
      label: :ABC,
      next: %ST.Recurse{
        body: %ST.Send{
          label: :Hello,
          next: %ST.Recv{
            label: :HelloBack,
            next: %ST.Recurse{
              body: %ST.Send{label: :Num, next: %ST.Recurse{body: %ST.Call_Recurse{label: :Z}, label: :Z}, types: [:number]},
              label: :Y
            },
            types: [:any]
          },
          types: [:any]
        },
        label: :X
      },
      types: [:any]
    }

    result = Parser.parse(source)
    assert expected == result
  end

  # todo reject recursion without any actions
  test "cannot have multiple recursions next to each other" do
    source = "rec X.(rec Y.(X))"

    try do
      ElixirSessions.Parser.parse(source)
      assert false
    catch
      _ -> assert true
    end

    source = "X = rec Y.(X)"

    try do
      ElixirSessions.Parser.parse(source)
      assert false
    catch
      _ -> assert true
    end
  end

  test "recurse with outer label" do
    source = "server = !A().server"

    expected = %ST.Recurse{
      body: %ST.Send{
        label: :A,
        next: %ST.Call_Recurse{
          label: :server
        },
        types: []
      },
      label: :server,
      outer_recurse: true
    }

    result = Parser.parse(source)
    assert expected == result
  end

  test "no recurse with outer label" do
    source = "server = !A().end"

    expected = %ST.Recurse{label: :server, body: %ST.Send{label: :A, types: [], next: %ST.Terminate{}}, outer_recurse: true}

    result = Parser.parse(source)
    assert expected == result
  end

  test "validation no error - choice" do
    source = "!Hello(Integer).+{!neg(number, pid).?Num(Number), !other_option(number, pid).?Num(Number)}"

    try do
      ElixirSessions.Parser.parse(source)
      assert true
    catch
      _ -> assert false
    end
  end

  test "validation no error - branch" do
    source = "!Hello(Integer).&{?neg(number, pid).?Num(Number), ?other_option(number, pid).?Num(Number)}"

    try do
      ElixirSessions.Parser.parse(source)
      assert true
    catch
      _ -> assert false
    end
  end

  test "validation same label error - branch" do
    source = "!Hello(Integer).&{?neg(number, pid).?Num(Number), ?neg(number, pid).?Num(Number)}"

    try do
      ElixirSessions.Parser.parse(source)
      assert false
    catch
      _ -> assert true
    end
  end

  test "validation error - choice" do
    source = "!Hello(Integer).+{?neg(number, pid).?Num(Number), !neg2(number, pid).?Num(Number)}"

    try do
      ElixirSessions.Parser.parse(source)
      assert false
    catch
      _ -> assert true
    end
  end

  test "validation error - branch" do
    source = "!Hello(Integer).&{!neg1(number, pid).?Num(Number), ?neg2(number, pid).?Num(Number)}"

    try do
      ElixirSessions.Parser.parse(source)
      assert false
    catch
      _ -> assert true
    end
  end

  test "validation error - tuple/lists" do
    source = "!Hello(atom, {}, [abc]).+{!neg(number, pid).?Num(Number)}"

    try do
      ElixirSessions.Parser.parse(source)
      assert false
    catch
      _ -> assert true
    end

    source = "!Hello(atom, {boolean}, [abc]).+{!neg(number, pid).?Num(Number)}"

    try do
      assert false == ElixirSessions.Parser.parse(source)
      assert false
    catch
      _ -> assert true
    end
  end

  test "session type to string" do
    source =
      "?M220(string).+{!Helo(string).?M250(string).rec X.(+{!MailFrom(string).?M250(string).rec Y.(+{!Data().?M354(string).!Content(string).?M250(string).X, !Quit().?M221(string), !RcptTo(string).?M250(string).Y}), !Quit().?M221(string)}), !Quit().?M221(string)}"

    st = ElixirSessions.Parser.parse(source)

    assert ST.st_to_string(st) == source
  end
end
