defmodule ElixirSessions.Duality do
  # Session type duality.
  # Given a session type, `dual(s)` is able to get  dual session type of `s`.

  @moduledoc false
  require Logger
  require ST
  alias ElixirSessions.Parser



  @type ast :: ST.ast()
  @type session_type :: ST.session_type()

  # Returns the dual of the session type `session_type`
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
    # s1 = "branch<neg2: receive '{number, pid}' . send '{number}'>"
    # s1 = "choice<neg2: send '{number, pid}' . receive '{number}'>"
    session1 = Parser.parse(s1)

    session2 = dual(session1)

    IO.inspect(session1)
    IO.inspect(session2)

    :ok
  end
end
