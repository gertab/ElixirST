defmodule ElixirSessions.TypeOperations do
  @moduledoc """
  Operations related to expression typing
  """
  # List of accepted types in session types
  # todo maybe add maps, list
  @types [
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
  ]

  @doc """
  Returns a list of all accepted types, including :number, :integer, :atom, ...
  """
  @spec accepted_types :: [atom]
  def accepted_types() do
    @types
  end

  # Extended list of types accepted by Elixir
  @all_types [
    :any,
    :atom,
    :binary,
    :bitstring,
    :boolean,
    :exception,
    :float,
    :function,
    :integer,
    :list,
    :map,
    nil,
    :number,
    :pid,
    :port,
    :reference,
    :struct,
    :tuple,
    :string
  ]

  @spec all_types :: [atom]
  def all_types() do
    @all_types
  end

  @doc """
    Give types in @spec format, returns usable types.
    Accepts: any, atom, binary, boolean, float, integer, nil, number, pid, string, no_return, [] and {}
  """
  @spec spec_get_type(any) :: atom | {:list, list} | {:tuple, list}
  def spec_get_type({type, _, _}) when type in @types do
    type
  end

  def spec_get_type({:{}, _, types}), do: {:tuple, Enum.map(types, &spec_get_type/1)}

  def spec_get_type({type, _, _}) when type not in @types do
    :error
  end

  def spec_get_type(type) when is_list(type), do: {:list, Enum.map(type, &spec_get_type/1)}

  def spec_get_type(type) when is_tuple(type),
    do: {:tuple, Enum.map(Tuple.to_list(type), &spec_get_type/1)}

  def spec_get_type(type) when is_atom(type), do: type
  def spec_get_type(type) when is_binary(type), do: :binary
  def spec_get_type(type) when is_boolean(type), do: :boolean
  def spec_get_type(type) when is_float(type), do: :float
  def spec_get_type(type) when is_integer(type), do: :integer
  def spec_get_type(type) when is_nil(type), do: nil
  def spec_get_type(type) when is_number(type), do: :number
  def spec_get_type(type) when is_pid(type), do: :pid
  def spec_get_type(_), do: :error


  @doc """
  Returns the name of the quoted variable or nil in case of an underscore at the beginning.
  """
  @spec get_var(any) :: any
  def get_var({var, _, _}) when is_atom(var) do
    name = Atom.to_string(var)
    init = String.at(name, 0)
    if init == "_" do
      nil
    else
      var
    end
  end
  def get_var(_) do
    nil
  end

  def typeof(value) when is_number(value), do: :number
  def typeof(value) when is_atom(value), do: value
  def typeof(value) when is_binary(value), do: :binary
  def typeof(value) when is_boolean(value), do: :boolean
  def typeof(value) when is_float(value), do: :float
  def typeof(value) when is_integer(value), do: :integer
  def typeof(value) when is_nil(value), do: nil
  def typeof(value) when is_pid(value), do: :pid
  def typeof(_), do: :error

  # Is type1 a subtype of type2
  def subtype?(type, type), do: true
  def subtype?(type1, :atom) when is_atom(type1), do: true
  def subtype?(:integer, :number), do: true
  def subtype?(:integer, :float), do: true
  def subtype?(:float, :number), do: true
  def subtype?(type1, type2) when is_tuple(type1) and is_tuple(type2) do
    Enum.zip(Tuple.to_list(type1), Tuple.to_list(type2))
    |> Enum.reduce(fn {left, right}, acc -> acc and subtype?(left, right) end)
  end
  def subtype?([type1], [type2]), do: subtype?(type1, type2)
  def subtype?(_, _), do: false



  @spec type_to_guard(binary) :: :error | binary
  def type_to_guard(type) when is_binary(type) do
    case type do
      "atom" -> "is_atom"
      "binary" -> "is_binary"
      "bitstring" -> "is_bitstring"
      "boolean" -> "is_boolean"
      "exception" -> "is_exception"
      "float" -> "is_float"
      "function" -> "is_function"
      "integer" -> "is_integer"
      "list" -> "is_list"
      "map" -> "is_map"
      "nil" -> "is_nil"
      "number" -> "is_number"
      "pid" -> "is_pid"
      "port" -> "is_port"
      "reference" -> "is_reference"
      "struct" -> "is_struct"
      "tuple" -> "is_tuple"
      "string" -> "is_binary"
      _ -> :error
    end
  end
end
