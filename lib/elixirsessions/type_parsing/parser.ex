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


  def run() do
    :leex.file('src/lexer.xrl')
    source = "[one: 1, two: 2]"
    parse(source)
  end
  # Application.app_dir(:my_app, "priv/lexer.xrl")

  # run(2)

  # {:ok, tokens, _} = source |> String.to_char_list |> :lexer.string
  # compile("priv/lexer.erl")
  # :lexer.parse("hello")

  # IO.inspect(tokens)

end
