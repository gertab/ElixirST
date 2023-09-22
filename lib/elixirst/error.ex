defmodule ElixirSTError do
  defexception message: "ElixirST exception.", lines: []

  def message(%{lines: [], message: message}) do
    # Line unknown
    "[Line 0] " <> message
  end

  def message(%{lines: lines, message: message}) do
    "[Line #{inspect(List.last(lines))}] [#{inspect(lines)}] " <> message
  end
end
