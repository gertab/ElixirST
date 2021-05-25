defmodule TypeOperationsTest do
  use ExUnit.Case
  doctest ElixirSessions.TypeOperations

  test "small example" do
    {:@, _, [spec]} =
      quote do
        @spec function(integer(), integer()) :: number
      end

    {:spec, _, [{:"::", _, [{_spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.get_type(args_types)
    return_type = ElixirSessions.TypeOperations.get_type(return_type)

    assert args_types == {:list, [:number, :number]}
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

    assert args_types == {:list, [:any, :atom, :binary, :boolean, nil, :number, :pid, :string, :no_return]}
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

    assert args_types == {:list, [:number, {:list, [:number]}]}
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

    assert args_types == {:list, [:number, nil, :atom, :binary]}
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

    assert args_types == {:list, [:number, :boolean, :boolean, :number, nil, :pid, :binary]}
    assert return_type == :atom
  end

  test "edge tuple example" do
    {:@, _, [spec]} =
      quote do
        @spec function({number, number, :ok}) :: :ok
      end

    {:spec, _, [{:"::", _, [{_spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.get_type(args_types)
    return_type = ElixirSessions.TypeOperations.get_type(return_type)

    assert args_types == {:list, [{:tuple, [:number, :number, :atom]}]}
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

  test "equal list" do
    type1 = {:list, [:number]}
    type2 = {:list, [:number]}
    assert ElixirSessions.TypeOperations.equal?(type1, type2) === true
    assert ElixirSessions.TypeOperations.equal?(type2, type1) === true
  end

  test "equal bad" do
    assert ElixirSessions.TypeOperations.equal?(:abc, :number) === false
    assert ElixirSessions.TypeOperations.equal?({:tuple, [:atom]}, {:list, [:abc]}) === false
    assert ElixirSessions.TypeOperations.equal?(:float, :atom) === false
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

  test "to string" do
    types = {:tuple, [:atom, :boolean, :number]}
    string = "{atom, boolean, number}"

    assert ElixirSessions.TypeOperations.string(types) == string

    types = {:tuple, [:atom, :boolean, {:tuple, [:atom, :boolean, :number]}]}
    string = "{atom, boolean, {atom, boolean, number}}"

    assert ElixirSessions.TypeOperations.string(types) == string

    types = {:list, [{:tuple, [:atom, {:tuple, [:atom, :boolean, :number]}, :number]}, :boolean, {:tuple, [:atom, :boolean, :number]}]}
    string = "[{atom, {atom, boolean, number}, number}, boolean, {atom, boolean, number}]"

    assert ElixirSessions.TypeOperations.string(types) == string
  end

  test "valid_type" do
    types = {:tuple, [:atom, :boolean, :number]}

    case ElixirSessions.TypeOperations.valid_type(types) do
      {:error, _} -> assert false
      valid_type -> assert valid_type == types
    end

    types = {:tuple, [:atom, :boolean, {:tuple, [:atom, :boolean, :number]}]}

    case ElixirSessions.TypeOperations.valid_type(types) do
      {:error, _} -> assert false
      valid_type -> assert valid_type == types
    end

    types = {:tuple, [:atom, :boolean, {:tuple, [:atom, :boolean, {:tuple, [:atom, :boolean, {:tuple, [:atom, :boolean, :number]}]}]}]}

    case ElixirSessions.TypeOperations.valid_type(types) do
      {:error, _} -> assert false
      valid_type -> assert valid_type == types
    end
  end

  test "valid_type invalid" do
    types = {:tuple, [:abc, :boolean, :number]}

    case ElixirSessions.TypeOperations.valid_type(types) do
      {:error, _} -> assert true
      _ -> assert false
    end

    types = {:list, [:atom, :boolean, {:tuple, [:atom, :boolean, :number]}]}

    case ElixirSessions.TypeOperations.valid_type(types) do
      {:error, _} -> assert true
      _ -> assert false
    end

    types = {:abc, [:number]}

    case ElixirSessions.TypeOperations.valid_type(types) do
      {:error, _} -> assert true
      _ -> assert false
    end
  end
end
