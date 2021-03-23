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
    # if label in recurse_var do
    #   throw("Cannot have multiple recursions with same variable: #{label}.")
    # end

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
  @spec equal(session_type(), session_type(), %{}) :: boolean()
  def equal(session_type, session_type, recurse_var_mapping)

  def equal(
        %ST.Send{label: label, types: types, next: next1},
        %ST.Send{label: label, types: types, next: next2},
        recurse_var_mapping
      ) do
    equal(next1, next2, recurse_var_mapping)
  end

  def equal(
        %ST.Recv{label: label, types: types, next: next1},
        %ST.Recv{label: label, types: types, next: next2},
        recurse_var_mapping
      ) do
    equal(next1, next2, recurse_var_mapping)
  end

  def equal(%ST.Choice{choices: choices1}, %ST.Choice{choices: choices2}, recurse_var_mapping) do
    # Sorting is done (automatically) by the map

    Enum.zip(Map.values(choices1), Map.values(choices2))
    |> Enum.reduce(
      true,
      fn
        {choice1, choice2}, acc ->
          acc and equal(choice1, choice2, recurse_var_mapping)
      end
    )
  end

  def equal(%ST.Branch{branches: branches1}, %ST.Branch{branches: branches2}, recurse_var_mapping) do
    # Sorting is done (automatically) by the map

    Enum.zip(Map.values(branches1), Map.values(branches2))
    |> Enum.reduce(
      true,
      fn
        {branche1, branche2}, acc ->
          acc and equal(branche1, branche2, recurse_var_mapping)
      end
    )
  end

  def equal(
        %ST.Recurse{label: label1, body: body1},
        %ST.Recurse{label: label2, body: body2},
        recurse_var_mapping
      ) do
    equal(body1, body2, Map.put(recurse_var_mapping, label1, label2))
  end

  def equal(%ST.Call_Recurse{label: label1}, %ST.Call_Recurse{label: label2}, recurse_var_mapping) do
    # todo alpha equivalence?
    true

    case Map.fetch(recurse_var_mapping, label1) do
      {:ok, ^label2} -> true
      _ -> false
    end
  end

  def equal(%ST.Call_Session_Type{} = s1, %ST.Call_Session_Type{} = s2, _recurse_var_mapping) do
    s1 == s2
  end

  def equal(%ST.Terminate{}, %ST.Terminate{}, _recurse_var_mapping) do
    true
  end

  def equal(_, _, _) do
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
  @spec session_remainder(session_type(), session_type()) ::
          {:ok, session_type()} | {:error, any()}
  def session_remainder(session_type, session_type_internal) do
    try do
      remaining_session_type = session_remainder!(session_type, session_type_internal)

      {:ok, remaining_session_type}
    catch
      error -> {:error, error}
    end
  end

  @spec session_remainder!(session_type(), session_type()) :: session_type()
  def session_remainder!(session_type, session_type_internal)

  def session_remainder!(
        %ST.Send{label: label, types: types, next: next1},
        %ST.Send{label: label, types: types, next: next2}
      ) do
    session_remainder!(next1, next2)
  end

  def session_remainder!(
        %ST.Recv{label: label, types: types, next: next1},
        %ST.Recv{label: label, types: types, next: next2}
      ) do
    session_remainder!(next1, next2)
  end

  def session_remainder!(%ST.Choice{choices: choices1}, %ST.Choice{choices: choices2}) do
    # Sorting is done (automatically) by the map
    choices2
    |> Enum.map(fn
      {choice2_key, choice2_value} ->
        case Map.fetch(choices1, choice2_key) do
          {:ok, choice1_value} ->
            session_remainder!(choice1_value, choice2_value)

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

  def session_remainder!(%ST.Branch{branches: branches1}, %ST.Branch{branches: branches2}) do
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
        session_remainder!(branch1, branch2)
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

  def session_remainder!(%ST.Choice{choices: choices1}, %ST.Send{label: label} = choice2) do
    case Map.fetch(choices1, label) do
      {:ok, choice1_value} ->
        session_remainder!(choice1_value, choice2)

      :error ->
        throw("Choosing non exisiting choice: #{ST.st_to_string(choice2)}.")
    end
  end

  def session_remainder!(%ST.Branch{branches: branches1} = b1, %ST.Recv{label: label} = branch2) do
    if map_size(branches1) != 1 do
      throw("Cannot match #{ST.st_to_string(branch2)} with #{ST.st_to_string(b1)}.")
    end

    case Map.fetch(branches1, label) do
      {:ok, branch1_value} ->
        session_remainder!(branch1_value, branch2)

      :error ->
        throw("Choosing non exisiting choice: #{ST.st_to_string(branch2)}.")
    end
  end

  def session_remainder!(%ST.Recurse{label: label, body: body1}, %ST.Recurse{
        label: label,
        body: body2
      }) do
    session_remainder!(body1, body2)
  end

  def session_remainder!(%ST.Call_Recurse{label: label}, %ST.Call_Recurse{label: label}) do
    # todo alpha equivalence?
    %ST.Terminate{}
  end

  def session_remainder!(%ST.Call_Session_Type{}, %ST.Call_Session_Type{}) do
    %ST.Terminate{}
  end

  def session_remainder!(remaining_session_type, %ST.Terminate{}) do
    remaining_session_type
  end

  def session_remainder!(%ST.Terminate{}, remaining_session_type) do
    throw(
      "Session type larger than expected. Remaining: #{ST.st_to_string(remaining_session_type)}."
    )
  end

  def session_remainder!(st, %ST.Recurse{body: body}) do
    # todo alpha equivalence?
    session_remainder!(st, body)
  end

  def session_remainder!(session_type, session_type_internal) do
    throw(
      "Session type #{ST.st_to_string(session_type)} does not match session type " <>
        "#{ST.st_to_string(session_type_internal)}."
    )
  end

  # Takes a session type (starting with a recursion, e.g. rec X.(...)) and outputs a single unfold of X
  @spec unfold_current_inside(session_type(), label(), ST.Recurse.t()) :: session_type()
  def unfold_current_inside(%ST.Send{label: label_send, types: types, next: next}, label, rec) do
    %ST.Send{label: label_send, types: types, next: unfold_current_inside(next, label, rec)}
  end

  def unfold_current_inside(%ST.Recv{label: label_recv, types: types, next: next}, label, rec) do
    %ST.Recv{label: label_recv, types: types, next: unfold_current_inside(next, label, rec)}
  end

  def unfold_current_inside(%ST.Choice{choices: choices}, label, rec) do
    %ST.Choice{
      choices:
        Enum.map(choices, fn {l, choice} -> {l, unfold_current_inside(choice, label, rec)} end)
        |> Enum.into(%{})
    }
  end

  def unfold_current_inside(%ST.Branch{branches: branches}, label, rec) do
    %ST.Branch{
      branches:
        Enum.map(branches, fn {l, branch} -> {l, unfold_current_inside(branch, label, rec)} end)
        |> Enum.into(%{})
    }
  end

  def unfold_current_inside(%ST.Recurse{label: diff_label, body: body}, label, rec) do
    %ST.Recurse{label: diff_label, body: unfold_current_inside(body, label, rec)}
  end

  def unfold_current_inside(%ST.Call_Recurse{label: label}, label, rec) do
    rec
  end

  def unfold_current_inside(%ST.Call_Recurse{label: diff_label}, _label, _rec) do
    %ST.Call_Recurse{label: diff_label}
  end

  def unfold_current_inside(%ST.Call_Session_Type{} = call, _label, _rec) do
    call
  end

  def unfold_current_inside(%ST.Terminate{} = st, _label, _rec) do
    st
  end

  # Given !A().X, it will unfold the recursive variable X.
  def unfold_unknown_inside(
        %ST.Send{label: label, types: types, next: next},
        recurse_var,
        bound_var
      ) do
    %ST.Send{
      label: label,
      types: types,
      next: unfold_unknown_inside(next, recurse_var, bound_var)
    }
  end

  def unfold_unknown_inside(
        %ST.Recv{label: label, types: types, next: next},
        recurse_var,
        bound_var
      ) do
    %ST.Recv{
      label: label,
      types: types,
      next: unfold_unknown_inside(next, recurse_var, bound_var)
    }
  end

  def unfold_unknown_inside(%ST.Choice{choices: choices}, recurse_var, bound_var) do
    %ST.Choice{
      choices:
        Enum.map(choices, fn {l, choice} ->
          {l, unfold_unknown_inside(choice, recurse_var, bound_var)}
        end)
        |> Enum.into(%{})
    }
  end

  def unfold_unknown_inside(%ST.Branch{branches: branches}, recurse_var, bound_var) do
    %ST.Branch{
      branches:
        Enum.map(branches, fn {l, branch} ->
          {l, unfold_unknown_inside(branch, recurse_var, bound_var)}
        end)
        |> Enum.into(%{})
    }
  end

  def unfold_unknown_inside(%ST.Recurse{label: label, body: body}, recurse_var, bound_var) do
    new_bound_var = [label | bound_var]
    %ST.Recurse{label: label, body: unfold_unknown_inside(body, recurse_var, new_bound_var)}
  end

  def unfold_unknown_inside(%ST.Call_Recurse{label: label}, recurse_var, bound_var) do
    if label in bound_var do
      %ST.Call_Recurse{label: label}
    else
      case Map.fetch(recurse_var, label) do
        {:ok, found} -> found
        :error -> throw("Trying to expand Call_Recurse, but #{label} was not found.")
      end
    end
  end

  def unfold_unknown_inside(%ST.Call_Session_Type{label: label}, recurse_var, bound_var) do
    # todo currently a hack. remove Call_Session_Type
    if label in bound_var do
      %ST.Call_Recurse{label: label}
    else
      case Map.fetch(recurse_var, label) do
        {:ok, found} -> found
        :error -> throw("Trying to expand Call_Recurse, but #{label} was not found.")
      end
    end
  end

  def unfold_unknown_inside(%ST.Terminate{} = st, _recurse_var, _bound_var) do
    st
  end

  # recompile && ElixirSessions.Operations.run
  def run() do
    s1 = "rec X.(!Hello().X)"

    s2 = "rec Y.(!Hello().Y)"

    equal(ST.string_to_st(s1), ST.string_to_st(s2), %{})
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
