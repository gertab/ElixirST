defmodule ElixirSessions.Operations do
  @moduledoc false
  require ST

  @type session_type :: ST.session_type()
  @type session_type_tuple() :: ST.session_type_tuple()
  @typep label :: ST.label()
  @type session_type_incl_label() :: {label(), session_type()}

  # todo make all methods that throw errors contain '!'. Add equivalent non '!' methods
  # Performs validations on the session type.
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
            throw(
              "Session type parsing validation error: Each branch needs a send as the first statement: #{
                ST.st_to_string(other)
              }."
            )

            false

          _ ->
            throw("BAD - check")
        end
      )

    # AND operation
    if false in res do
      false
    else
      true
    end
  end

  def validate!(%ST.Branch{branches: branches}) do
    res =
      Enum.map(
        branches,
        fn
          {_label, %ST.Recv{next: next}} ->
            validate!(next)

          {_, other} ->
            throw(
              "Session type parsing validation error: Each branch needs a receive as the first statement: #{
                ST.st_to_string(other)
              }."
            )

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

  def validate!(%ST.Call_Session_Type{}) do
    true
  end

  def validate!(%ST.Terminate{}) do
    true
  end

  def validate!(x) do
    throw("Validation problem. Unknown input: #{inspect(x)}")
    false
  end

  @correct_types [
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

  # Convert session types from Erlang records (tuples) to Elixir Structs.
  # throws error in case of branches/choices with same labels, or
  # if the types are not valid
  # @spec convert_to_structs(session_type_tuple(), [label()]) :: session_type()
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

  def convert_to_structs({:send, label, types, next}, recurse_var) do
    invalid_type = Enum.filter(types, fn t -> t not in @correct_types end)

    if length(invalid_type) > 0 do
      throw("Invalid type/s: #{inspect(invalid_type)}")
    end

    %ST.Send{label: label, types: types, next: convert_to_structs(next, recurse_var)}
  end

  def convert_to_structs({:recv, label, types, next}, recurse_var) do
    invalid_type = Enum.filter(types, fn t -> t not in @correct_types end)

    if length(invalid_type) > 0 do
      throw("Invalid type/s: #{inspect(invalid_type)}")
    end

    %ST.Recv{label: label, types: types, next: convert_to_structs(next, recurse_var)}
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
    if label in recurse_var do
      throw("Cannot have multiple recursions with same variable: #{label}.")
    end

    %ST.Recurse{label: label, body: convert_to_structs(body, [label | recurse_var])}
  end

  def convert_to_structs({:call, label}, recurse_var) do
    if label in recurse_var do
      %ST.Call_Recurse{label: label}
    else
      %ST.Call_Session_Type{label: label}
    end
  end

  defp label(%ST.Send{label: label}) do
    label
  end

  defp label(%ST.Recv{label: label}) do
    label
  end

  defp label(_) do
    throw("After a branch/choice, a send or receive statement is required.")
  end

  #  Converts s session type to a string
  # todo in the case of 'end'
  # replace name to to_string
  @spec st_to_string(session_type() | session_type_incl_label()) :: String.t()
  def st_to_string(session_type)

  def st_to_string({label, session_type}) do
    case label do
      :nolabel ->
        st_to_string(session_type)

      _ ->
        "#{label} = " <> st_to_string(session_type)
    end
  end

  def st_to_string(%ST.Send{label: label, types: types, next: next}) do
    types_string = types |> Enum.join(", ")

    following_st = st_to_string(next)

    if following_st != "" do
      "!#{label}(#{types_string}).#{following_st}"
    else
      "!#{label}(#{types_string})"
    end
  end

  def st_to_string(%ST.Recv{label: label, types: types, next: next}) do
    types_string = types |> Enum.join(", ")

    following_st = st_to_string(next)

    if following_st != "" do
      "?#{label}(#{types_string}).#{following_st}"
    else
      "?#{label}(#{types_string})"
    end
  end

  def st_to_string(%ST.Choice{choices: choices}) do
    v =
      Enum.map(choices, fn {_label, x} -> st_to_string(x) end)
      |> Enum.join(", ")

    "+{#{v}}"
  end

  def st_to_string(%ST.Branch{branches: branches}) do
    v =
      Enum.map(branches, fn {_label, x} -> st_to_string(x) end)
      |> Enum.join(", ")

    "&{#{v}}"
  end

  def st_to_string(%ST.Recurse{label: label, body: body}) do
    "rec #{label}.(#{st_to_string(body)})"
  end

  def st_to_string(%ST.Call_Recurse{label: label}) do
    "#{label}"
  end

  def st_to_string(%ST.Call_Session_Type{label: label}) do
    "#{label}"
  end

  def st_to_string(%ST.Terminate{}) do
    ""
    # "end"
  end

  #  Converts one item in a session type to a string. E.g. ?Hello().!hi() would return ?Hello() only.
  @spec st_to_string_current(session_type()) :: String.t()
  def st_to_string_current(session_type)

  def st_to_string_current(%ST.Send{label: label, types: types}) do
    types_string = types |> Enum.join(", ")

    "!#{label}(#{types_string})"
  end

  def st_to_string_current(%ST.Recv{label: label, types: types}) do
    types_string = types |> Enum.join(", ")

    "?#{label}(#{types_string})"
  end

  def st_to_string_current(%ST.Choice{choices: choices}) do
    v =
      Enum.map(choices, fn {_, x} -> st_to_string_current(x) end)
      |> Enum.map(fn x -> x <> "..." end)
      |> Enum.join(", ")

    "+{#{v}}"
  end

  def st_to_string_current(%ST.Branch{branches: branches}) do
    v =
      Enum.map(branches, fn {_, x} -> st_to_string_current(x) end)
      |> Enum.map(fn x -> x <> "..." end)
      |> Enum.join(", ")

    "&{#{v}}"
  end

  def st_to_string_current(%ST.Recurse{label: label, body: body}) do
    "rec #{label}.(#{st_to_string_current(body)})"
  end

  def st_to_string_current(%ST.Call_Recurse{label: label}) do
    "#{label}"
  end

  def st_to_string_current(%ST.Call_Session_Type{label: label}) do
    "#{label}"
  end

  def st_to_string_current(%ST.Terminate{}) do
    ""
  end

  # Pattern matching with ST.session_type()
  # todo remove? use == instead
  # ! = +{l} and & = &{l}
  @spec equal(session_type(), session_type()) :: boolean()
  def equal(session_type, session_type)

  def equal(
        %ST.Send{label: label, types: types, next: next1},
        %ST.Send{label: label, types: types, next: next2}
      ) do
    equal(next1, next2)
  end

  def equal(
        %ST.Recv{label: label, types: types, next: next1},
        %ST.Recv{label: label, types: types, next: next2}
      ) do
    equal(next1, next2)
  end

  def equal(%ST.Choice{choices: choices1}, %ST.Choice{choices: choices2}) do
    # Sorting is done (automatically) by the map

    Enum.zip(Map.values(choices1), Map.values(choices2))
    |> Enum.reduce(
      true,
      fn
        {choice1, choice2}, acc ->
          acc and equal(choice1, choice2)
      end
    )
  end

  def equal(%ST.Branch{branches: branches1}, %ST.Branch{branches: branches2}) do
    # Sorting is done (automatically) by the map

    Enum.zip(Map.values(branches1), Map.values(branches2))
    |> Enum.reduce(
      true,
      fn
        {branche1, branche2}, acc ->
          acc and equal(branche1, branche2)
      end
    )
  end

  def equal(%ST.Recurse{label: label, body: body1}, %ST.Recurse{label: label, body: body2}) do
    equal(body1, body2)
  end

  def equal(%ST.Call_Recurse{label: label}, %ST.Call_Recurse{label: label}) do
    # todo alpha equivalence?
    true
  end

  def equal(%ST.Call_Session_Type{} = s1, %ST.Call_Session_Type{} = s2) do
    s1 == s2
  end

  def equal(%ST.Terminate{}, %ST.Terminate{}) do
    true
  end

  def equal(_, _) do
    false
  end

  # Walks through session_type by session_type_internal and returns the remaining session type.
  # E.g.:
  # session_type:          !Hello().!Hello2().end
  # session_type_internal: !Hello().end
  # results in the remaining type !Hello2()

  # E.g. 2:
  # session_type:          !Hello().end
  # session_type_internal: !Hello().!Hello2().end
  # throws error
  @spec compare_session_types(session_type(), session_type()) :: {:ok, session_type()} | {:error, any()}
  def compare_session_types(session_type, session_type_internal) do
    try do
      remaining_session_type = compare_session_types!(session_type, session_type_internal)

      {:ok, remaining_session_type}
    catch
      error -> {:error, error}
    end
  end

  @spec compare_session_types!(session_type(), session_type()) :: session_type()
  def compare_session_types!(session_type, session_type_internal)

  def compare_session_types!(
        %ST.Send{label: label, types: types, next: next1},
        %ST.Send{label: label, types: types, next: next2}
      ) do
    compare_session_types!(next1, next2)
  end

  def compare_session_types!(
        %ST.Recv{label: label, types: types, next: next1},
        %ST.Recv{label: label, types: types, next: next2}
      ) do
    compare_session_types!(next1, next2)
  end

  def compare_session_types!(%ST.Choice{choices: choices1}, %ST.Choice{choices: choices2}) do
    # Sorting is done (automatically) by the map
    choices2
    |> Enum.map(fn
      {choice2_key, choice2_value} ->
        case Map.fetch(choices1, choice2_key) do
          {:ok, choice1_value} ->
            compare_session_types!(choice1_value, choice2_value)

          :error ->
            throw("Choosing non exisiting choice: #{ST.st_to_string(choice2_value)}.")
        end
    end)
    |> Enum.reduce(fn
      remaining_st, acc ->
        if remaining_st != acc do
          throw(
            "Choices do not reach the same state: #{ST.st_to_string(remaining_st)} " <>
              "#{ST.st_to_string(acc)}."
          )
        end

        remaining_st
    end)
  end

  def compare_session_types!(%ST.Branch{branches: branches1}, %ST.Branch{branches: branches2}) do
    # Sorting is done (automatically) by the map

    if map_size(branches1) != map_size(branches2) do
      throw(
        "Branch sizes do not match: #{ST.st_to_string(branches1)} (size = #{map_size(branches1)}) " <>
          "#{ST.st_to_string(branches2)} (size = #{map_size(branches2)})"
      )
    end

    Enum.zip(Map.values(branches1), Map.values(branches2))
    |> Enum.map(fn
      {branch1, branch2} ->
        compare_session_types!(branch1, branch2)
    end)
    |> Enum.reduce(fn
      remaining_st, acc ->
        if remaining_st != acc do
          throw(
            "Branches do not reach the same state: #{ST.st_to_string(remaining_st)} " <>
              "#{ST.st_to_string(acc)}."
          )
        end

        remaining_st
    end)
  end

  def compare_session_types!(%ST.Choice{choices: choices1}, %ST.Send{label: label} = choice2) do
      case Map.fetch(choices1, label) do
        {:ok, choice1_value} ->
          compare_session_types!(choice1_value, choice2)

        :error ->
          throw("Choosing non exisiting choice: #{ST.st_to_string(choice2)}.")
      end
  end

  def compare_session_types!(%ST.Branch{branches: branches1} = b1, %ST.Recv{label: label} = branch2) do

    if map_size(branches1) != 1 do
      throw("Cannot match #{ST.st_to_string(branch2)} with #{ST.st_to_string(b1)}.")
    end

    case Map.fetch(branches1, label) do
      {:ok, branch1_value} ->
        compare_session_types!(branch1_value, branch2)

      :error ->
        throw("Choosing non exisiting choice: #{ST.st_to_string(branch2)}.")
    end
end

  def compare_session_types!(%ST.Recurse{label: label, body: body1}, %ST.Recurse{
        label: label,
        body: body2
      }) do
    compare_session_types!(body1, body2)
  end

  def compare_session_types!(%ST.Call_Recurse{label: label}, %ST.Call_Recurse{label: label}) do
    # todo alpha equivalence?
    %ST.Terminate{}
  end

  def compare_session_types!(%ST.Call_Session_Type{}, %ST.Call_Session_Type{}) do
    %ST.Terminate{}
  end

  def compare_session_types!(remaining_session_type, %ST.Terminate{}) do
    remaining_session_type
  end

  def compare_session_types!(%ST.Terminate{}, remaining_session_type) do
    throw(
      "Session type larger than expected. Remaining: #{ST.st_to_string(remaining_session_type)}."
    )
  end

  def compare_session_types!(session_type, session_type_internal) do
    throw(
      "Session type #{ST.st_to_string(session_type)} does not match session type " <>
        "#{ST.st_to_string(session_type_internal)}."
    )
  end

  # recompile && ElixirSessions.Operations.run
  def run() do
    s1 = "!Hello2(atom, list).+{!Hello(atom, list).?H11(), !Hello2(atom, list).?H11(), !Hello3(atom, list).?H11()}"
    s2 = "!Hello2(atom, list) !Hello(atom, list)"

    compare_session_types!(ST.string_to_st(s1), ST.string_to_st(s2))
  end
end

# Pattern matching with ST.session_type()
# def xyz(session_type)

# def xyz(%ST.Send{label: label, types: types, next: next}) do
# end

# def xyz(%ST.Recv{label: label, types: types, next: next}) do
# end

# def xyz(%ST.Choice{choices: choices}) do
# end

# def xyz(%ST.Branch{branches: branches}) do
# end

# def xyz(%ST.Recurse{label: label, body: body}) do
# end

# def xyz(%ST.Call_Recurse{label: label}) do
# end

# def xyz(%ST.Call_Session_Type{label: label}) do
# end

# def xyz(%ST.Terminate{}) do
# end
