# Input session type
@session "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"

# Processed session types [automated]
session_type = [
  recv: '{label}',
  branch: %{
    add: [recv: '{number, number, pid}', send: '{number}'],
    neg: [recv: '{number, pid}', send: '{number}']
  }
]


# Input function
def arith_serv() do
    receive do
      {:add} ->
        receive do
          {num1, num2, pid} ->
            IO.puts("[server] #{num1} + #{num2}")
            send(pid, {num1 + num2})
        end

      {:neg} ->
        receive do
          {num, pid} ->
            IO.puts("[server] neg of #{num}")
            send(pid, {-num})
        end
    end
  end

# AST of Elixir arith_serv() function [automated]
AST = [
  do: {:receive, [line: 14],
   [
     [
       do: [
         {:->, [line: 15],
          [
            [{:{}, [line: 15], [:add]}],
            {:receive, [line: 16],
             [
               [
                 do: [
                   {:->, [line: 17],
                    [
                      [
                        {:{}, [line: 17],
                         [
                           {:num1, [line: 17], nil},
                           {:num2, [line: 17], nil},
                           {:pid, [line: 17], nil}
                         ]}
                      ],
                      {:__block__, [],
                       [
                         {{:., [line: 18],
                           [{:__aliases__, [line: 18], [:IO]}, :puts]},
                          [line: 18],
                          [
                            {:<<>>, [line: 18],
                             [
                               "[server] ",
                               {:"::", [line: 18],
                                [
                                  {{:., [line: 18], [Kernel, :to_string]},
                                   [line: 18], [{:num1, [line: 18], nil}]},
                                  {:binary, [line: 18], nil}
                                ]},
                               " + ",
                               {:"::", [line: 18],
                                [
                                  {{:., [line: 18], [Kernel, :to_string]},
                                   [line: 18], [{:num2, [line: 18], nil}]},
                                  {:binary, [line: 18], nil}
                                ]}
                             ]}
                          ]},
                         {:send, [line: 19],
                          [
                            {:pid, [line: 19], nil},
                            {:{}, [line: 19],
                             [
                               {:+, [line: 19],
                                [
                                  {:num1, [line: 19], nil},
                                  {:num2, [line: 19], nil}
                                ]}
                             ]}
                          ]}
                       ]}
                    ]}
                 ]
               ]
             ]}
          ]},
         {:->, [line: 22],
          [
            [{:{}, [line: 22], [:neg]}],
            {:receive, [line: 23],
             [
               [
                 do: [
                   {:->, [line: 24],
                    [
                      [{{:num, [line: 24], nil}, {:pid, [line: 24], nil}}],
                      {:__block__, [],
                       [
                         {{:., [line: 25],
                           [{:__aliases__, [line: 25], [:IO]}, :puts]},
                          [line: 25],
                          [
                            {:<<>>, [line: 25],
                             [
                               "[server] neg of ",
                               {:"::", [line: 25],
                                [
                                  {{:., [line: 25], [Kernel, :to_string]},
                                   [line: 25], [{:num, [line: 25], nil}]},
                                  {:binary, [line: 25], nil}
                                ]}
                             ]}
                          ]},
                         {:send, [line: 26],
                          [
                            {:pid, [line: 26], nil},
                            {:{}, [line: 26],
                             [{:-, [line: 26], [{:num, [line: 26], nil}]}]}
                          ]}
                       ]}
                    ]}
                 ]
               ]
             ]}
          ]}
       ]
     ]
   ]}
]
