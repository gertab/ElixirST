defmodule ElixirST.TypeOperations do
  @moduledoc """
  Operations related to expression typing.
  """
  # List of accepted types in session types
  @types [
    :any,
    :atom,
    :binary,
    :boolean,
    :number,
    :pid,
    :string,
    :no_return,
    nil
  ]

  @doc """
  Returns a list of all accepted types, including :number, :atom, ...
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

  @doc false
  @spec all_types :: [atom]
  def all_types() do
    @all_types
  end

  @doc """
    Process types in @spec format and returns usable types.

    Accepts: any, atom, binary, boolean, nil, number, pid, string, no_return, list and tuple
    The type of variables is returned if the environment contains the corresponding type of variable.
  """
  @spec get_type(any) :: atom | {:list, any} | {:tuple, list} | list
  def get_type(type) do
    get_type(type, %{})
  end

  @spec get_type(any, %{}) :: atom | {:list, any} | {:tuple, list} | list
  def get_type(types, env) when is_list(types) do
    Enum.map(types, &get_type_internal(&1, env))
  end

  def get_type(types, env) do
    get_type_internal(types, env)
  end

  defp get_type_internal({type, _, _}, _env) when type in @types do
    type
  end

  defp get_type_internal({type, _, _}, _env) when type in [:integer, :float] do
    # warn
    :number
  end

  defp get_type_internal({:{}, _, types}, env), do: {:tuple, Enum.map(types, &get_type(&1, env))}

  defp get_type_internal({variable, _, args}, env) when is_atom(variable) and is_atom(args) do
    if env[:variable_ctx][variable] do
      env[:variable_ctx][variable]
    else
      :error
    end
  end

  defp get_type_internal({type, _, _}, _env) when type not in @types do
    :error
  end

  defp get_type_internal([], _env), do: {:list, nil}
  defp get_type_internal([type], env), do: {:list, get_type(type, env)}
  # defp get_type_internal(type, env) when is_list(type), do: {:list, Enum.map(type, &get_type(&1, env))}

  defp get_type_internal(type, env) when is_tuple(type),
    do: {:tuple, Enum.map(Tuple.to_list(type), &get_type(&1, env))}

  # or string
  defp get_type_internal(type, _env) when is_binary(type), do: :binary
  defp get_type_internal(type, _env) when is_boolean(type), do: :boolean
  defp get_type_internal(type, _env) when is_nil(type), do: nil
  defp get_type_internal(type, _env) when is_number(type), do: :number
  defp get_type_internal(type, _env) when is_pid(type), do: :pid
  defp get_type_internal(type, _env) when is_atom(type), do: :atom
  defp get_type_internal(_, _), do: :error

  @spec typeof(atom | binary | boolean | :error | nil | number | pid) :: :atom | :binary | :boolean | :error | nil | :number | :pid
  def typeof(value) when is_nil(value), do: nil
  def typeof(value) when is_boolean(value), do: :boolean
  def typeof(value) when is_number(value), do: :number
  def typeof(value) when is_pid(value), do: :pid
  def typeof(value) when is_binary(value), do: :binary
  def typeof(value) when is_atom(value), do: :atom
  def typeof(_), do: :error

  @spec equal?(any, any) :: boolean
  def equal?(type, type), do: true
  def equal?(_, _), do: false

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
          param_type_list = Enum.map(param_type_list, &string/1)
          {:error, message <> ": Expected " <> Enum.join(param_type_list, ", ") <> ", but found " <> Macro.to_string(params)}
      end
    end
  end

  # var is the quoted part of the lhs in a binding operation (i.e. =)
  @spec get_vars(any, atom | {:list, any} | {:tuple, list} | list)
          :: list | {:error, :binary}
  def get_vars(var, type)
  def get_vars(_, :any), do: []
  def get_vars({op, _, _}, type) when op not in [:{}, :%{}, :=, :_, :|], do: {op, type}
  def get_vars({:_, _, _}, _type), do: []
  def get_vars({:=, _, [_arg1, _arg2]}, _), do: {:error, "'=' is not supported"}
  def get_vars([], {:list, _type}), do: []
  def get_vars([{:|, _, [operand1, operand2]}], {:list, type}), do: [get_vars(operand1, type), get_vars(operand2, {:list, type})]
  def get_vars({:|, _, [operand1, operand2]}, {:list, type}), do: [get_vars(operand1, type), get_vars(operand2, {:list, type})]
  def get_vars(op, {:list, type}) when is_list(op), do: Enum.map(op, fn x -> get_vars(x, type) end)
  def get_vars(_, {:list, _}), do: {:error, "Incorrect type specification"}
  def get_vars([], _), do: {:error, "Incorrect type specification"}
  def get_vars({:|, _, _}, _), do: {:error, "Incorrect type specification"}

  def get_vars({:%{}, _, op}, {:map, {_, value_types}}),
    do:
      Enum.zip(op, value_types)
      |> Enum.map(fn {{_, value}, value_type} -> get_vars(value, value_type) end)

  def get_vars({:%{}, _, _}, _), do: {:error, "Incorrect type specification"}
  def get_vars(_, {:map, {_, _}}), do: {:error, "Incorrect type specification"}
  def get_vars({:{}, _, ops}, {:tuple, type_list}), do: get_vars_tuple(ops, type_list)
  def get_vars(ops, {:tuple, type_list}) when is_tuple(ops), do: get_vars_tuple(Tuple.to_list(ops), type_list)
  def get_vars({:{}, _, _}, _), do: {:error, "Incorrect type specification"}
  def get_vars(_, {:tuple, _}), do: {:error, "Incorrect type specification"}

  def get_vars(value, type) when type in @types or is_atom(type) do
    # (is_integer(value) and type == :integer) or
    # (is_float(value) and type == :float) or
    literal =
      (is_nil(value) and type == nil) or
        (is_boolean(value) and type == :boolean) or
        (is_number(value) and type == :number) or
        (is_pid(value) and type == :pid) or
        (is_binary(value) and type == :binary) or
        (is_atom(value) and type == :atom)

    if literal do
      []
    else
      {:error, "Incorrect type specification"}
    end
  end

  def get_vars(_, _), do: {:error, "Incorrect type specification"}

  def get_vars_tuple(ops, type_list) do
    if length(ops) === length(type_list),
      do: Enum.zip(ops, type_list) |> Enum.map(fn {var, type} -> get_vars(var, type) end),
      else: {:error, "The number of parameters in tuple does not match the number of types"}
  end

  def string({:list, types}) when not is_list(types) do
    types = string(types)
    "[" <> types <> "]"
  end

  def string({:tuple, types}) when is_list(types) do
    types = Enum.map(types, &string/1)
    "{" <> Enum.join(types, ", ") <> "}"
  end

  def string(type) when type in @types do
    Atom.to_string(type)
  end

  def string(type) when is_atom(type) do
    "?" <> Atom.to_string(type)
  end

  # Checks if a type is valid
  # Returns correct_type or {:error, incorrect_type}
  def valid_type(type) when is_atom(type) do
    accepted_types = ElixirST.TypeOperations.accepted_types()

    type = if type in [:integer, :float], do: :number, else: type

    if type not in accepted_types do
      {:error, type}
    else
      type
    end
  end

  def valid_type({:tuple, types}) when is_list(types) do
    try do
      checked_types = Enum.map(types, fn x -> valid_type(x) end)

      Enum.each(checked_types, fn
        {:error, incorrect_types} -> throw({:error, incorrect_types})
        _ -> :ok
      end)

      {:tuple, checked_types}
    catch
      {:error, _} = error ->
        error
    end
  end

  def valid_type({:list, type}) when not is_list(type) do
    case valid_type(type) do
      {:error, _} = error ->
        error

      type ->
        {:list, type}
    end
  end

  def valid_type(type) do
    {:error, type}
  end
end
