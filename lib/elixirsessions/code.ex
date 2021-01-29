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

# Checking for AST literals
# :atom
# 123
# 3.12
# [1,2,3]
# "string"
# {:ok, 1}
# {:ok, [1,2,3]}
  defp code_check(x) when is_atom(x) do
    IO.puts("~~ Atom: #{IO.inspect(x)}")
  end

  defp code_check(x) when is_number(x) do
    IO.puts("~~ Number: #{IO.inspect(x)}")
  end

  defp code_check(x) when is_binary(x) do
    IO.puts("~~ Binary/string: #{IO.inspect(x)}")
  end

  defp code_check({a, b}) do
    IO.puts("~~Tuple: {#{IO.inspect(a)}, #{IO.inspect(b)}}")
  end

  defp code_check([a, b]) do
    # todo: check a, b
    IO.puts("~~Short list: {#{IO.inspect(a)}, #{IO.inspect(b)}}}")
  end

  defp code_check([a, b, c]) do
    IO.puts("~~Short list:")
    IO.inspect(a)
    IO.inspect(b)
    IO.inspect(c)
  end

  defp code_check(x) do
    IO.puts("~~Unknown:")
    IO.inspect(x)
  end


  # recompile && ElixirSessions.Code.run
  def run() do
    fun = :ping
    body =
      quote do

        :ok
        a = 1+2
        if 5 < 53 do
          1324234
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
  end
end
