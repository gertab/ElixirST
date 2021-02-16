defmodule ElixirSessions.SessionTypechecking do
  require ElixirSessions.Common
  @moduledoc """
  Given a session type and Elixir code, the Elixir code is typechecked against the session type.
  """
  @typedoc false
  @type ast :: ElixirSessions.Common.ast()
  @typedoc false
  @type info :: ElixirSessions.Common.info()
  @typedoc false
  @type session_type :: ElixirSessions.Common.session_type()

  @doc """
  Given a function (and its body), it is compared to a session type. `fun` is the function name and `body` is the function body as AST.

  Examples
  iex> ast = quote do
  ...>   def ping() do
  ...>     send(self(), {:hello})
  ...>   end
  ...> end
  ...> ElixirSessions.Inference.infer_session_type(:ping, ast)
  [send: 'type']
  """
  @spec session_typecheck(atom(), integer(), ast(), session_type()) :: boolean()
  def session_typecheck(fun, arity, body, session_type) do
    IO.puts("Session typechecking of &#{to_string fun}/#{arity}")

    info = %{
      call_recursion: fun,
      function_name: fun,
      arity: arity
    }

    session_typecheck(body, session_type, info)

    # case contains_recursion?(inferred_session_type) do
    #   true -> [{:recurse, :X, inferred_session_type}]
    #   false -> inferred_session_type
    # end

    true
  end


  @doc """
  Traverses the given Elixir `ast` and session-typechecks it with respect to the `session_type`.
  """
  @spec session_typecheck(ast(), session_type(), info()) :: boolean()
  def session_typecheck(body, session_type, info)
  def session_typecheck(body, session_type, info) do
    true
  end
end
