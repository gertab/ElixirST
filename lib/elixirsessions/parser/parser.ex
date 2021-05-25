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

  # Parses a session type from a string to an Elixir data structure.
  @spec parse_no_validations(bitstring() | charlist()) :: session_type()
  def parse_no_validations(string) when is_bitstring(string) do
    string
    |> String.to_charlist()
    |> parse_no_validations()
  end

  def parse_no_validations(string) do
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

        # YeccRet = {ok, Parserfile} | {ok, Parserfile, Warnings} | error | {error, Errors, Warnings}

        # todo convert branches with one option to receive statements
        # and choices with one choice to send
      end
    else
      err ->
        # todo: cuter error message needed
        _ = Logger.error(inspect(err))
        []
    end
  end

  @spec parse(bitstring() | charlist()) :: session_type()
  def parse(string) do
    st = parse_no_validations(string)
    validate!(st)
    st
  end

  defp lexer(string) do
    # IO.inspect tokens
    :lexer.string(string)
  end

  # Performs validations on the session type.
  # todo get rid of unused and infinite (empty) recursion e.g.: rec Y.rec X.Y
  @spec validate(session_type()) :: :ok | {:error, any()}
  def validate(session_type) do
    try do
      validate!(session_type)
      :ok
    catch
      x -> {:error, x}
    end
  end

  @spec validate!(session_type()) :: boolean()
  def validate!(session_type)

  def validate!(%ST.Send{next: next}) do
    validate!(next)
  end

  def validate!(%ST.Recv{next: next}) do
    validate!(next)
  end

  def validate!(%ST.Choice{choices: choices}) do
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

  def validate!(%ST.Branch{branches: branches}) do
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

  def validate!(%ST.Recurse{body: body}) do
    validate!(body)
  end

  def validate!(%ST.Call_Recurse{}) do
    true
  end

  def validate!(%ST.Terminate{}) do
    true
  end

  def validate!(x) do
    throw("Validation problem. Unknown input: #{inspect(x)}")
    false
  end

  @doc """
    Convert session types from Erlang records to Elixir Structs.
    Throws error in case of branches/choices with same labels, or
    if the types are not valid.

    ## Example
        iex> st_erlang = {:recv, :Ping, [], {:send, :Pong, [], {:terminate}}}
        ...> ElixirSessions.Parser.convert_to_structs(st_erlang, [])
        %ST.Recv{
          label: :Ping,
          next: %ST.Send{label: :Pong, next: %ST.Terminate{}, types: []},
          types: []
        }
  """
  # Convert session types from Erlang records (tuples) to Elixir Structs.
  # throws error in case of branches/choices with same labels, or
  # if the types are not valid
  # todo remove validations and put them in validate!
  @spec convert_to_structs(
          # should be { , , [atom], }
          {:send, atom, any, session_type_tuple()}
          | {:recv, atom, any, session_type_tuple()}
          | {:choice, [session_type_tuple()]}
          | {:branch, [session_type_tuple()]}
          | {:call, atom}
          | {:recurse, atom, session_type_tuple()}
          | {:terminate},
          [label()]
        ) :: session_type()
  def convert_to_structs(session_type, recurse_var)

  def convert_to_structs({:terminate}, _recurse_var) do
    %ST.Terminate{}
  end

  def convert_to_structs({send_recv, label, types, next}, recurse_var) when send_recv in [:send, :recv] do
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

  def convert_to_structs({:choice, choices}, recurse_var) do
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

  def convert_to_structs({:branch, branches}, recurse_var) do
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

  def convert_to_structs({:recurse, label, body}, recurse_var) do
    # if label in recurse_var do
    #   throw("Cannot have multiple recursions with same variable: #{label}.")
    # end

    %ST.Recurse{label: label, body: convert_to_structs(body, [label | recurse_var])}
  end

  def convert_to_structs({:call, label}, _recurse_var) do
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
end
