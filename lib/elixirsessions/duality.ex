defmodule ElixirSessions.Duality do
  @moduledoc """
  Session type duality.
  Given a session type, `dual(s)` is able to get  dual session type of `s`.

  ## Examples
      iex> st_string = "!Ping(Integer).?Pong(String)"
      ...> st = ElixirSessions.Parser.parse(st_string)
      ...> st_dual = ElixirSessions.Duality.dual(st)
      %ST.Recv{
        label: :Ping,
        next: %ST.Send{label: :Pong, next: %ST.Terminate{}, types: [:string]},
        types: [:integer]
      }
      ...> ST.st_to_string(st_dual)
      "?Ping(integer).!Pong(string)"

  """
  require Logger
  require ST
  alias ElixirSessions.Parser

  @typedoc false
  @type ast :: ST.ast()
  @typedoc false
  @type session_type :: ST.session_type()

  @doc """
  Returns the dual of the session type `session_type`

  ## Examples
      iex> s = %ST.Recurse{label: :X, body: %ST.Send{label: :Hello, types: [], next: %ST.Call_Recurse{label: :X}}}
      ...> ElixirSessions.Duality.dual(s)
      %ST.Recurse{
        body: %ST.Recv{label: :Hello, next: %ST.Call_Recurse{label: :X}, types: []},
        label: :X
      }
  """
  @spec dual(session_type()) :: session_type()
  def dual(session_type)

  def dual(%ST.Send{label: label, types: types, next: next}) do
    %ST.Recv{label: label, types: types, next: dual(next)}
  end

  def dual(%ST.Recv{label: label, types: types, next: next}) do
    %ST.Send{label: label, types: types, next: dual(next)}
  end

  def dual(%ST.Choice{choices: choices}) do
    %ST.Branch{branches: Enum.map(choices, fn choice -> dual(choice) end)}
  end

  def dual(%ST.Branch{branches: branches}) do
    %ST.Choice{choices: Enum.map(branches, fn branche -> dual(branche) end)}
  end

  def dual(%ST.Recurse{label: label, body: body}) do
    %ST.Recurse{label: label, body: dual(body)}
  end

  def dual(%ST.Call_Recurse{} = st) do
    st
  end

  def dual(%ST.Terminate{} = st) do
    st
  end

  # defp compute_dual(tokens) do
  #   _ = Logger.error("Unknown input type for #{IO.puts(tokens)}")
  # end

  # recompile && ElixirSessions.Duality.run_dual
  def run_dual() do
    s1 = "rec X . (!Hello() . X)"
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
end
