defmodule ElixirSessions.Operations do
  @moduledoc false
  require ST

  @type session_type :: ST.session_type()
  @type session_type_tuple() :: ST.session_type_tuple()
  @typep label :: ST.label()

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
    %ST.Call_Recurse{label: label}
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
  @spec st_to_string(session_type()) :: String.t()
  def st_to_string(session_type)

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

  def st_to_string_current(%ST.Terminate{}) do
    ""
  end

  # Pattern matching with ST.session_type()
  # todo remove? use == instead
  # ! = +{l} and & = &{l}
  @spec equal?(session_type(), session_type(), %{}) :: boolean()
  def equal?(session_type, session_type, recurse_var_mapping)

  def equal?(
        %ST.Send{label: label, types: types, next: next1},
        %ST.Send{label: label, types: types, next: next2},
        recurse_var_mapping
      ) do
    equal?(next1, next2, recurse_var_mapping)
  end

  def equal?(
        %ST.Recv{label: label, types: types, next: next1},
        %ST.Recv{label: label, types: types, next: next2},
        recurse_var_mapping
      ) do
    equal?(next1, next2, recurse_var_mapping)
  end

  def equal?(%ST.Choice{choices: choices1}, %ST.Choice{choices: choices2}, recurse_var_mapping) do
    # Sorting is done (automatically) by the map

    Enum.zip(Map.values(choices1), Map.values(choices2))
    |> Enum.reduce(
      true,
      fn
        {choice1, choice2}, acc ->
          acc and equal?(choice1, choice2, recurse_var_mapping)
      end
    )
  end

  def equal?(
        %ST.Branch{branches: branches1},
        %ST.Branch{branches: branches2},
        recurse_var_mapping
      ) do
    # Sorting is done (automatically) by the map

    Enum.zip(Map.values(branches1), Map.values(branches2))
    |> Enum.reduce(
      true,
      fn
        {branche1, branche2}, acc ->
          acc and equal?(branche1, branche2, recurse_var_mapping)
      end
    )
  end

  def equal?(
        %ST.Recurse{label: label1, body: body1},
        %ST.Recurse{label: label2, body: body2},
        recurse_var_mapping
      ) do
    equal?(body1, body2, Map.put(recurse_var_mapping, label1, label2))
  end

  def equal?(
        %ST.Call_Recurse{label: label1},
        %ST.Call_Recurse{label: label2},
        recurse_var_mapping
      ) do
    case Map.fetch(recurse_var_mapping, label1) do
      {:ok, ^label2} ->
        true

      _ ->
        # In case of free var
        label1 == label2
    end
  end

  def equal?(%ST.Terminate{}, %ST.Terminate{}, _recurse_var_mapping) do
    true
  end

  def equal?(_, _, _) do
    false
  end

  # Walks through session_type by header_session_type and returns the remaining session type.
  # !A().!B().!C() - !A() = !B().!C()

  # E.g.:
  # session_type:          !Hello().!Hello2().end
  # header_session_type:   !Hello().end
  # results in the remaining type !Hello2()

  # E.g. 2:
  # session_type:          !Hello().end
  # header_session_type:   !Hello().!Hello2().end
  # throws error
  @spec session_subtraction(session_type(), session_type()) ::
          {:ok, session_type()} | {:error, any()}
  def session_subtraction(session_type, header_session_type) do
    try do
      remaining_session_type = session_subtraction!(session_type, %{}, header_session_type, %{})

      {:ok, remaining_session_type}
    catch
      error -> {:error, error}
    end
  end

  @spec session_subtraction!(session_type(), %{}, session_type(), %{}) :: session_type()
  def session_subtraction!(session_type, rec_var1, header_session_type, rec_var2)

  def session_subtraction!(
        %ST.Send{label: label, types: types, next: next1},
        rec_var1,
        %ST.Send{label: label, types: types, next: next2},
        rec_var2
      ) do
    session_subtraction!(next1, rec_var1, next2, rec_var2)
  end

  def session_subtraction!(
        %ST.Recv{label: label, types: types, next: next1},
        rec_var1,
        %ST.Recv{label: label, types: types, next: next2},
        rec_var2
      ) do
    session_subtraction!(next1, rec_var1, next2, rec_var2)
  end

  def session_subtraction!(
        %ST.Choice{choices: choices1},
        rec_var1,
        %ST.Choice{choices: choices2},
        rec_var2
      ) do
    # Sorting is done (automatically) by the map
    choices2
    |> Enum.map(fn
      {choice2_key, choice2_value} ->
        case Map.fetch(choices1, choice2_key) do
          {:ok, choice1_value} ->
            session_subtraction!(choice1_value, rec_var1, choice2_value, rec_var2)

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

  def session_subtraction!(
        %ST.Branch{branches: branches1},
        rec_var1,
        %ST.Branch{branches: branches2},
        rec_var2
      ) do
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
        session_subtraction!(branch1, rec_var1, branch2, rec_var2)
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

  def session_subtraction!(
        %ST.Choice{choices: choices1},
        rec_var1,
        %ST.Send{label: label} = choice2,
        rec_var2
      ) do
    case Map.fetch(choices1, label) do
      {:ok, choice1_value} ->
        session_subtraction!(choice1_value, rec_var1, choice2, rec_var2)

      :error ->
        throw("Choosing non exisiting choice: #{ST.st_to_string(choice2)}.")
    end
  end

  def session_subtraction!(
        %ST.Branch{branches: branches1} = b1,
        rec_var1,
        %ST.Recv{label: label} = branch2,
        rec_var2
      ) do
    if map_size(branches1) != 1 do
      throw("Cannot match #{ST.st_to_string(branch2)} with #{ST.st_to_string(b1)}.")
    end

    case Map.fetch(branches1, label) do
      {:ok, branch1_value} ->
        session_subtraction!(branch1_value, rec_var1, branch2, rec_var2)

      :error ->
        throw("Choosing non exisiting choice: #{ST.st_to_string(branch2)}.")
    end
  end

  def session_subtraction!(
        %ST.Recurse{label: label1, body: body1} = rec1,
        rec_var1,
        %ST.Recurse{label: label2, body: body2} = rec2,
        rec_var2
      ) do
    rec_var1 = Map.put(rec_var1, label1, rec1)
    rec_var2 = Map.put(rec_var2, label2, rec2)

    session_subtraction!(body1, rec_var1, body2, rec_var2)
  end

  def session_subtraction!(
        %ST.Recurse{label: label1, body: body1} = rec1,
        rec_var1,
        %ST.Call_Recurse{label: label2},
        rec_var2
      ) do

    rec_var1 = Map.put(rec_var1, label1, rec1)

    case Map.fetch(rec_var2, label2) do
      {:ok, st} -> session_subtraction!(body1, rec_var1, st, rec_var2)
      :error -> throw("Trying to unfold #{label2} but not found.")
    end
  end

  def session_subtraction!(
        %ST.Call_Recurse{label: label1},
        rec_var1,
        %ST.Call_Recurse{label: label2},
        rec_var2
      ) do

    rec1 = Map.fetch!(rec_var1, label1)
    rec2 = Map.fetch!(rec_var2, label2)

    if ST.equal?(ST.unfold_unknown(rec1, rec_var1), ST.unfold_unknown(rec2, rec_var2)) do
      %ST.Terminate{}
    else
      throw("Session types #{ST.st_to_string(rec1)} does not correspond to #{ST.st_to_string(rec2)}.")
    end
  end

  def session_subtraction!(remaining_session_type, _rec_var1, %ST.Terminate{}, _rec_var2) do
    remaining_session_type
  end

  def session_subtraction!(%ST.Terminate{}, _rec_var1, remaining_session_type, _rec_var2) do
    throw(
      "Session type larger than expected. Remaining: #{ST.st_to_string(remaining_session_type)}."
    )
  end

  def session_subtraction!(st, rec_var1, %ST.Recurse{label: label2, body: body} = rec2, rec_var2) do
    rec_var2 = Map.put(rec_var2, label2, rec2)
    session_subtraction!(st, rec_var1, body, rec_var2)
  end

  def session_subtraction!(session_type, _rec_var1, header_session_type, _rec_var2) do
    throw(
      "Session type #{ST.st_to_string(session_type)} does not match session type " <>
        "#{ST.st_to_string(header_session_type)}."
    )
  end

  # Similar session_subtraction, but session type is subtracted from the end.
  # !A().!B().!C() -  !B().!C() = !A()
  # Walks through session_type until the session type matches the session_type_tail.
  @spec session_tail_subtraction(session_type(), session_type()) ::
          {:ok, session_type()} | {:error, any()}
  def session_tail_subtraction(session_type, header_session_type) do
    try do
      case session_tail_subtraction!(session_type, header_session_type) do
        {true, front_session_type} ->
          {:ok, front_session_type}

        {false, _} ->
          {:error,
           "Session type #{ST.st_to_string(header_session_type)} was not found in " <>
             "the tail of #{ST.st_to_string(session_type)}."}
      end
    catch
      error -> {:error, error}
    end
  end

  @spec session_tail_subtraction!(session_type(), session_type()) :: {boolean(), session_type()}
  defp session_tail_subtraction!(session_type, session_type_tail)

  defp session_tail_subtraction!(%ST.Send{} = st, st_tail) do
    if ST.equal?(st, st_tail) do
      {true, %ST.Terminate{}}
    else
      %ST.Send{label: label, types: types, next: next} = st
      {found, tail} = session_tail_subtraction!(next, st_tail)
      {found, %ST.Send{label: label, types: types, next: tail}}
    end
  end

  defp session_tail_subtraction!(%ST.Recv{} = st, st_tail) do
    # throw("Checking #{ST.st_to_string(st)} and #{ST.st_to_string(st_tail)}")

    if ST.equal?(st, st_tail) do
      {true, %ST.Terminate{}}
    else
      %ST.Recv{label: label, types: types, next: next} = st
      {found, tail} = session_tail_subtraction!(next, st_tail)
      {found, %ST.Recv{label: label, types: types, next: tail}}
    end
  end

  defp session_tail_subtraction!(%ST.Choice{choices: choices} = st, st_tail) do
    if ST.equal?(st, st_tail) do
      {true, %ST.Terminate{}}
    else
      {choices, found} =
        Enum.map_reduce(choices, false, fn {label, choice}, acc ->
          {found, tail} = session_tail_subtraction!(choice, st_tail)
          {{label, tail}, acc or found}
        end)

      # todo Check for empty choices?
      empty_choices =
        Enum.reduce(choices, false, fn
          {_, %ST.Terminate{}}, _acc -> true
          _, acc -> acc
        end)

      if empty_choices do
        throw("Found empty choices")
      end

      {found,
       %ST.Choice{
         choices:
           choices
           |> Enum.into(%{})
       }}
    end
  end

  defp session_tail_subtraction!(%ST.Branch{branches: branches} = st, st_tail) do
    if ST.equal?(st, st_tail) do
      {true, %ST.Terminate{}}
    else
      {branches, found} =
        Enum.map(branches, fn {label, branch} ->
          {found, tail} = session_tail_subtraction!(branch, st_tail)
          {{label, tail}, found}
        end)
        |> Enum.unzip()

      # Check for empty branches - should not happen
      empty_branches =
        Enum.reduce(branches, false, fn
          {_, %ST.Terminate{}}, _acc -> true
          _, acc -> acc
        end)

      if empty_branches do
        throw("Found empty branches")
      end

      all_same = Enum.reduce(found, fn elem, acc -> elem == acc end)

      if all_same do
        # Take the first one since all elements are the same
        found_result = hd(found)

        {found_result,
         %ST.Branch{
           branches:
             branches
             |> Enum.into(%{})
         }}
      else
        throw("In case of branch, either all or none should match (#{ST.st_to_string(st)}).")
      end
    end
  end

  defp session_tail_subtraction!(%ST.Recurse{body: body, label: label} = st, st_tail) do
    if ST.equal?(st, st_tail) do
      {true, %ST.Terminate{}}
    else
      {found, next} = session_tail_subtraction!(body, st_tail)

      {found, %ST.Recurse{label: label, body: next}}
    end
  end

  defp session_tail_subtraction!(%ST.Call_Recurse{} = st, st_tail) do
    if ST.equal?(st, st_tail) do
      {true, %ST.Terminate{}}
    else
      {false, st}
    end
  end

  defp session_tail_subtraction!(%ST.Terminate{} = st, st_tail) do
    if ST.equal?(st, st_tail) do
      {true, %ST.Terminate{}}
    else
      {false, st}
    end
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
        :error -> throw("Trying to expand Call_Recurse, but #{label} was not found (#{inspect recurse_var}).")
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

    equal?(ST.string_to_st(s1), ST.string_to_st(s2), %{})

    s1 = "!ok().rec Y.(&{?option1().rec ZZ.(!ok().rec Y.(&{?option1().ZZ, ?option2().Y})), ?option2().Y})"

    s2 = "rec XXX.(!ok().rec Y.(&{?option1().XXX, ?option2().Y}))"

    case ST.session_subtraction(ST.string_to_st(s1), ST.string_to_st(s2)) do
      {:ok, remaining_st} ->
        # assert false
        ST.st_to_string(remaining_st)

      {:error, error} ->
        # Test should fail
        # assert true
        throw(error)
    end
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

# def xyz(%ST.Terminate{}) do
# end
