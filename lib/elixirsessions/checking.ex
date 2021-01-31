defmodule ElixirSessions.Checking do
  require Logger

  @moduledoc """
  This module is the starting point of ElixirSessions. It parses the `@session` attribute and starts the AST code comparison with the session type.
  """

  defmacro __using__(_) do
    quote do
      import ElixirSessions.Checking

      Module.register_attribute(__MODULE__, :session, accumulate: true)
      # Module.register_attribute(__MODULE__, :session_hook, accumulate: true)

      @on_definition ElixirSessions.Checking

      IO.puts("ElixirSession started in #{IO.inspect __MODULE__}")
    end
  end

  # Definition of a function head, therefore do nothing
  def __on_definition__(_env, _access, _name, _args, _guards, nil), do: nil
  def __on_definition__(_env, _access, _name, _args, _guards, []), do: nil

  def __on_definition__(env, _access, _name, _args, _guards, _body) do

    if sessions = Module.get_attribute(env.module, :session) do

      if length(sessions) > 0 do
        [session | _ ] = sessions
        s = ElixirSessions.Parser.parse(session)
        case s do
          {:ok , _session_type} -> :ok
          # {:ok , session_type} -> ElixirSessions.Code.walk_ast(name, body, session_type)
          _                    -> _ = Logger.error("Leex error")
                                  :ok
        end
        # ElixirSessions.Parser.parse(session)
        # IO.inspect(name)
      end
    end
    # IO.inspect(body)
    :ok
  end
end
