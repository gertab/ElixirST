defmodule ElixirSessions.Parser do
  def parse(string) when is_bitstring(string), do: string |> String.to_charlist() |> parse()
  def parse(string) do
    with {:ok, tokens, _} <- :lexer.string(string) do
      IO.inspect tokens
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
    # source = "receive '{:ping, pid}' . send '{:pong}' . send 'any' . send_choice <lBbel2: send 'any' . receive 'any'>"
    source = "receive '{:ping, pid}' . send '{:pong}' . send 'any' . offer_option <lBbel2: send 'any' . receive 'any', lBbel3: send 'any' . receive 'any'>"
    # source = "receive '{:ping, pid}'"
    parse(source)
  end
end
