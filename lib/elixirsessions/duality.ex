defmodule ElixirSessions.Duality do
  require Logger
  alias ElixirSessions.Parser

  @moduledoc """
  Session type duality.
  Given a session type, `dual(s)` is able to get  dual session type of `s`. `dual?(s1, s2)` checks if `s1` is the dual of `s2`.
  """

  @doc """
  Returns the dual of the session type `session_type`

  ## Examples
      iex> s = {:ok, [choice: %{neg: [recv: 'any']}]}
      ...> ElixirSessions.Duality.dual(s)
      {:ok, [branch: %{neg: [send: 'any']}]}
  """
  def dual(session_type) do
    compute_dual(session_type)
  end

  defp compute_dual({:ok, tokens}) do
    {:ok, compute_dual(tokens)}
  end

  defp compute_dual({:send, tokens}) do
    {:recv, tokens}
  end

  defp compute_dual({:recv, tokens}) do
    {:send, tokens}
  end

  defp compute_dual({:branch, tokens}) do
    m =
      Enum.map(tokens, fn {label, body} ->
        {label, compute_dual(body)}
      end)

    {:choice, Enum.into(m, %{})}
  end

  defp compute_dual({:choice, tokens}) do
    m =
      Enum.map(tokens, fn {label, body} ->
        {label, compute_dual(body)}
      end)

    {:branch, Enum.into(m, %{})}
  end

  defp compute_dual({:recurse, label, body}) do
    {:recurse, label, compute_dual(body)}
  end

  defp compute_dual({:call_recurse, label}) do
    {:call_recurse, label}
  end

  defp compute_dual(tokens) when is_list(tokens) do
    Enum.map(tokens, fn
      x -> compute_dual(x)
    end)
  end

  defp compute_dual(tokens) do
    _ = Logger.error("Unknown input type for #{IO.puts(tokens)}")
  end

  # recompile && ElixirSessions.Duality.run_dual
  def run_dual() do
    s1 = "rec X . (send 'any' . X)"
    # s1 = "choice<neg: receive 'any'>"
    # s1 = "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"
    # s1 = "send '{label}' . choice<neg: send '{number, pid}' . receive '{number}'> . choice<neg: send '{number, pid}' . receive '{number}'>"
    # s1 = "branch<neg2: receive '{number, pid}' . send '{number}'>"
    # s1 = "choice<neg2: send '{number, pid}' . receive '{number}'>"
    session1 = Parser.parse(s1)

    session2 = dual(session1)

    IO.inspect(session1)
    IO.inspect(session2)

    :ok
  end

  @doc """
  `dual?(session1, session2)` checks if the session type `session1` is the dual of `session2`

  `dual?/2` not working correctly (todo: recursive)

  ## Examples
      iex> s1 = "branch<neg2: receive '{number, pid}' . send '{number}'>"
      ...> s2 = "choice<neg2: send '{number, pid}' . receive '{number}'>"
      ...> session1 = ElixirSessions.Parser.parse(s1)
      ...> session2 = ElixirSessions.Parser.parse(s2)
      ...> ElixirSessions.Duality.dual?(session1, session2)
      true
  """
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

  defp check([], [_ | _], _) do
    # If server mode, may never end
    false
  end

  defp check([_ | _], [], _) do
    false
  end

  defp check({:send, _}, {:recv, _}, _) do
    true
  end

  defp check({:send, _}, {:send, _}, _) do
    _ = Logger.error("Expected send and receive; got send and send")

    false
  end

  defp check({:recv, _}, {:send, _}, _) do
    true
  end

  defp check({:recv, _}, {:recv, _}, _) do
    _ = Logger.error("Expected receive and receive; got receive and receive")

    false
  end

  defp check({:branch, a}, {:choice, b}, recurse) do
    check({:choice, b}, {:branch, a}, recurse)
  end

  defp check({:choice, options1}, {:branch, options2}, recurse) do
    r =
      Enum.reduce(options1, true, fn {label, body1}, accumulator ->
        result =
          case Map.fetch(options2, label) do
            {:ok, body2} ->
              check(body1, body2, recurse)

            _ ->
              _ = Logger.error("Choosing a nonexisting label: #{IO.inspect(label)}")
              false
          end

        # All need to match
        accumulator && result
        # accumulator || result # One match is enough
      end)

    # case r do
    #   :ok ->
    #     :ok

    #   {:error, _} ->
    #     _ = Logger.error("Choosing a nonexisting label")

    #   nil ->
    #     _ = Logger.error("Choosing a nonexisting label")
    # end

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

  # recompile && ElixirSessions.Duality.run_dual?
  def run_dual?() do
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
