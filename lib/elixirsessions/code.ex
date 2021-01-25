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
    IO.inspect(session_type)

    # Macro.prewalk(body, fn x -> IO.inspect x end)
  end

  # recompile && ElixirSessions.Code.run
  def run() do
    fun = :ping
    body = [
      do: {:__block__, [],
       [
         {{:., [line: 28], [{:__aliases__, [line: 28], [:IO]}, :puts]}, [line: 28],
          [
            {:<<>>, [line: 28],
             [
               "Sending ping to ",
               {:"::", [line: 28],
                [
                  {{:., [line: 28], [Kernel, :to_string]}, [line: 28],
                   [{:inspect, [line: 28], [{:pid, [line: 28], nil}]}]},
                  {:binary, [line: 28], nil}
                ]}
             ]}
          ]},
         {:send, [line: 29],
          [{:pid, [line: 29], nil}, {:ping, {:self, [line: 29], []}}]},
         {:receive, [line: 31],
          [
            [
              do: [
                {:->, [line: 32],
                 [
                   [{:{}, [line: 32], [:pong]}],
                   {{:., [line: 33], [{:__aliases__, [line: 33], [:IO]}, :puts]},
                    [line: 33], ["Received pong!"]}
                 ]}
              ]
            ]
          ]}
       ]}
    ]
    session_type = [send: '{:ping, pid}', recv: '{:pong}']

    walk_ast(fun, body, session_type)
  end
end
