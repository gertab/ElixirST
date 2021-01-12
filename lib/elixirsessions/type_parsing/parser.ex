defmodule ElixirSessions.Parser do
  def parse(string) when is_bitstring(string), do: string |> String.to_charlist() |> parse()
  def parse(string) do
    with {:ok, tokens, _} <- :lexer.string(string) do
      # IO.inspect tokens
      :parse.parse(tokens)
    else
      err -> err
    end
  end

  #recompile && ElixirSessions.Parser.run
  @spec run ::
          {:error, any}
          | {:ok,
             nonempty_maybe_improper_list(
               nonempty_maybe_improper_list(any, [] | tuple) | tuple,
               [] | tuple
             )
             | tuple}
          | {:error, {any, :lexer, {any, any}}, any}
  def run() do
    :leex.file('src/lexer.xrl')
    # source = "send '{:ping, pid}' . receive '{:pong}'"
    # source = "send '{string}' . choice<neg: send '{number, pid}' . receive '{number}'>"
    source = " rec X ( send 'any' . receive 'any' . rec Y. ( send '{number}' . receive '{any}' . rec Z . ( Z ) . receive '{any}' . Y ) . X )"
    parse(source)
  end
end
