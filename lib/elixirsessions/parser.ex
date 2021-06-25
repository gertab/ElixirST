defmodule ElixirSessions.Parser do
  @moduledoc """
    Parses an input string to session types (as Elixir data).
  """
  require Logger
  require ST

  @typedoc false
  @type session_type :: ST.session_type()
  @typep session_type_tuple() :: ST.session_type_tuple()
  @typep label :: ST.label()

  @doc """
  Parses a string into a session type data structure

  ## Example
      iex> s = "rec Y.(+{!Hello(number, [{boolean, atom}]).Y, !Ok()})"
      ...> session_type = ElixirSessions.Parser.parse(s)
      ...> ST.st_to_string(session_type)
      "rec Y.(+{!Hello(number, [{boolean, atom}]).Y, !Ok()})"
  """
  @spec parse(bitstring() | charlist()) :: session_type()
  def parse(string) when is_bitstring(string) do
    st =
      string
      |> String.to_charlist()
      |> parse()

    validate!(st)
    st
  end

  def parse(string) do
    with {:ok, tokens, _} <- lexer(string) do
      if tokens == [] do
        # Empty input
        %ST.Terminate{}
      else
        case :parser.parse(tokens) do
          {:ok, session_type} ->
            convert_to_structs(session_type, [])

          {:error, errors} ->
            throw("Error while parsing session type #{inspect(string)}: " <> inspect(errors))
        end
      end
    else
      {:error, {_line, :lexer, error}, 1} ->
        # todo: cuter error message needed
        throw("Error in syntax of the session type " <> inspect(string) <> ". Found " <> inspect(error))
        []
    end
  end

  defp lexer(string) do
    # IO.inspect tokens
    :lexer.string(string)
  end

  # Convert session types from Erlang records to Elixir Structs.
  # Throws error in case of branches/choices with same labels, or
  # if the types are not valid.
  @spec convert_to_structs(
          # should be { , , [atom], }
          {:send, atom, any, session_type_tuple()}
          | {:recv, atom, any, session_type_tuple()}
          | {:choice, [session_type_tuple()]}
          | {:branch, [session_type_tuple()]}
          | {:call, atom}
          | {:recurse, atom, session_type_tuple(), boolean()}
          | {:terminate},
          [label()]
        ) :: session_type()
  defp convert_to_structs(session_type, recurse_var)

  defp convert_to_structs({:terminate}, _recurse_var) do
    %ST.Terminate{}
  end

  defp convert_to_structs({send_recv, label, types, next}, recurse_var) when send_recv in [:send, :recv] do
    checked_types = Enum.map(types, &ElixirSessions.TypeOperations.valid_type/1)

    Enum.each(checked_types, fn
      {:error, incorrect_types} -> throw("Invalid type/s: #{inspect(incorrect_types)}")
      _ -> :ok
    end)

    case send_recv do
      :send ->
        %ST.Send{label: label, types: checked_types, next: convert_to_structs(next, recurse_var)}

      :recv ->
        %ST.Recv{label: label, types: checked_types, next: convert_to_structs(next, recurse_var)}
    end
  end

  defp convert_to_structs({:choice, choices}, recurse_var) do
    %ST.Choice{
      choices:
        Enum.reduce(
          choices,
          %{},
          fn choice, map ->
            converted_st = convert_to_structs(choice, recurse_var)
            label = label(converted_st)

            if Map.has_key?(map, label) do
              throw("Cannot insert multiple choices with same label: #{label}.")
            else
              Map.put(map, label, converted_st)
            end
          end
        )
    }
  end

  defp convert_to_structs({:branch, branches}, recurse_var) do
    %ST.Branch{
      branches:
        Enum.reduce(
          branches,
          %{},
          fn branch, map ->
            converted_st = convert_to_structs(branch, recurse_var)
            label = label(converted_st)

            if Map.has_key?(map, label) do
              throw("Cannot insert multiple branches with same label: #{label}.")
            else
              Map.put(map, label, converted_st)
            end
          end
        )
    }
  end

  defp convert_to_structs({:recurse, label, body, outer_recurse}, recurse_var) do
    # if label in recurse_var do
    #   throw("Cannot have multiple recursions with same variable: #{label}.")
    # end

    %ST.Recurse{label: label, body: convert_to_structs(body, [label | recurse_var]), outer_recurse: outer_recurse}
  end

  defp convert_to_structs({:call, label}, _recurse_var) do
    %ST.Call_Recurse{label: label}
  end

  defp label(%ST.Send{label: label}) do
    label
  end

  defp label(%ST.Recv{label: label}) do
    label
  end

  defp label(_) do
    throw("Following a branch/choice, a send or receive statement is required.")
  end

  # Performs validations on the session type.
  @spec validate!(session_type()) :: boolean()
  defp validate!(session_type)

  defp validate!(%ST.Send{next: next}) do
    validate!(next)
  end

  defp validate!(%ST.Recv{next: next}) do
    validate!(next)
  end

  defp validate!(%ST.Choice{choices: choices}) do
    res =
      Enum.map(
        choices,
        fn
          {_label, %ST.Send{next: next}} ->
            validate!(next)

          {_, other} ->
            throw("Session type parsing validation error: Each branch needs a send as the first statement: #{ST.st_to_string(other)}.")

            false

          _ ->
            throw("BAD - check")
        end
      )

    # Return false if one (or more) false are found
    Enum.find(res, true, fn x -> !x end)
  end

  defp validate!(%ST.Branch{branches: branches}) do
    res =
      Enum.map(
        branches,
        fn
          {_label, %ST.Recv{next: next}} ->
            validate!(next)

          {_, other} ->
            throw("Session type parsing validation error: Each branch needs a receive as the first statement: #{ST.st_to_string(other)}.")

            false

          _ ->
            throw("BAD - check")
        end
      )

    if false in res do
      false
    else
      true
    end
  end

  defp validate!(%ST.Recurse{body: body} = st) do
    case body do
      %ST.Recurse{} ->
        throw("It is unnecessary to having multiple recursions following each other: '#{ST.st_to_string(st)}'")

      _ ->
        validate!(body)
    end
  end

  defp validate!(%ST.Call_Recurse{}) do
    true
  end

  defp validate!(%ST.Terminate{}) do
    true
  end

  defp validate!(x) do
    throw("Validation problem. Unknown input: #{inspect(x)}")
    false
  end
end
