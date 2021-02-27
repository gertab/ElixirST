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
      validate(session_type)
      session_type

      # todo add function: validate_session_type (to check when using branch all branches start with a 'receive' statement, and when using a choice ensure that all options start with a 'send' statement)
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

  @spec validate(session_type()) :: boolean()
  def validate(session_type)

  def validate(body) when is_list(body) do
    v = Enum.map(body, fn x -> validate(x) end)

    # AND operation in list: [t, t, f, t] -> f
    if false in v do
      false
    else
      true
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
    v =
      Enum.map(body, fn
        [{:recv, _label, _types}] ->
          true

        [{:recv, _label, _types} | y] ->
          y

        x ->
          throw(
            "Session type parsing validation error: Each branch needs a receive as the first statement: #{
              inspect(x)
            }"
          )
          false
      end)

    # AND operation
    if false in v do
      false
    else
      true
    end
  end

  def validate({:choice, body}) when is_list(body) do
    v =
      Enum.map(body, fn
        [{:send, _label, _types}] ->
          true

        [{:send, _label, _types} | y] ->
          y

        x ->
          throw(
            "Session type parsing validation error: Each branch needs a send as the first statement: #{
              inspect(x)
            }"
          )

          false
      end)

    # AND operation
    if false in v do
      false
    else
      true
    end
  end

  def validate(_) do
    throw("Validation problem. Unknown input")
    false
  end

  # recompile && ElixirSessions.Parser.run
  def run() do
    _leex_res = :leex.file('src/lexer.xrl')
    # returns {ok, Scannerfile} | {ok, Scannerfile, Warnings} | error | {error, Errors, Warnings}

    # source = "branch<neg: send 'any', neg2: send 'any'>"
    # source = "send '{:ping, pid}' . receive '{:pong}'"
    # source = "send '{string}' . choice<neg: send '{number, pid}' . receive '{number}'>"
    # source = " send 'any'.  rec X ( send 'any' . receive 'any' . rec Y. ( send '{number}' . receive '{any}' . rec Z . ( Z ) . receive '{any}' . Y ) . X )"
    # S_ponger=rec X.(&{?Ping().!Pong().X, ?Quit().end})
    # S_smtp = ?M220(msg: String).+{ !Helo(hostname: String).?M250(msg: String). rec X.(+{ !MailFrom(addr: String). ?M250(msg: String) . rec Y.(+{ !RcptTo(addr: String).?M250(msg: String).Y, !Data().?M354(msg: String).!Content(txt: String).?M250(msg: String).X, !Quit().?M221(msg: String) }), !Quit().?M221(msg: String)}), !Quit().?M221(msg: String) }

    source =
      "?M220(msg: String).+{ !Helo(hostname: String).?M250(msg: String). rec X.(+{ !MailFrom(addr: String). ?M250(msg: String) . rec Y.(+{ !RcptTo(addr: String).?M250(msg: String).Y, !Data().?M354(msg: String).!Content(txt: String).?M250(msg: String).X, !Quit().?M221(msg: String) }), !Quit().?M221(msg: String)}), !Quit().?M221(msg: String) }"

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
  end
end

defmodule Helpers do
  @moduledoc false
  def extract_token({_token, _line, value}), do: value
  def to_atom(':' ++ atom), do: List.to_atom(atom)
end
