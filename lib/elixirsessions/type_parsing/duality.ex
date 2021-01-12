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

  defp check([current1 | remaining1], [current2 | remaining2]) do
    check(current1, current2) && check(remaining1, remaining2)
  end

  defp check([], []) do
    true
  end

  defp check({:send, _}, {:recv, _}) do
    true
  end

  defp check({:send, _}, {:send, _}) do
    false
  end

  defp check({:recv, _}, {:send, _}) do
    true
  end

  defp check({:recv, _}, {:recv, _}) do
    false
  end

  defp check({:choice, a}, {:branch, b}) do
    check({:branch, b}, {:choice, a})
  end

  defp check({:branch, options}, {:choice, {label, b}}) do
    case Map.fetch(options, label) do
      {:ok, a} -> check(a, b)
      _ -> false
    end
  end

  defp check(_, _) do
    false
  end

  # recompile && ElixirSessions.Duality.run
  def run() do
    # s1 = "send 'any' . send 'any' . receive 'any'"
    s1 = "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"
    # s2 = "choice<neg: receive 'any'>"
    s2 = "send '{label}' . choice<neg: send '{number, pid}' . receive '{number}'>"


    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    dual2?(session1, session2)

    :ok
  end
end
