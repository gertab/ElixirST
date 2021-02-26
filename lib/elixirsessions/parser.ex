defmodule ElixirSessions.Parser do
  @moduledoc """
  Documentation for ElixirSessions.Parser.
  Parses the input to a Elixir data as session types.
  """
  require Logger

  @doc """
  Parses a session type from a string to an Elixir datatype.

  ## Examples

      iex> s = "!Hello() . ?Receive(Integer)"
      ...> ElixirSessions.Parser.parse(s)
      [{:send, :Hello, []}, {:recv, :Receive, [:Integer]}]

  """
  def parse(string) when is_bitstring(string), do: string |> String.to_charlist() |> parse()

  def parse(string) do
    with {:ok, tokens, _} <- lexer(string) do
      {:ok, session_type} = :parse.parse(tokens)
      # IO.inspect(session_type)
      session_type
      # todo add function: validate_session_type (to check when using branch all branches start with a 'receive' statement, and when using a choice ensure that all options start with a 'send' statement)
    else
      err -> err
    end
  end

  defp lexer(string) do
    # IO.inspect tokens
    :lexer.string(string)
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
  def extract_token({_token, _line, value}), do: value
  def to_atom(':' ++ atom), do: List.to_atom(atom)
end
