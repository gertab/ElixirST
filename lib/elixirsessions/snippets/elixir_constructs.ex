defmodule ElixirSessions.Constructs do

  # if
  if false do
    "if"
  end

  # Pattern matching in 'case'
  case {1, 2} do
    {1, x} ->
      x
    {_, x} ->
      x
    _ ->
      "Any value"
  end

  # Anonymous Functions
  square = fn(x) -> x * x end
  square.(2)

  # Function
  def plus1(x) when is_number(x) do
    x + 1
  end


  # Actors
  spawn(fn -> 1 + 1 end)

  send(self(), {:number, 3})

  receive do
    {:number, x} -> x
    {:letter, y} -> y
  end

  #### Others

  # Cond - checks many constructs
  cond do
    1 + 1 == 3 ->
      "First condition"
    false ->
      "False"
    true ->
      "Default"
  end

  try do
    throw(:hello)
  catch
    message -> "Message: #{message}"
  after
    "After.."
  end

end
