defmodule TypeOperationsTest do
  use ExUnit.Case
  doctest ElixirSessions.TypeOperations

  test "small example" do
    {:@, _, [spec]} =
      quote do
        @spec function(integer, integer()) :: number
      end

    {:spec, _, [{:"::", _, [{spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.spec_get_type(args_types)
    return_type = ElixirSessions.TypeOperations.spec_get_type(return_type)

    assert args_types == {:list, [:integer, :integer]}
    assert return_type == :number
  end

  test "all accepted example" do
    {:@, _, [spec]} =
      quote do
        @spec function(
                :any,
                :atom,
                :binary,
                :boolean,
                :float,
                :integer,
                nil,
                :number,
                :pid,
                :string,
                :no_return
              ) :: :any
      end

    {:spec, _, [{:"::", _, [{spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.spec_get_type(args_types)
    return_type = ElixirSessions.TypeOperations.spec_get_type(return_type)

    assert args_types == {:list, [:any, :atom, :binary, :boolean, :float, :integer, nil, :number, :pid, :string, :no_return]}
    assert return_type == :any
  end

  test "list/tuple example" do
    {:@, _, [spec]} =
      quote do
        @spec function(integer, [integer]) :: {number}
      end

    {:spec, _, [{:"::", _, [{spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.spec_get_type(args_types)
    return_type = ElixirSessions.TypeOperations.spec_get_type(return_type)

    assert args_types == {:list, [:integer, {:list, [:integer]}]}
    assert return_type == {:tuple, [:number]}
  end

  test "literal example" do
    {:@, _, [spec]} =
      quote do
        @spec function(78, nil, :abc, "hello") :: :ok
      end

    {:spec, _, [{:"::", _, [{spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.spec_get_type(args_types)
    return_type = ElixirSessions.TypeOperations.spec_get_type(return_type)

    assert args_types == {:list, [:integer, nil, :abc, :binary]}
    assert return_type == :ok
  end

  test "further literals example" do
    {:@, _, [spec]} =
      quote do
        @spec function(7676.4, true, :false, 78, nil, pid, "hello") :: :ok
      end

    {:spec, _, [{:"::", _, [{spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.spec_get_type(args_types)
    return_type = ElixirSessions.TypeOperations.spec_get_type(return_type)

    assert args_types == {:list, [:float, true, false, :integer, nil, :pid, :binary]}
    assert return_type == :ok
  end


  test "edge tuple example" do
    {:@, _, [spec]} =
      quote do
        @spec function({number, integer, :ok}) :: :ok
      end

    {:spec, _, [{:"::", _, [{spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.spec_get_type(args_types)
    return_type = ElixirSessions.TypeOperations.spec_get_type(return_type)

    assert args_types == {:list, [{:tuple, [:number, :integer, :ok]}]}
    assert return_type == :ok
  end

  test "error type" do
    {:@, _, [spec]} =
      quote do
        @spec function(abc) :: number
      end

    {:spec, _, [{:"::", _, [{spec_name, _, args_types}, return_type]}]} = spec

    args_types = ElixirSessions.TypeOperations.spec_get_type(args_types)
    return_type = ElixirSessions.TypeOperations.spec_get_type(return_type)

    assert args_types == {:list, [:error]}
    assert return_type == :number
  end

end
