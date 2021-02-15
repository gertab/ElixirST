defmodule ElixirSessions.Parser do
  @moduledoc """
  Documentation for ElixirSessions.Parser.
  Parses the input to a Elixir data as session types.
  """
  require Logger

  @doc """
  Parses a session type from a string to an Elixir datatype.

  ## Examples

      iex> s = "send '{number()}' . receive '{number()}'"
      ...> ElixirSessions.Parser.parse(s)
      [send: '{number()}', recv: '{number()}']

  """
  def parse(string) when is_bitstring(string), do: string |> String.to_charlist() |> parse()

  def parse(string) do
    with {:ok, tokens, _} <- lexer(string) do
      {:ok, session_type} = :parse.parse(tokens)
      session_type
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
    source =
      "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"

    parse(source)
  end
end

defmodule Helpers do
  def extract_token({_token, _line, value}), do: value
  def to_atom(':' ++ atom), do: List.to_atom(atom)
end
