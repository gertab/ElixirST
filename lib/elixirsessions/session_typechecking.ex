defmodule ElixirSessions.SessionTypechecking do
  require ST

  @moduledoc """
  Given a session type and Elixir code, the Elixir code is typechecked against the session type.
  """
  @typedoc false
  @type ast :: ST.ast()
  @typedoc false
  # @typedoc """
  # Information related to a function body.
  # """
  @type info() :: %{
          # recursion: boolean(),
          call_recursion: atom,
          function_name: atom,
          arity: arity
          # session_type: any
          # todo maybe add __module__
        }
  @typedoc false
  @type session_type :: ST.session_type()
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
  %ST.Send{label: :hello, next: %ST.Terminate{}, types: []}
  """
  @spec session_typecheck(atom(), arity(), ast(), session_type()) :: true
  def session_typecheck(fun, arity, body, session_type) do
    IO.puts("Session typechecking of &#{to_string(fun)}/#{arity}")

    info = %{
      call_recursion: fun,
      function_name: fun,
      arity: arity
    }

    IO.puts("Session typechecking: #{inspect(session_type)}")
    {_, remaining_session_type} = session_typecheck_ast(body, session_type, info, %{})

    case remaining_session_type do
      %ST.Terminate{} -> :ok

      # todo what if call_recursive
      _ -> throw("Remaining session type: #{ST.st_to_string(remaining_session_type)}")
    end

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
    IO.puts("\literal: ")
    {false, session_type}
  end

  def session_typecheck_ast({_a, _b}, session_type, _info, _session_context) do
    IO.puts("\nTuple: ")

    # todo check if ok, maybe check each element
    {false, session_type}
  end

  # def session_typecheck_ast({type, _, _} = ast, [session_type], info, session_context) when type != :__block__ do
  #   # session_type is a list of size 1
  #   session_typecheck_ast(ast, session_type, info, session_context)
  # end
  def session_typecheck_ast([], session_type, _info, _session_context) do
    # todo ensure that session_type = terminate
    {false, session_type}
  end

  def session_typecheck_ast([head | tail], session_type, info, session_context) do
    IO.puts("\nlist:")

    {_, remaining_session_type} = session_typecheck_ast(head, session_type, info, session_context)

    IO.puts("Remaining st: #{inspect(remaining_session_type)}")
    session_typecheck_ast(tail, remaining_session_type, info, session_context)
  end

  def session_typecheck_ast(args, session_type, _info, _session_context) when is_list(args) do
    {false, session_type}
  end

  # Non literals
  def session_typecheck_ast({:__block__, _meta, args}, session_type, info, session_context) do
    IO.puts("__block__ of size #{length(args)}")
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

  def session_typecheck_ast({:send, meta, _} = ast, session_type, _info, _session_context) do
    IO.puts("[in send] #{inspect(session_type)}")

    line =
      if meta[:line] do
        meta[:line]
      else
        "unknown"
      end

    case session_type do
      #   throw(
      #     "Session type error [line #{line}]: expected a 'receive #{IO.inspect(type)}' but found a send statement."
      #   )

      %ST.Send{label: label, types: _types, next: next} ->
        # todo types
        # todo check label
        IO.puts("Matched send: #{label}")
        {false, next}

      x ->
        throw("Cannot match `#{Macro.to_string(ast)}` with #{ST.st_to_string(x)}.")
    end
  end

  def session_typecheck_ast(
        {:receive, meta, [body | _]} = ast,
        session_type,
        info,
        session_context
      ) do
    # body contains [do: [ {:->, _, [ [ when/condition ], work ]}, other_cases... ] ]
    IO.puts("[in recv] #{inspect(session_type)}")

    line =
      if meta[:line] do
        meta[:line]
      else
        "unknown"
      end

    cases = body[:do]

    case length(cases) do
      0 ->
        []

      1 ->
        # 1 receive option, therefore assume that it is not a branch

        case session_type do
          #   throw(
          #     "Session type error [line #{line}]: expected a 'send #{IO.inspect(type)}' but found a receive statement."
          #   )

          %ST.Recv{label: label, types: _types, next: next} ->
            # todo types
            # todo check label
            IO.puts("Matched receive: #{label}")
            {false, next}

          x ->
            throw(
              "[In receive] Cannot match `#{Macro.to_string(ast)}` with #{ST.st_to_string(x)}."
            )
        end

      _ ->
        # More than 1 receive option, therefore assume that it is a branch
        branches_session_types =
          case session_type do
            %ST.Branch{branches: branches} ->
              branches
          end

        if length(branches_session_types) != length(cases) do
          throw("[in receive] Mismatch in number of receive and & branches.")
        end

        remaining_branches_session_types =
          Enum.zip(cases, branches_session_types)
          |> Enum.map(fn
            {{:->, _, [[lhs] | rhs]}, bra_session_type} ->
              # Given {:a, b} when is_atom(b) -> do_something()
              # lhs contains data related to '{:a, b} when is_atom(b)'
              # rhs contains body, e.g. 'do_something()'
              {label, types} = parse_options(lhs)

              next =
                case bra_session_type do
                  %ST.Recv{label: _label, types: _types, next: next} ->
                    next

                  x ->
                    throw(
                      "[In receive/branch] Cannot match `#{Macro.to_string(ast)}` with #{
                        ST.st_to_string(x)
                      }."
                    )
                end

              session_typecheck_ast(hd(rhs), next, info, session_context)
          end)

        # Ensure that all element in remaining_branches_session_types are the same
        hd(remaining_branches_session_types)
    end
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
    IO.puts("Other input")
    {false, session_type}
  end

  @doc false
  # Takes case of :-> and returns the label and number of values as ':any' type.
  # e.g. {:label, value1, value2} -> do_something()
  # or   {:label, value1, value2} when is_number(value1) -> do_something()
  # returns {:label, [:any, :any]}
  def parse_options(x) do
    x =
      case x do
        {:when, _, data} ->
          # throw("Problem while typechecking: 'when' not implemented yet")
          hd(data)

        x ->
          x
      end

    {label, size} =
      case x do
        # Size 0, e.g. {:do_something}
        {:{}, _, [label]} ->
          {label, 0}

        # Size 1, e.g. {:value, 545}
        {label, _} ->
          {label, 1}

        # Size > 2, e.g. {:add, 3, 5}
        {:{}, _, x} when is_list(x) and length(x) > 2 ->
          {hd(x), length(x)}

        _ ->
          throw(
            "Needs to be a tuple contain at least a label. E.g. {:do_something} oe {:value, 54}"
          )
      end

    case is_atom(label) do
      true ->
        :ok

      false ->
        throw("First item in tuple needs to be a label/atom. (#{inspect(label)})")
    end

    # Default type is set to any
    types = List.duplicate(:any, size)

    {label, types}
  end

  # recompile && ElixirSessions.SessionTypechecking.run
  def run() do
    fun = :ping

    body =
      quote do
        send(self(), {:ping1, self()})
        send(self(), {:ping2, self()})

        receive do
          {:message_type1, value} ->
            send(self(), {:ping3, self()})
            :ok1

          {:message_type22, value} ->
            send(self(), {:ping3, self()})
            :ok
        end

        # send(self(), {:ping3, self()})
      end

    st = "!Ping1().!Ping2().&{?Option1().!Ping3(), ?Option2().!DSF()}"
    session_type = ST.string_to_st(st)

    session_typecheck(fun, 0, body, session_type)

    []
  end
end
