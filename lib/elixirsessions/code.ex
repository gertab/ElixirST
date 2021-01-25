defmodule ElixirSessions.Code do
  @moduledoc """
  Performs the AST comparison with the session types.
  """

  @doc """
  Given a function (and its body), it is compared to a session type. `fun` is the function name and `body` is the function body as AST.
  """
  def walk_ast(fun, body, session_type) do
    IO.inspect(fun)
    IO.inspect(body)
    IO.puts(Macro.to_string(body))

    IO.inspect(session_type)

    # Macro.prewalk(body, fn x -> IO.inspect x end)
  end

  # recompile && ElixirSessions.Code.run
  def run() do
    fun = :ping
    body = quote do
      IO.puts("Sending ping to #{inspect pid}")
      send(pid, {:ping, self()})

      receive do
        {:pong} ->
          IO.puts("Received pong!")
      end
    end
    session_type = [send: '{:ping, pid}', recv: '{:pong}']

    walk_ast(fun, body, session_type)
  end
end
