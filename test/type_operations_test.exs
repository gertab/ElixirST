defmodule TypeOperationsTest do
  use ExUnit.Case
  doctest ElixirSessions.TypeOperations

  test "small example" do
    {:@, _, [spec]} =
      quote do
        @spec function(integer, integer()) :: number
      end

    {:spec, _, [{:"::", _, [{_spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.get_type(args_types)
    return_type = ElixirSessions.TypeOperations.get_type(return_type)

    assert args_types == {:list, [:integer, :integer]}
    assert return_type == :number
  end

  test "all accepted example" do
    {:@, _, [spec]} =
      quote do
        @spec function(
                any,
                atom,
                binary,
                boolean,
                float,
                integer,
                nil,
                number,
                pid,
                string,
                no_return
              ) :: any
      end

    {:spec, _, [{:"::", _, [{_spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.get_type(args_types)
    return_type = ElixirSessions.TypeOperations.get_type(return_type)

    assert args_types == {:list, [:any, :atom, :binary, :boolean, :float, :integer, nil, :number, :pid, :string, :no_return]}
    assert return_type == :any
  end

  test "list/tuple example" do
    {:@, _, [spec]} =
      quote do
        @spec function(integer, [integer]) :: {number}
      end

    {:spec, _, [{:"::", _, [{_spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.get_type(args_types)
    return_type = ElixirSessions.TypeOperations.get_type(return_type)

    assert args_types == {:list, [:integer, {:list, [:integer]}]}
    assert return_type == {:tuple, [:number]}
  end

  test "literal example" do
    {:@, _, [spec]} =
      quote do
        @spec function(78, nil, :abc, "hello") :: :ok
      end

    {:spec, _, [{:"::", _, [{_spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.get_type(args_types)
    return_type = ElixirSessions.TypeOperations.get_type(return_type)

    assert args_types == {:list, [:integer, nil, :atom, :binary]}
    assert return_type == :atom
  end

  test "further literals example" do
    {:@, _, [spec]} =
      quote do
        @spec function(7676.4, true, false, 78, nil, pid, "hello") :: :ok
      end

    {:spec, _, [{:"::", _, [{_spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.get_type(args_types)
    return_type = ElixirSessions.TypeOperations.get_type(return_type)

    assert args_types == {:list, [:float, :boolean, :boolean, :integer, nil, :pid, :binary]}
    assert return_type == :atom
  end

  test "edge tuple example" do
    {:@, _, [spec]} =
      quote do
        @spec function({number, integer, :ok}) :: :ok
      end

    {:spec, _, [{:"::", _, [{_spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.get_type(args_types)
    return_type = ElixirSessions.TypeOperations.get_type(return_type)

    assert args_types == {:list, [{:tuple, [:number, :integer, :atom]}]}
    assert return_type == :atom
  end

  test "error type" do
    {:@, _, [spec]} =
      quote do
        @spec function(abc) :: number
      end

    {:spec, _, [{:"::", _, [{__spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.get_type(args_types)
    return_type = ElixirSessions.TypeOperations.get_type(return_type)

    assert args_types == {:list, [:error]}
    assert return_type == :number
  end

  test "subtype? atom 1" do
    type1 = :atom
    type2 = :atom
    assert ElixirSessions.TypeOperations.subtype?(type1, type2) === true
    assert ElixirSessions.TypeOperations.subtype?(type2, type1) === true
    assert ElixirSessions.TypeOperations.greatest_lower_bound(type2, type1) === :atom
  end

  test "subtype? atom 2" do
    type1 = :atom
    type2 = :atom
    assert ElixirSessions.TypeOperations.subtype?(type1, type2) === true
    assert ElixirSessions.TypeOperations.subtype?(type2, type1) === true
    assert ElixirSessions.TypeOperations.greatest_lower_bound(type2, type1) === :atom
  end

  test "subtype? number 1" do
    type1 = :integer
    type2 = :number
    assert ElixirSessions.TypeOperations.subtype?(type1, type2) === true
    assert ElixirSessions.TypeOperations.subtype?(type2, type1) === false
    assert ElixirSessions.TypeOperations.greatest_lower_bound(type2, type1) === :number
  end

  test "subtype? number 2" do
    type1 = :integer
    type2 = :float
    assert ElixirSessions.TypeOperations.subtype?(type1, type2) === true
    assert ElixirSessions.TypeOperations.subtype?(type2, type1) === false
    assert ElixirSessions.TypeOperations.greatest_lower_bound(type2, type1) === :float
  end

  test "subtype? number 3" do
    type1 = :float
    type2 = :number
    assert ElixirSessions.TypeOperations.subtype?(type1, type2) === true
    assert ElixirSessions.TypeOperations.subtype?(type2, type1) === false
    assert ElixirSessions.TypeOperations.greatest_lower_bound(type2, type1) === :number
  end

  test "subtype? tuple" do
    type1 = {:tuple, [:atom, :integer, :atom]}
    type2 = {:tuple, [:atom, :integer, :atom]}
    assert ElixirSessions.TypeOperations.subtype?(type1, type2) === true
    assert ElixirSessions.TypeOperations.subtype?(type2, type1) === true

    assert ElixirSessions.TypeOperations.greatest_lower_bound(type2, type1) ===
             {:tuple, [:atom, :integer, :atom]}
  end

  test "subtype? list" do
    type1 = {:list, [:number]}
    type2 = {:list, [:number]}
    assert ElixirSessions.TypeOperations.subtype?(type1, type2) === true
    assert ElixirSessions.TypeOperations.subtype?(type2, type1) === true
    assert ElixirSessions.TypeOperations.greatest_lower_bound(type2, type1) === {:list, [:number]}
  end

  test "subtype? list - maybe todo remove" do
    type1 = {:list, [:atom, :integer, :atom]}
    type2 = {:list, [:atom, :integer, :atom]}
    assert ElixirSessions.TypeOperations.subtype?(type1, type2) === true
    assert ElixirSessions.TypeOperations.subtype?(type2, type1) === true

    assert ElixirSessions.TypeOperations.greatest_lower_bound(type2, type1) ===
             {:list, [:atom, :integer, :atom]}
  end

  test "subtype? bad" do
    assert ElixirSessions.TypeOperations.subtype?(:abc, :number) === false
    assert ElixirSessions.TypeOperations.subtype?({:tuple, [:atom]}, {:list, [:abc]}) === false
    assert ElixirSessions.TypeOperations.subtype?(:float, :atom) === false
    assert ElixirSessions.TypeOperations.greatest_lower_bound(:abc, :number) === :error

    assert ElixirSessions.TypeOperations.greatest_lower_bound({:tuple, [:atom]}, {:list, [:abc]}) ===
             :error

    assert ElixirSessions.TypeOperations.greatest_lower_bound(:float, :atom) === :error
  end

  test "greatest lower bound list" do
    assert ElixirSessions.TypeOperations.greatest_lower_bound([:integer, :number, :float]) ==
             :number

    assert ElixirSessions.TypeOperations.greatest_lower_bound([
             {:integer, :number, :float},
             {:number, :integer, :integer}
           ]) == :error

    assert ElixirSessions.TypeOperations.greatest_lower_bound([
             {:tuple, [:integer, :number, :float]},
             {:tuple, [:number, :integer, :integer]}
           ]) == {:tuple, [:number, :number, :float]}
  end

  test "var_pattern" do
    a = [{:{}, [line: 74], [:A, {:_value, [line: 74], nil}, {:_value2, [line: 74], nil}]}]
    b = [{:tuple, [:atom, :boolean, :number]}]

    assert ElixirSessions.TypeOperations.var_pattern(a, b) == %{
             _value: :boolean,
             _value2: :number
           }

    a = [
      quote do
        {:dn, y, z}
      end
    ]

    b = [{:tuple, [:atom, :number, :float]}]
    assert ElixirSessions.TypeOperations.var_pattern(a, b) == %{y: :number, z: :float}
  end
end
