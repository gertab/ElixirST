defmodule DualityTest do
  use ExUnit.Case
  doctest ElixirSessions.Duality
  alias ElixirSessions.Duality
  alias ElixirSessions.Parser

  test "send dual" do
    s = "!Hello(any)"

    session = Parser.parse(s)
    actual = %ST.Recv{label: :Hello, next: %ST.Terminate{}, types: [:any]}

    assert Duality.dual(session) == actual
  end

  test "receive dual" do
    s = "?Hello(any)"

    session = Parser.parse(s)
    actual = %ST.Send{label: :Hello, next: %ST.Terminate{}, types: [:any]}

    assert Duality.dual(session) == actual
  end

  test "sequence dual" do
    s = "?Hello(any).?Hello2(any).!Hello3(any)"

    session = Parser.parse(s)

    actual = %ST.Send{
      label: :Hello,
      next: %ST.Send{
        label: :Hello2,
        next: %ST.Recv{label: :Hello3, next: %ST.Terminate{}, types: [:any]},
        types: [:any]
      },
      types: [:any]
    }

    assert Duality.dual(session) == actual
  end

  test "branching choice dual" do
    s = "&{?Neg(number, pid).?Hello(number)}"

    session = Parser.parse(s)

    actual = %ST.Choice{
      choices: [
        %ST.Send{
          label: :Neg,
          next: %ST.Send{label: :Hello, next: %ST.Terminate{}, types: [:number]},
          types: [:number, :pid]
        }
      ]
    }

    assert Duality.dual(session) == actual
  end

  test "sequence and branching choice dual = all need to match (incorrect) dual" do
    s = "!Hello().+{!Neg(number, pid).!Hello(number)}"

    session = Parser.parse(s)

    actual = %ST.Recv{
      label: :Hello,
      next: %ST.Branch{
        branches: [
          %ST.Recv{
            label: :Neg,
            next: %ST.Recv{label: :Hello, next: %ST.Terminate{}, types: [:number]},
            types: [:number, :pid]
          }
        ]
      },
      types: []
    }

    assert Duality.dual(session) == actual
  end

  test "sequence and branching choice dual = all need to match (correct) dual" do
    s = "!Hello().&{?Neg(number, pid).!Hello(number), ?Neg(number, pid).!Hello(number)}"

    session = Parser.parse(s)

    actual = %ST.Recv{
      label: :Hello,
      next: %ST.Choice{
        choices: [
          %ST.Send{
            label: :Neg,
            next: %ST.Recv{label: :Hello, next: %ST.Terminate{}, types: [:number]},
            types: [:number, :pid]
          },
          %ST.Send{
            label: :Neg,
            next: %ST.Recv{label: :Hello, next: %ST.Terminate{}, types: [:number]},
            types: [:number, :pid]
          }
        ]
      },
      types: []
    }

    assert Duality.dual(session) == actual
  end
end
