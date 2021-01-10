defmodule ElixirSessions.Parser do
  def parse(string) when is_bitstring(string), do: string |> String.to_charlist() |> parse()
  def parse(string) do
    with {:ok, tokens, _} <- :lexer.string(string) do
      IO.inspect tokens
      # :parse.parse(tokens)
    else
      err -> err
    end
  end

  #recompile && ElixirSessions.Parser.run
  def run() do
    :leex.file('src/lexer.xrl')
    source = "[one: 1, two: 2, trt: 4] send <> receive.send_choice<jejnf:'sdds23'>"
    parse(source)
  end
end
