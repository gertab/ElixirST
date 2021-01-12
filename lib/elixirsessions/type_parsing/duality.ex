defmodule ElixirSessions.Duality do
  alias ElixirSessions.Parser
  def dual?(session1, session2) do
    dual2?(session1, session2)
  end

  defp dual2?({:ok, tokens1}, {:ok, tokens2}) do
    IO.inspect(tokens1)
    IO.inspect(tokens2)
    result = check(tokens1, tokens2)
    IO.inspect(result)

    result
  end

  defp check([], []) do
    true
  end

  defp check([current1], [current2]) do
    case current1 do
      {:send, _} -> case current2 do
                        {:recv, _} -> true
                        _          -> false
                    end
      {:recv, _} -> case current2 do
                        {:send, _} -> true
                        _          -> false
                    end
      _ -> {:unknowncase, :false}
    end
  end

  defp check([current1 | remaining1], [current2 | remaining2]) do
    check([current1], [current2]) && check(remaining1, remaining2)
  end

  # recompile && ElixirSessions.Duality.run
  def run() do
    s1 = "send 'any' . send 'any' . receive 'any'"
    s2 = "receive 'any' . receive 'any' . send 'any'"


    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    dual2?(session1, session2)

    :ok
  end
end
