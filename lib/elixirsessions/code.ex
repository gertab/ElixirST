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

    code_check(body)
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

  defp code_check([a, b]) do
    # todo: check a, b
    IO.puts("\n~~Short list: {#{IO.inspect(a)}, #{IO.inspect(b)}}}")
  end

  defp code_check([a, b, c]) do
    IO.puts("\n~~Short list:")
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
  defp code_check({:case, meta, args}) do
    IO.puts("\n~~case:")
    IO.inspect(args)

    contains_send_receive?({:case, meta, args})
  end

  defp code_check(x) do
    IO.puts("~~Unknown:")
    IO.inspect(x)
  end

  ### Checks if (case) contains send/receive
  defp contains_send_receive?({:case, _, [_what_you_are_checking, body]})
   when is_list(body) do
    # [do: [ {:->, _, [ [ when/condition ], body ]}, other_cases... ] ]

    stuff = case List.keyfind(body, :do, 0) do
      {:do, x} -> x
      _ -> []
    end

    IO.puts("\nCHECKING IF CONTAINS SEND RECEIVE")
    IO.inspect(stuff)
    contains_send_receive?(stuff)
  end

  defp contains_send_receive?([a, b]) do
    contains_send_receive?(a) || contains_send_receive?(b)
  end

  defp contains_send_receive?([a, b, c]) do
    contains_send_receive?(a) || contains_send_receive?(b) || contains_send_receive?(c)
  end

  defp contains_send_receive?({:__block__, _meta, args}) do
    Enum.map_reduce(args, false, fn x, acc -> acc || contains_send_receive?(x) end)
  end

  defp contains_send_receive?({:send, _, _}) do
    :true
  end

  defp contains_send_receive?({:receive, _, _}) do
    :true
  end

  defp contains_send_receive?(_) do
    :false
  end

  # recompile && ElixirSessions.Code.run
  def run() do
    fun = :ping
    body =
      quote do

        :ok
        a = 1+2

        case a do
          b when is_list(b) ->
            :okkkk
          a when is_list(a) ->
            :okkkk
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
