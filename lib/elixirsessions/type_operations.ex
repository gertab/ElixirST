defmodule ElixirSessions.TypeOperations do
  @moduledoc """
  Operations related to expression typing
  """
  # @spec types :: [
  #         :atom
  #         | :binary
  #         | :bitstring
  #         | :boolean
  #         | :exception
  #         | :float
  #         | :function
  #         | :integer
  #         | :list
  #         | :map
  #         | nil
  #         | :number
  #         | :pid
  #         | :port
  #         | :reference
  #         | :struct
  #         | :tuple
  #         | :string
  #       ]

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

  # @all_ty pes
  # [
  #   :any,
  #   :atom,
  #   :binary,
  #   :bitstring,
  #   :boolean,
  #   :exception,
  #   :float,
  #   :function,
  #   :integer,
  #   :list,
  #   :map,
  #   nil,
  #   :number,
  #   :pid,
  #   :port,
  #   :reference,
  #   :struct,
  #   :tuple,
  #   :string
  # ]


  @doc """
    Give types in @spec format, returns usable types.
    Accepts: any, atom, binary, boolean, float, integer, nil, number, pid, string, no_return, [] and {}
    todo maybe add maps
  """
  @spec spec_get_type(any) :: atom | {:list, list} | {:tuple, list}
  def spec_get_type({type, _, _})
      when type in [
             :any,
             :atom,
             :binary,
             :boolean,
             :float,
             :integer,
             :nil,
             :number,
             :pid,
             :string,
             :no_return
           ] do
    type
  end
  def spec_get_type({:{}, _, types}), do: {:tuple, Enum.map(types, &spec_get_type/1)}
  def spec_get_type(type) when is_list(type), do: {:list, Enum.map(type, &spec_get_type/1)}
  def spec_get_type(type) when is_tuple(type), do: {:tuple, Enum.map(Tuple.to_list(type), &spec_get_type/1)}
  def spec_get_type(type) when is_atom(type), do: type
  def spec_get_type(type) when is_binary(type), do: :binary
  def spec_get_type(type) when is_boolean(type), do: :boolean
  def spec_get_type(type) when is_float(type), do: :float
  def spec_get_type(type) when is_integer(type), do: :integer
  def spec_get_type(type) when is_nil(type), do: :nil
  def spec_get_type(type) when is_number(type), do: :number
  def spec_get_type(type) when is_pid(type), do: :pid
  def spec_get_type(_), do: :error
end
