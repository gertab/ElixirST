defmodule ElixirSessions.Operations do
  @moduledoc false
  require ST

  @type session_type :: ST.session_type()
  @type session_type_tuple() :: ST.session_type_tuple()

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
    # todo maybe check the label; check if sorted
    # todo check for uniqeness
    res =
      Enum.map(
        choices,
        fn
          %ST.Send{next: next} ->
            validate!(next)

          other ->
            throw(
              "Session type parsing validation error: Each branch needs a send as the first statement: #{
                ST.st_to_string(other)
              }."
            )

            false
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
          %ST.Recv{next: next} ->
            validate!(next)

          other ->
            throw(
              "Session type parsing validation error: Each branch needs a receive as the first statement: #{
                ST.st_to_string(other)
              }."
            )

            false
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

  # Convert session types from Erlang records (tuples) to Elixir Structs.
  # @spec convert_to_structs(session_type_tuple()) :: session_type()
  @spec convert_to_structs(
          {:send, atom, any, session_type_tuple()} # should be { , , [atom], }
          | {:recv, atom, any, session_type_tuple()}
          | {:choice, [session_type_tuple()]}
          | {:branch, [session_type_tuple()]}
          | {:call_recurse, atom}
          | {:recurse, atom, session_type_tuple()}
          | {:terminate}
        ) :: session_type()
  def convert_to_structs(session_type)

  def convert_to_structs({:terminate}) do
    %ST.Terminate{}
  end

  def convert_to_structs({:send, label, types, next}) do
    %ST.Send{label: label, types: types, next: convert_to_structs(next)}
  end

  def convert_to_structs({:recv, label, types, next}) do
    %ST.Recv{label: label, types: types, next: convert_to_structs(next)}
  end

  def convert_to_structs({:choice, choices}) do
    %ST.Choice{choices: Enum.map(choices, fn x -> convert_to_structs(x) end)}
  end

  def convert_to_structs({:branch, branches}) do
    %ST.Branch{branches: Enum.map(branches, fn x -> convert_to_structs(x) end)}
  end

  def convert_to_structs({:recurse, label, body}) do
    %ST.Recurse{label: label, body: convert_to_structs(body)}
  end

  def convert_to_structs({:call_recurse, label}) do
    %ST.Call_Recurse{label: label}
  end

  #  Converts s session type to a string
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
      Enum.map(choices, fn x -> st_to_string(x) end)
      |> Enum.join(", ")

    "+{#{v}}"
  end

  def st_to_string(%ST.Branch{branches: branches}) do
    v =
      Enum.map(branches, fn x -> st_to_string(x) end)
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
      Enum.map(choices, fn x -> st_to_string_current(x) end)
      |> Enum.map(fn x -> x <> "..." end)
      |> Enum.join(", ")

    "+{#{v}}"
  end

  def st_to_string_current(%ST.Branch{branches: branches}) do
    v =
      Enum.map(branches, fn x -> st_to_string_current(x) end)
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
  @spec equal(session_type(), session_type()) :: boolean()
  def equal(session_type, session_type)

  def equal(%ST.Send{label: label1, types: types1, next: next1}, %ST.Send{label: label2, types: types2, next: next2}) do
    label1 == label2 and types1 == types2 and equal(next1, next2)
  end

  def equal(%ST.Recv{label: label1, types: types1, next: next1}, %ST.Recv{label: label2, types: types2, next: next2}) do
    label1 == label2 and types1 == types2 and equal(next1, next2)
  end

  def equal(%ST.Choice{choices: choices1}, %ST.Choice{choices: choices2}) do
    Enum.zip(choices1, choices2)
    |> Enum.reduce(true,
    fn
      {choice1, choice2}, acc ->
        acc and equal(choice1, choice2)
    end)
  end

  def equal(%ST.Branch{branches: branches1}, %ST.Branch{branches: branches2}) do
    Enum.zip(branches1, branches2)
    |> Enum.reduce(true,
    fn
      {branche1, branche2}, acc ->
        acc and equal(branche1, branche2)
    end)
  end

  def equal(%ST.Recurse{label: label1, body: body1}, %ST.Recurse{label: label2, body: body2}) do
    label1 == label2 and equal(body1, body2)
  end

  def equal(%ST.Call_Recurse{label: label1}, %ST.Call_Recurse{label: label2}) do
    label1 == label2
  end

  def equal(%ST.Terminate{}, %ST.Terminate{}) do
    true
  end

  def equal(_, _) do
    false
  end


  # recompile && ElixirSessions.Operations.run
  def run() do
    s1 = "!Hello2(atom, list).&{?Hello2(atom, list).?H(), ?Hello2(atom, list)}"
    s2 = "!Hello2(atom, list)&{?Hello2(atom, list), ?Hello2(atom, list).?H()}"

    equal(ST.string_to_st(s1), ST.string_to_st(s2))
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
