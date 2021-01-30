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
    # IO.puts(Macro.to_string(body))

    IO.inspect(session_type)

    # Macro.prewalk(body, fn x -> IO.inspect x end)
    # rec = contains_recursion?(body, fun)
    # IO.puts("CONTAINS RECURSION? #{IO.inspect(rec)}")

    result = code_check_incl_recursion(fun, body, session_type)
    # code_check(body)
    IO.inspect(result)
    result
  end

  def code_check_incl_recursion(fun, body, session_type) do
    rec = contains_recursion?(body, fun)
    # todo maybe add __module__
    info = %{recursion: rec, call_recursion: "X", function_name: fun, session_type: session_type}
    code_check(body, info)
  end

  #### Checking for AST literals
  # :atom
  # 123
  # 3.12
  # [1,2,3]
  # "string"
  # {:ok, 1}
  # {:ok, [1,2,3]}
  defp code_check(x, _info) when is_atom(x) do
    IO.puts("\n~~ Atom: #{IO.inspect(x)}")

    nil
  end

  defp code_check(x, _info) when is_number(x) do
    IO.puts("\n~~ Number: #{IO.inspect(x)}")

    nil
  end

  defp code_check(x, _info) when is_binary(x) do
    IO.puts("\n~~ Binary/string: #{IO.inspect(x)}")

    nil
  end

  defp code_check({a, b}, _info) do
    IO.puts("\n~~Tuple: {#{IO.inspect(a)}, #{IO.inspect(b)}}")

    nil
  end

  defp code_check([a], info) do
    # todo: check a
    IO.puts("\n~~Short list (1):")
    IO.inspect(a)

    res = [code_check(a, info)]

    case Enum.filter(res, &(!is_nil(&1))) do
      [] -> nil
      x -> x
    end
  end

  defp code_check([a, b], info) do
    # todo: check a, b
    IO.puts("\n~~Short list (2):")
    IO.inspect(a)
    IO.inspect(b)

    # todo remove nils from list. then if list = [], return nil
    res = [code_check(a, info)] ++ [code_check(b, info)]

    case Enum.filter(res, &(!is_nil(&1))) do
      [] -> nil
      x -> x
    end
  end

  defp code_check([a, b, c], info) do
    IO.puts("\n~~Short list (3):")
    IO.inspect(a)
    IO.inspect(b)
    IO.inspect(c)
    res = [code_check(a, info)] ++ [code_check(b, info)] ++ [code_check(c, info)]

    case Enum.filter(res, &(!is_nil(&1))) do
      [] -> nil
      x -> x
    end
  end

  #### AST checking for non literals
  defp code_check({:__block__, _meta, args}, info) do
    IO.puts("\n~~Block: ")
    IO.inspect(args)

    Enum.map(args, fn x -> code_check(x, info) end)
    |> Enum.filter(&(!is_nil(&1)))

    # todo flatten on a single level
    # |> List.flatten
  end

  # todo: when checking for case AST; if it does not contain send/receive, skip
  defp code_check({:case, _, [_what_you_are_checking, body]} = ast, _info) when is_list(body) do
    IO.puts("\n~~case:")

    if contains_send_receive?(ast) do
      IO.puts("\nCONTAINS SEND/RECEIVE")
      # todo check if all cases neen to have send/receive
      cases =
        case List.keyfind(body, :do, 0) do
          {:do, x} -> x
          # should never happen
          _ -> []
        end

      IO.inspect(cases)
    else
      IO.puts("\nDOES NOT CONTAIN SEND/RECEIVE")

      nil
    end
  end

  defp code_check({:=, _meta, [_left, right]}, info) do
    # todo check right hand side
    IO.puts("\n~~pattern matchin (=):")
    IO.inspect(right)

    code_check(right, info)
  end

  defp code_check({:send, _, _}, _info) do
    # todo fix type
    {:send, 'type'}
  end

  defp code_check({:receive, _, [body]}, info) do
    # body contains [do: [ {:->, _, [ [ when/condition ], body ]}, other_cases... ] ]

    IO.puts("\nRECEIVE")

    stuff =
      case List.keyfind(body, :do, 0) do
        {:do, x} -> x
        _ -> []
      end

    result =
      case length(stuff) do
        0 ->
          nil

        1 ->
          {:recv, 'type'}

        _ ->
          # Greater than 1
          # todo replace map with more suitable function (since each element may have more than one item in a list)
          Enum.map(stuff, fn x -> [{:recv, 'type'}] ++ code_check(x, info) end)
          |> Enum.filter(&(!is_nil(&1)))
        # |> List.flatten
      end

    IO.puts("RESULT for receive")
    IO.inspect(result)
    result
  end

  defp code_check({:->, _, [_head | body]}, _info) do
    IO.inspect(body)

    nil
  end

  defp code_check(x, _info) do
    IO.puts("\n~~Unknown:")
    IO.inspect(x)
  end

  # todo: replace contains_send_receive? and contains_recursion? with Macro.prewalk()
  ### Checks if (case) contains send/receive
  defp contains_send_receive?({:case, _, [_what_you_are_checking, body]})
       when is_list(body) do
    # [do: [ {:->, _, [ [ when/condition ], body ]}, other_cases... ] ]

    stuff =
      case List.keyfind(body, :do, 0) do
        {:do, x} -> x
        _ -> []
      end

    IO.puts("\nCHECKING IF CONTAINS SEND RECEIVE")
    IO.inspect(stuff)
    contains_send_receive?(stuff)
  end

  defp contains_send_receive?([a]) do
    contains_send_receive?(a)
  end

  defp contains_send_receive?([a, b]) do
    contains_send_receive?(a) || contains_send_receive?(b)
  end

  defp contains_send_receive?([a, b, c]) do
    contains_send_receive?(a) || contains_send_receive?(b) || contains_send_receive?(c)
  end

  defp contains_send_receive?({:->, _meta, args}) do
    # head contains info related to 'when'
    [_head | tail] = args
    # IO.puts("Checking tail:")
    # IO.inspect(tail)
    contains_send_receive?(tail)
  end

  defp contains_send_receive?({:__block__, _meta, args}) when is_list(args) do
    {_, result} =
      Enum.map_reduce(args, false, fn x, acc ->
        {contains_send_receive?(x), acc || contains_send_receive?(x)}
      end)

    result
  end

  defp contains_send_receive?({definition, _, _}) when definition in [:send, :receive] do
    true
  end

  defp contains_send_receive?(_) do
    false
  end

  ### Checks if contains send/receive
  defp contains_recursion?({:case, _, [_what_you_are_checking, body]}, function_name)
       when is_list(body) do
    # [do: [ {:->, _, [ [ when/condition ], body ]}, other_cases... ] ]

    stuff =
      case List.keyfind(body, :do, 0) do
        {:do, x} -> x
        _ -> []
      end

    IO.puts("\nCHECKING IF CONTAINS RECURSION")
    IO.inspect(stuff)
    contains_recursion?(stuff, function_name)
  end

  defp contains_recursion?([a], function_name) do
    contains_recursion?(a, function_name)
  end

  defp contains_recursion?([a, b], function_name) do
    contains_recursion?(a, function_name) || contains_recursion?(b, function_name)
  end

  defp contains_recursion?([a, b, c], function_name) do
    contains_recursion?(a, function_name) || contains_recursion?(b, function_name) ||
      contains_recursion?(c, function_name)
  end

  defp contains_recursion?({:->, _meta, args}, function_name) do
    # head contains info related to 'when'
    [_head | tail] = args
    contains_recursion?(tail, function_name)
  end

  defp contains_recursion?({:__block__, _meta, args}, function_name) when is_list(args) do
    {_, result} =
      Enum.map_reduce(args, false, fn x, acc ->
        {contains_recursion?(x, function_name), acc || contains_recursion?(x, function_name)}
      end)

    result
  end

  defp contains_recursion?({function_name, _, _}, function_name) do
    # Recursion occurs here, since {function_name, _, _} calls the current function
    # todo: case when same function is called via module name e.g. Module.function_name
    true
  end

  defp contains_recursion?(_, _function_name) do
    false
  end

  # recompile && ElixirSessions.Code.run
  def run() do
    fun = :ping

    body =
      quote do
        # :ok
        # a = 1 + 2
        # ping()

        # send(self(), 123)

        # case a do
        #   b when is_list(b) ->
        #     :okkkk

        #   a when is_list(a) ->
        #     :okkk
        #     receive do
        #       {:message_type, value} ->
        #         value
        #       {:message_type2, value} when is_atom(value) ->
        #         aaa = value + 1
        #         aaa
        #     end

        #   a when is_list(a) ->
        #     :okkk

        # end

        # send(self(), :ok)

        # receive do
        #   {:message_type, _value} ->
        #     :receievve
        # end

        # IO.puts("Sending ping to #{inspect(pid)}")
        send(pid, {:ping, self()})
        send(pid, {:ping, self()})
        send(pid, {:ping, self()})

        case true do
          true -> :ok
          false -> :not_ok
        end

        receive do
          {:pong} ->
            IO.puts("Received pong!")
            send(self(), {:ok})
          {:ponng} ->
            IO.puts("Received pong!")
        end

      end

    session_type = [send: '{:ping, pid}', recv: '{:pong}']
    # a = Macro.prewalk(body, fn x -> Macro.expand(x, __ENV__) end)
    # IO.inspect(a)

    # IO.inspect Macro.expand(body, __ENV__)
    # IO.puts("_b = ")
    # IO.inspect(body)
    walk_ast(fun, body, session_type)

    # body
  end
end
