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
    The type of variables is returned if the environment is configured.
  """
  @spec get_type(any) :: atom | {:list, list} | {:tuple, list}
  def get_type(type) do
    get_type(type, %{})
  end

  @spec get_type(any, %{}) :: atom | {:list, list} | {:tuple, list}
  def get_type({type, _, _}, _env) when type in @types do
    type
  end

  def get_type({:{}, _, types}, env), do: {:tuple, Enum.map(types, &get_type(&1, env))}

  def get_type({variable, _, args}, env) when is_atom(variable) and is_atom(args) do
    if env[:variable_ctx][variable] do
      env[:variable_ctx][variable]
    else
      :error
    end
  end

  def get_type({type, _, _}, _env) when type not in @types do
    :error
  end

  def get_type(type, env) when is_list(type), do: {:list, Enum.map(type, &get_type(&1, env))}

  def get_type(type, env) when is_tuple(type),
    do: {:tuple, Enum.map(Tuple.to_list(type), &get_type(&1, env))}

  def get_type(type, _env) when is_binary(type), do: :binary
  def get_type(type, _env) when is_boolean(type), do: :boolean
  def get_type(type, _env) when is_float(type), do: :float
  def get_type(type, _env) when is_integer(type), do: :integer
  def get_type(type, _env) when is_nil(type), do: nil
  def get_type(type, _env) when is_number(type), do: :number
  def get_type(type, _env) when is_pid(type), do: :pid
  def get_type(type, _env) when is_atom(type), do: type
  def get_type(_, _), do: :error

  @doc """
  Returns the name of the quoted variable or nil in case of an underscore at the beginning.
  """
  @spec get_var(any) :: any
  def get_var({var, _, _}) when is_atom(var) do
    name = Atom.to_string(var)

    if String.at(name, 0) == "_" do
      nil
    else
      var
    end
  end

  def get_var(_) do
    nil
  end

  def typeof(value) when is_nil(value), do: nil
  def typeof(value) when is_boolean(value), do: :boolean
  def typeof(value) when is_integer(value), do: :integer
  def typeof(value) when is_float(value), do: :float
  def typeof(value) when is_number(value), do: :number
  def typeof(value) when is_pid(value), do: :pid
  def typeof(value) when is_binary(value), do: :binary
  def typeof(value) when is_atom(value), do: value
  def typeof(_), do: :error

  # Is type1 a subtype of type2, type1 <: type2?
  # def subtype?(type1, type2) do
  #   case greatest_lower_bound(type1, type2) do
  #     :error -> false
  #     _ -> true
  #   end
  # end

  def subtype?(type1, type2)
  def subtype?(type, type), do: true
  def subtype?(type1, :atom) when is_atom(type1) and type1 not in @types, do: true
  # def subtype?(type1, :atom) when is_atom(type1), do: true # todo not sure
  def subtype?(:integer, :number), do: true
  def subtype?(:integer, :float), do: true
  def subtype?(:float, :number), do: true

  def subtype?({:tuple, type1}, {:tuple, type2}) do
    subtype?(type1, type2)
  end

  def subtype?({:list, type1}, {:list, type2})
      when is_list(type1) and is_list(type2) do
    # todo: either t or [t]; [t1, t2] is not a valid type
    subtype?(type1, type2)
  end

  def subtype?(type1, type2) when is_list(type1) and is_list(type2) do
    result =
      Enum.zip(type1, type2)
      |> Enum.map(fn {left, right} -> subtype?(left, right) end)

    not Enum.member?(result, false)
  end

  def subtype?(_, :any), do: true
  def subtype?(_, _), do: false

  def greatest_lower_bound(types) when is_list(types) do
    Enum.reduce_while(types, hd(types), fn type, acc ->
      case greatest_lower_bound(type, acc) do
        :error -> {:halt, :error}
        x -> {:cont, x}
      end
    end)
  end

  # todo add any

  def greatest_lower_bound(type1, type2)
  def greatest_lower_bound(type, type), do: type
  def greatest_lower_bound(type1, :atom) when is_atom(type1) and type1 not in @types, do: :atom
  def greatest_lower_bound(:atom, type2) when is_atom(type2) and type2 not in @types, do: :atom
  # def greatest_lower_bound(type1, :atom) when is_atom(type1), do: true # todo not sure
  def greatest_lower_bound(:integer, :number), do: :number
  def greatest_lower_bound(:number, :integer), do: :number
  def greatest_lower_bound(:integer, :float), do: :float
  def greatest_lower_bound(:float, :integer), do: :float
  def greatest_lower_bound(:float, :number), do: :number
  def greatest_lower_bound(:number, :float), do: :number

  def greatest_lower_bound({:tuple, type1}, {:tuple, type2}) do
    case greatest_lower_bound(type1, type2) do
      :error ->
        :error

      inner ->
        {:tuple, inner}
    end
  end

  def greatest_lower_bound({:list, type1}, {:list, type2})
      when is_list(type1) and is_list(type2) do
    # todo: either t or [t]; [t1, t2] is not a valid type
    case greatest_lower_bound(type1, type2) do
      :error ->
        :error

      inner ->
        {:list, inner}
    end
  end

  def greatest_lower_bound(type1, type2) when is_list(type1) and is_list(type2) do
    result =
      Enum.zip(type1, type2)
      |> Enum.map(fn {left, right} -> greatest_lower_bound(left, right) end)

    if Enum.member?(result, :error) do
      :error
    else
      result
    end
  end

  def greatest_lower_bound(type1, type2)
      when is_atom(type1) and is_atom(type2) and type1 not in @types and type2 not in @types,
      do: :atom

  def greatest_lower_bound(type, :any), do: type
  def greatest_lower_bound(:any, type), do: type
  def greatest_lower_bound(_, _), do: :error

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

  def var_pattern(params, param_type_list) when is_list(params) and is_list(param_type_list) do
    if length(params) != length(param_type_list) do
      {:error, "Incorrectly sized parameters/types"}
    else
      new_vars =
        Enum.zip(params, param_type_list)
        |> Enum.map(fn {var, type} -> get_vars(var, type) end)
        |> List.flatten()

      case new_vars[:error] do
        nil ->
          Enum.reduce_while(new_vars, %{}, fn {var, type}, acc ->
            t = Map.get(acc, var)

            cond do
              t === nil or t === type -> {:cont, Map.put(acc, var, type)}
              true -> {:halt, {:error, "Variable #{var} is already defined with type #{t}"}}
            end
          end)

        message ->
          # {:error, message}
          {:error, message <> ": Expected " <> inspect(param_type_list) <> ", but found " <> Macro.to_string(params)}
      end
    end
  end

  # var is the quoted part of the lhs in a binding operation (i.e. =)
  defp get_vars(var, type)
  defp get_vars(_, :any), do: []
  defp get_vars({op, _, _}, type) when op not in [:{}, :%{}, :=, :_, :|], do: {op, type}
  defp get_vars({:_, _, _}, _type), do: []

  defp get_vars({:=, _, [_arg1, _arg2]}, _),
    do: {:error, "'=' is not supported"}

  defp get_vars([], {:list, _type}), do: []

  defp get_vars(op, {:list, type}) when is_list(op),
    do: Enum.map(op, fn x -> get_vars(x, type) end)

  defp get_vars({:|, _, [operand1, operand2]}, {:list, type}),
    do: [get_vars(operand1, type), get_vars(operand2, {:list, type})]

  defp get_vars(_, {:list, _}), do: {:error, "Incorrect type specification"}

  defp get_vars([], _), do: {:error, "Incorrect type specification"}

  defp get_vars({:|, _, _}, _), do: {:error, "Incorrect type specification"}

  defp get_vars({:%{}, _, op}, {:map, {_, value_types}}),
    do:
      Enum.zip(op, value_types)
      |> Enum.map(fn {{_, value}, value_type} -> get_vars(value, value_type) end)

  defp get_vars({:%{}, _, _}, _), do: {:error, "Incorrect type specification"}

  defp get_vars(_, {:map, {_, _}}), do: {:error, "Incorrect type specification"}

  defp get_vars({:{}, _, ops}, {:tuple, type_list}), do: get_vars_tuple(ops, type_list)

  defp get_vars(ops, {:tuple, type_list}) when is_tuple(ops),
    do: get_vars_tuple(Tuple.to_list(ops), type_list)

  defp get_vars({:{}, _, _}, _), do: {:error, "Incorrect type specification"}

  defp get_vars(_, {:tuple, _}), do: {:error, "Incorrect type specification"}

  defp get_vars(value, type) when type in @types or is_atom(type) do
    # (is_atom(value) and type == :atom)
    literal =
      (is_nil(value) and type == nil) or
        (is_boolean(value) and type == :boolean) or
        (is_integer(value) and type == :integer) or
        (is_float(value) and type == :float) or
        (is_number(value) and type == :number) or
        (is_pid(value) and type == :pid) or
        (is_binary(value) and type == :binary) or
        (is_atom(value) and subtype?(type, :atom))

    if literal do
      []
    else
      {:error, "Incorrect type specification"}
    end
  end

  defp get_vars(_, _), do: {:error, "Incorrect type specification"}

  defp get_vars_tuple(ops, type_list) do
    if length(ops) === length(type_list),
      do: Enum.zip(ops, type_list) |> Enum.map(fn {var, type} -> get_vars(var, type) end),
      else: {:error, "The number of parameters in tuple does not match the number of types"}
  end
end
