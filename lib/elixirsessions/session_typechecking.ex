defmodule ElixirSessions.SessionTypechecking do
  @moduledoc """
  Given a session type and Elixir code, the Elixir code is typechecked against the session type.
  """

  @typedoc """
  Abstract Syntax Tree (AST)
  """
  @type ast() :: Macro.t()

  @typedoc """
  Information related to a function body.
  """
  @type info() :: %{
          # recursion: boolean(),
          call_recursion: atom,
          function_name: atom
          # session_type: any
          # todo maybe add __module__
        }

  @typep branch_type() :: %{atom => session_type}

  @typep choice_type() :: %{atom => session_type}

  @typedoc """
  A session type list of session operations.

  A session type may: `receive` (or dually `send` data), `branch` (or make a `choice`) or `recurse`.
  """
  @type session_type() ::
          [
            {:recv, any}
            | {:send, any}
            | {:branch, branch_type}
            | {:call_recurse, any}
            | {:choice, choice_type}
            | {:recurse, any, session_type}
          ]

  @doc """
  Given a function (and its body), it is compared to a session type. `fun` is the function name and `body` is the function body as AST.

  ## Examples
          iex> ast = quote do
          ...>   def ping() do
          ...>     send(self(), {:hello})
          ...>   end
          ...> end
          ...> ElixirSessions.Inference.walk_ast(:ping, ast, nil)
          [send: 'type']
  """
  @spec walk_ast(atom(), ast(), session_type()) :: session_type()
  def walk_ast(fun, body, session_type) do
    # IO.inspect(fun)
    # IO.inspect(body)

    # infer_session_type_incl_recursion(fun, body)
    []
  end
end
