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
  @typep session_context :: %{atom() => session_type()}

  @doc """
  Given a function (and its body), it is compared to a session type. `fun` is the function name and `body` is the function body as AST.

  Examples
  iex> ast = quote do
  ...>   def ping() do
  ...>     send(self(), {:hello})
  ...>   end
  ...> end
  ...> ElixirSessions.Inference.infer_session_type(:ping, ast)
  [{:send, :hello, []}]
  """
  @spec session_typecheck(atom(), arity(), ast(), session_type()) :: true
  def session_typecheck(fun, arity, body, session_type) do
    IO.puts("Session typechecking of &#{to_string(fun)}/#{arity}")

    info = %{
      call_recursion: fun,
      function_name: fun,
      arity: arity
    }

    IO.puts("Session typechecking: #{inspect session_type}")
    _ = session_typecheck_ast(body, session_type, info, %{})

    # case contains_recursion?(inferred_session_type) do
    #   true -> [{:recurse, :X, inferred_session_type}]
    #   false -> inferred_session_type
    # end

    true
  end

  @doc """
  Traverses the given Elixir `ast` and session-typechecks it with respect to the `session_type`.
  """
  @spec session_typecheck_ast(ast(), session_type(), info(), session_context()) ::
          {boolean(), session_type()}
  def session_typecheck_ast(body, session_type, info, session_context)

  # literals
  def session_typecheck_ast(x, session_type, _info, _session_context)
      when is_atom(x) or is_number(x) or is_binary(x) do
    {false, session_type}
  end

  def session_typecheck_ast({_a, _b}, session_type, _info, _session_context) do
    # IO.puts("\nTuple: ")

    # todo check if ok, maybe check each element
    {false, session_type}
  end

  def session_typecheck_ast({type, _, _} = ast, [session_type], info, session_context) when type not in [:__block__]do
    # session_type is a list of size 1
    session_typecheck_ast(ast, session_type, info, session_context)
  end

  def session_typecheck_ast(args, session_type, info, session_context)
      when is_list(args) and is_list(session_type) do
    IO.puts("\nlist:")

    if length(args) != length(session_type) do
      {_, meta, _} = hd(args)

      if meta[:line] do
        throw(
          "Session type error (line #{inspect meta[:line]}): Session type size (#{length(session_type)}) is not equal to block size (#{
            length(args)
          })"
        )
      else
        throw(
          "Session type error: Session type size (#{length(session_type)}) is not equal to block size (#{
            length(args)
          })"
        )
      end
    end

    Enum.zip(args, session_type)
    |> Enum.map(fn {ast, s_t} ->
      # IO.puts("#{inspect(ast)} ## #{inspect(s_t)}")
      session_typecheck_ast(ast, s_t, info, session_context)
    end)

    # {_, remaining_session_type} =
    #   Enum.map_reduce(args, session_type, fn elem, s_t ->
    #     case is_list(session_type) do
    #       true ->
    #         case session_typecheck_ast(elem, hd(s_t), info, session_context) do
    #           {true, _} -> tl(s_t)
    #           {false, _} -> s_t
    #         end
    #       false ->
    #         :ok
    #     end
    #   end)
    # length(remaining_session_type) == 0
  end

  def session_typecheck_ast(args, session_type, _info, _session_context) when is_list(args) do
    {false, session_type}
  end

  # Non literals
  def session_typecheck_ast({:__block__, _meta, args}, session_type, info, session_context) do
    session_typecheck_ast(args, session_type, info, session_context)
  end

  def session_typecheck_ast(
        {:case, _meta, [_what_you_are_checking, body]},
        session_type,
        _info,
        _session_context
      )
      when is_list(body) do
    {false, session_type}
  end

  def session_typecheck_ast({:=, _meta, [_left, _right]}, session_type, _info, _session_context) do
    {false, session_type}
  end

  def session_typecheck_ast({:send, meta, _}, session_type, _info, _session_context) do
    IO.puts("[in send] #{inspect session_type}")

    line = if meta[:line] do
      meta[:line]
    else
      "unknown"
    end

    case session_type do
      {:recv, type} -> throw("Session type error [line #{line}]: expected a 'receive #{IO.inspect type}' but found a send statement.")
      {:send, _type} -> :ok
      s_t when is_list(s_t) -> throw("[send] todo: good but not implemented yet")
    end

    {false, session_type}
  end

  def session_typecheck_ast({:receive, meta, [_body]}, session_type, _info, _session_context) do
    # body contains [do: [ {:->, _, [ [ when/condition ], work ]}, other_cases... ] ]

    line = if meta[:line] do
      meta[:line]
    else
      "unknown"
    end

    case session_type do
      {:send, type} -> throw("Session type error [line #{line}]: expected a 'send #{IO.inspect type}' but found a receive statement.")
      {:recv, _type} -> :ok
      s_t when is_list(s_t) -> throw("[receive] todo: Good but not implemented yet")
    end


    {false, session_type}
  end

  def session_typecheck_ast({:->, _meta, [_head | _body]}, session_type, _info, _session_context) do
    {false, session_type}
  end

  def session_typecheck_ast({:|>, _meta, _args}, session_type, _info, _session_context) do
    {false, session_type}
  end

  def session_typecheck_ast(
        {fun, _meta, [_function_name, _body]},
        session_type,
        _info,
        _session_context
      )
      when fun in [:def, :defp] do
    {false, session_type}
  end

  def session_typecheck_ast(_, session_type, _info, _session_context) do
    {false, session_type}
  end

  # recompile && ElixirSessions.SessionTypechecking.run
  def run() do
    fun = :ping

    body =
      quote do
        send(self(), {:ping, self()})
        send(self(), {:ping, self()})
        receive do
          {:message_type, value} ->
            :ok
        end

        send(self(), {:ping, self()})
      end

    # session_type = [send: 'int']
    session_type = [send: 'int', send: 'int', send: 'type', send: 'int']

    session_typecheck(fun, 0, body, session_type)

    []
  end
end
