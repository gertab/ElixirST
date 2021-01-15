defmodule ElixirSessions.Duality do
  require Logger
  alias ElixirSessions.Parser
  def dual?(session1, session2) do
    dual2?(session1, session2)
  end

  defp dual2?({:ok, tokens1}, {:ok, tokens2}) do
    IO.inspect(tokens1)
    IO.inspect(tokens2)
    result = check(tokens1, tokens2, %{})
    IO.inspect(result)

    result
  end

  defp check([current1 | remaining1], [current2 | remaining2], recurse) do
    # if current1 = {:call_recurse, label}, then add body to first part
    check(current1, current2, recurse) && check(remaining1, remaining2, recurse)
  end

  defp check([], [], _) do
    true
  end

  defp check([], [_|_], _) do
    # If server mode, may never end
    false
  end
  defp check([_|_], [], _) do
    false
  end

  defp check({:send, _}, {:recv, _}, _) do
    true
  end

  defp check({:send, _}, {:send, _}, _) do
    Logger.error("Expected send and receive; got send and send")

    false
  end

  defp check({:recv, _}, {:send, _}, _) do
    true
  end

  defp check({:recv, _}, {:recv, _}, _) do
    Logger.error("Expected receive and receive; got receive and receive")

    false
  end

  defp check({:choice, a}, {:branch, b}, recurse) do
    check({:branch, b}, {:choice, a}, recurse)
  end

  defp check({:branch, options1}, {:choice, options2}, recurse) do
    r = Enum.reduce(options1, true, fn({label, body1}, accumulator) ->
      result = case Map.fetch(options2, label) do
        {:ok, body2} -> check(body1, body2, recurse)
        _ -> Logger.error("Choosing a nonexisting label: #{IO.inspect label}")
            false
      end

      accumulator && result # All need to match
      # accumulator || result # One match is enough
    end)

    if !r do
      Logger.error("Choosing a nonexisting label")
    end

    r
  end

  # # rec X .(send 'any' . X)
  # # {:recurse, :X, [send: 'any', call_recurse: :X]}
  # defp check({:recurse, label, body}, recurse) do
  #   Map.put(recurse, label, body)
  # end

  # defp check({:call_recurse, label}, _, recurse) do
  # end

  defp check(_, _, _) do
    false
  end

  # recompile && ElixirSessions.Duality.run
  def run() do
    # s1 = "send 'any' . send 'any' . receive 'any'"
    # s2 = "choice<neg: receive 'any'>"
    # s1 = "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'> . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"
    # s2 = "send '{label}' . choice<neg: send '{number, pid}' . receive '{number}'> . choice<neg: send '{number, pid}' . receive '{number}'>"
    s1 = "branch<neg2: receive '{number, pid}' . send '{number}'>"
    s2 = "choice<neg2: send '{number, pid}' . receive '{number}'>"
    session1 = Parser.parse(s1)
    session2 = Parser.parse(s2)

    dual2?(session1, session2)

    :ok
  end
end
