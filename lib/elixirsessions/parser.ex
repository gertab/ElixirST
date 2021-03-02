defmodule ElixirSessions.Parser do
  @moduledoc """
  Parses an input string to session types (as Elixir data).


  ## Examples

      iex> s = "!Hello(Integer)"
      ...> ElixirSessions.Parser.parse(s)
      [{:send, :Hello, [:integer]}]

      iex> s = "rec X.(&{?Ping().!Pong().X, ?Quit().end})"
      ...> ElixirSessions.Parser.parse(s)
      [
        {:recurse, :X,
        [
          branch: [
            [{:recv, :Ping, []}, {:send, :Pong, []}, {:call_recurse, :X}],
            [{:recv, :Quit, []}]
          ]
        ]}
      ]
  """
  require Logger
  require ElixirSessions.Common

  @typedoc false
  @type session_type :: ElixirSessions.Common.session_type()

  @doc """
  Parses a session type from a string to an Elixir data structure.

  ## Examples

      iex> s = "!Hello() . ?Receive(Integer)"
      ...> ElixirSessions.Parser.parse(s)
      [{:send, :Hello, []}, {:recv, :Receive, [:integer]}]

  """
  @spec parse(bitstring() | charlist()) :: session_type()
  def parse(string) when is_bitstring(string), do: string |> String.to_charlist() |> parse()

  def parse(string) do
    with {:ok, tokens, _} <- lexer(string) do
      {:ok, session_type} = :parse.parse(tokens)
      # IO.inspect(session_type)
      # IO.puts("Initial st: #{st_to_string(session_type)}")
      fixed_session_type = fix_structure_branch_choice(session_type)
      # IO.puts("Fixed st:   #{st_to_string(fixed_session_type)}")
      validate(fixed_session_type)
      fixed_session_type
    else
      err ->
        _ = Logger.error(err)
        []
    end
  end

  defp lexer(string) do
    # IO.inspect tokens
    :lexer.string(string)
  end

  # todo (confirm before implement) branches need more than one branch
  @doc """
  Performs validations on the session type.

  Ensure the following:
    1) All branches have a `receive` statement as the first statement.
    1) All choices have a `send` statement as the first statement.
    2) todo: There are no operations after a branch/choice (e.g. &{?Hello()}.!Hello() is invalid)
    4) todo: check if similar checks are needed for `rec`

  """
  @spec validate(session_type()) :: boolean()
  def validate(session_type)

  def validate(body) when is_list(body) do
    normal_validations = Enum.map(body, fn x -> validate(x) end)

    joins_validations = branch_choice_validation(body) |> List.flatten()

    # AND operation in list: [t, t, f, t] -> f
    if false in normal_validations do
      false
    else
      if false in joins_validations do
        false
      else
        true
      end
    end
  end

  def validate({x, _label, _types}) when x in [:recv, :send] do
    true
  end

  def validate({:call_recurse, _label}) do
    true
  end

  def validate({:recurse, _label, body}) do
    validate(body)
  end

  def validate({:branch, body}) when is_list(body) do
    receive_checks =
      Enum.map(body, fn
        [{:recv, _label, _types}] ->
          true

        [{:recv, _label, _types} | y] ->
          y

        x ->
          throw(
            "Session type parsing validation error: Each branch needs a receive as the first statement. Error in #{
              st_to_string(x)
            }"
          )

          false
      end)

    # AND operation
    if false in receive_checks do
      false
    else
      true
    end
  end

  def validate({:choice, body}) when is_list(body) do
    send_checks =
      Enum.map(body, fn
        [{:send, _label, _types}] ->
          true

        [{:send, _label, _types} | y] ->
          y

        x ->
          throw(
            "Session type parsing validation error: Each branch needs a send as the first statement: #{
              st_to_string(x)
            }"
          )

          false
      end)

    # AND operation
    if false in send_checks do
      false
    else
      true
    end
  end

  def validate(_) do
    throw("Validation problem. Unknown input")
    false
  end

  # Ensure that there are no commands following a branch or choice (in session type).
  defp branch_choice_validation([{:send, _label, _types} | remaining]) do
    [true | branch_choice_validation(remaining)]
  end

  defp branch_choice_validation([{:recv, _label, _types} | remaining]) do
    [true | branch_choice_validation(remaining)]
  end

  defp branch_choice_validation([{:branch, branches}]) do
    Enum.map(branches, fn branch ->
      branch_choice_validation(branch)
    end)
  end

  defp branch_choice_validation([{:branch, branches} | remaining]) do
    throw(
      "Connot have operations after a branch (e.g. &{!A()}.!B()). Session type #{
        st_to_string(remaining)
      } is invalid after #{st_to_string([{:branch, branches}])}."
    )

    [false]
  end

  defp branch_choice_validation([{:choice, choices}]) do
    Enum.map(choices, fn choice ->
      branch_choice_validation(choice)
    end)
  end

  defp branch_choice_validation([{:choice, choices} | remaining]) do
    throw(
      "Connot have operations after a choice (e.g. +{!A()}.!B()). Session type #{
        st_to_string(remaining)
      } is invalid after #{st_to_string([{:choice, choices}])}."
    )

    [false]
  end

  defp branch_choice_validation([{:call_recurse, _label} | remaining]) do
    [true | branch_choice_validation(remaining)]
  end

  defp branch_choice_validation([{:recurse, _label, _body} | remaining]) do
    [true | branch_choice_validation(remaining)]
  end

  defp branch_choice_validation([]) do
    [true]
  end

  defp branch_choice_validation(x) do
    throw("unknown #{inspect(x)}")
    [false]
  end

  @spec st_to_string(session_type()) :: String.t()
  def st_to_string(session_type)

  def st_to_string(body) when is_list(body) do
    Enum.map(body, fn x -> st_to_string(x) end)
    |> Enum.join(".")
  end

  def st_to_string({:recv, label, types}) do
    types_string = types |> Enum.join(", ")
    "?#{label}(#{types_string})"
  end

  def st_to_string({:send, label, types}) do
    types_string = types |> Enum.join(", ")
    "!#{label}(#{types_string})"
  end

  def st_to_string({:call_recurse, label}) do
    "#{label}"
  end

  def st_to_string({:recurse, label, body}) do
    "rec #{label}.(#{st_to_string(body)})"
  end

  def st_to_string({:branch, body}) when is_list(body) do
    v =
      Enum.map(body, fn x -> st_to_string(x) end)
      |> Enum.join(", ")

    "&{#{v}}"
  end

  def st_to_string({:choice, body}) when is_list(body) do
    v =
      Enum.map(body, fn x -> st_to_string(x) end)
      |> Enum.join(", ")

    "+{#{v}}"
  end

  def st_to_string(_) do
    throw("Parsing to string problem. Unknown input")
    ""
  end

  @doc """
  Fixes structure of sessionn types. E.g. &{!A()}.!B() becomes &{!A().!B()}
  """
  @spec fix_structure_branch_choice(session_type()) :: session_type()
  def fix_structure_branch_choice([{:send, label, types} | remaining]) do
    [{:send, label, types} | fix_structure_branch_choice(remaining)]
  end

  def fix_structure_branch_choice([{:recv, label, types} | remaining]) do
    [{:recv, label, types} | fix_structure_branch_choice(remaining)]
  end

  def fix_structure_branch_choice([{:branch, branches}]) do
    [{:branch, Enum.map(branches, fn branch -> fix_structure_branch_choice(branch) end)}]
  end

  def fix_structure_branch_choice([{:branch, branches} | remaining]) do
    final = [{:branch, Enum.map(branches, fn branch -> fix_structure_branch_choice(branch ++ fix_structure_branch_choice(remaining)) end)}]

    # _ = Logger.warn("Fixing structure of session type: \n#{st_to_string(initial)} was changed to\n#{st_to_string(final)}")
    final
  end

  def fix_structure_branch_choice([{:choice, choices}]) do
    [{:choice, Enum.map(choices, fn choice -> fix_structure_branch_choice(choice) end)}]
  end

  def fix_structure_branch_choice([{:choice, choices} | remaining]) do
    final = [{:choice, Enum.map(choices, fn choice -> fix_structure_branch_choice(choice ++ fix_structure_branch_choice(remaining)) end)}]

    # _ = Logger.warn("Fixing structure of session type: \n#{st_to_string(initial)} was changed to\n#{st_to_string(final)}")
    final


  end

  def fix_structure_branch_choice([{:call_recurse, label} | remaining]) do
    [{:call_recurse, label} | fix_structure_branch_choice(remaining)]
  end

  def fix_structure_branch_choice([{:recurse, label, body} | remaining]) do
    [{:recurse, label, fix_structure_branch_choice(body)} | fix_structure_branch_choice(remaining)]
  end

  def fix_structure_branch_choice([]) do
    []
  end

  def fix_structure_branch_choice(x) do
    throw("fix_structure_branch_choice unknown #{inspect(x)}")
    []
  end

  # recompile && ElixirSessions.Parser.run
  def run() do
    _leex_res = :leex.file('src/lexer.xrl')
    # returns {ok, Scannerfile} | {ok, Scannerfile, Warnings} | error | {error, Errors, Warnings}

    # S_ponger=rec X.(&{?Ping().!Pong().X, ?Quit().end})
    # S_smtp = ?M220(msg: String).+{ !Helo(hostname: String).?M250(msg: String). rec X.(+{ !MailFrom(addr: String). ?M250(msg: String) . rec Y.(+{ !RcptTo(addr: String).?M250(msg: String).Y, !Data().?M354(msg: String).!Content(txt: String).?M250(msg: String).X, !Quit().?M221(msg: String) }), !Quit().?M221(msg: String)}), !Quit().?M221(msg: String) }

    # source = "rec X.(!Hello1().&{?Ping().!Pong().X, ?Quit().end}.?Hello())"
    source = "rec X.(!Hello1().&{?Ping().!Pong().X, ?Quit().&{?sefe()}.?Hello()}.!HEELeL())"
    # "?Hello().!ABc(number).!ABc(number, number).&{?Hello().?Hello2(), ?Hello(number)}"
    # "?M220(msg: String).+{ !Helo(hostname: String).?M250(msg: String). rec X.(+{ !MailFrom(addr: String). ?M250(msg: String) . rec Y.(+{ !RcptTo(addr: String).?M250(msg: String).Y, !Data().?M354(msg: String).!Content(txt: String).?M250(msg: String).X, !Quit().?M221(msg: String) }), !Quit().?M221(msg: String)}), !Quit().?M221(msg: String) }"

    _res = [
      {:recv, :M220, [:String]},
      {:choice,
       [
         [
           {:send, :Helo, [:String]},
           {:recv, :M250, [:String]},
           {:recurse, :X,
            [
              choice: [
                [
                  {:send, :MailFrom, [:String]},
                  {:recv, :M250, [:String]},
                  {:recurse, :Y,
                   [
                     choice: [
                       [
                         {:send, :RcptTo, [:String]},
                         {:recv, :M250, [:String]},
                         {:call_recurse, :Y}
                       ],
                       [
                         {:send, :Data, []},
                         {:recv, :M354, [:String]},
                         {:send, :Content, [:String]},
                         {:recv, :M250, [:String]},
                         {:call_recurse, :X}
                       ],
                       [{:send, :Quit, []}, {:recv, :M221, [:String]}]
                     ]
                   ]}
                ],
                [{:send, :Quit, []}, {:recv, :M221, [:String]}]
              ]
            ]}
         ],
         [{:send, :Quit, []}, {:recv, :M221, [:String]}]
       ]}
    ]

    parse(source)
    # |> st_to_string()
  end
end

defmodule Helpers do
  @moduledoc false
  def extract_token({_token, _line, value}), do: value
  def to_atom(':' ++ atom), do: List.to_atom(atom)
end
