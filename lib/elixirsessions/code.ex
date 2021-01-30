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
    rec = contains_recursion?(body, fun)
    IO.puts("CONTAINS RECURSION? #{IO.inspect(rec)}")
    # code_check(body)
  end

  #### Checking for AST literals
  # :atom
  # 123
  # 3.12
  # [1,2,3]
  # "string"
  # {:ok, 1}
  # {:ok, [1,2,3]}
  defp code_check(x) when is_atom(x) do
    IO.puts("\n~~ Atom: #{IO.inspect(x)}")
  end

  defp code_check(x) when is_number(x) do
    IO.puts("\n~~ Number: #{IO.inspect(x)}")
  end

  defp code_check(x) when is_binary(x) do
    IO.puts("\n~~ Binary/string: #{IO.inspect(x)}")
  end

  defp code_check({a, b}) do
    IO.puts("\n~~Tuple: {#{IO.inspect(a)}, #{IO.inspect(b)}}")
  end

  defp code_check([a]) do
    # todo: check a
    IO.puts("\n~~Short list (1):")
    IO.inspect(a)
  end

  defp code_check([a, b]) do
    # todo: check a, b
    IO.puts("\n~~Short list (2):")
    IO.inspect(a)
    IO.inspect(b)
  end

  defp code_check([a, b, c]) do
    IO.puts("\n~~Short list (3):")
    IO.inspect(a)
    IO.inspect(b)
    IO.inspect(c)
  end

  #### AST checking for non literals
  defp code_check({:__block__, _meta, args}) do
    IO.puts("\n~~Block: ")
    IO.inspect(args)

    Enum.map(args, fn x -> code_check(x) end)
  end

  # todo: when cheking for case AST; if it does not contain send/receive, skip
  defp code_check({:case, _meta, args} = ast) do
    IO.puts("\n~~case:")
    IO.inspect(args)

    if contains_send_receive?(ast) do
      IO.puts("\nCONTAINS SEND/RECEIVE")
    else
      IO.puts("\nDOES NOT CONTAIN SEND/RECEIVE")
    end
  end

  defp code_check({:=, _meta, [_left, right]}) do
    # todo check right hand side
    IO.puts("\n~~pattern matchin (=):")
    IO.inspect(right)
  end

  defp code_check(x) do
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
    [_head | tail] = args # head contains info related to 'when'
    # IO.puts("Checking tail:")
    # IO.inspect(tail)
    contains_send_receive?(tail)
  end

  defp contains_send_receive?({:__block__, _meta, args}) when is_list(args) do
    {_, result} = Enum.map_reduce(args, false, fn x, acc -> {contains_send_receive?(x), acc || contains_send_receive?(x)} end)

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
    contains_recursion?(a, function_name) || contains_recursion?(b, function_name) || contains_recursion?(c, function_name)
  end

  defp contains_recursion?({:->, _meta, args}, function_name) do
    [_head | tail] = args # head contains info related to 'when'
    contains_recursion?(tail, function_name)
  end

  defp contains_recursion?({:__block__, _meta, args}, function_name) when is_list(args) do
    {_, result} = Enum.map_reduce(args, false, fn x, acc -> {contains_recursion?(x, function_name), acc || contains_recursion?(x, function_name)} end)

    result
  end

  defp contains_recursion?({description, _, _}, function_name) do
    description == function_name
  end

  defp contains_recursion?(_, _function_name) do
    false
  end

  # recompile && ElixirSessions.Code.run
  def run() do
    fun = :ping

    body =
      quote do
        :ok
        a = 1 + 2
        ping()

        case a do
          b when is_list(b) ->
            :okkkk

          a when is_list(a) ->
            :okkk
            send(self(), 123)

          a when is_list(a) ->
            :okkk

        end

        send(self(), :ok)

        receive do
          {:message_type, _value} ->
            :receievve
        end

        # IO.puts("Sending ping to #{inspect(pid)}")
        # send(pid, {:ping, self()})

        # receive do
        #   {:pong} ->
        #     IO.puts("Received pong!")
        # end
      end

    session_type = [send: '{:ping, pid}', recv: '{:pong}']
    # a = Macro.prewalk(body, fn x -> Macro.expand(x, __ENV__) end)
    # IO.inspect(a)

    # IO.inspect Macro.expand(body, __ENV__)
    # IO.puts("_b = ")
    # IO.inspect(body)
    walk_ast(fun, body, session_type)

    body
  end
end
