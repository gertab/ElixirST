@session "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"

session_type = [
   recv: '{label}',
   branch: [
     add: [recv: '{number, number, pid}', send: '{number}'],
     neg: [recv: '{number, pid}', send: '{number}']
   ]
]




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

# AST of Elixir arith_serv() function
AST = [
  do: {:__block__, [],
   [
     {{:., [line: 11], [{:__aliases__, [line: 11], [:IO]}, :puts]}, [line: 11],
      ["Spawning process"]},
     {:=, [line: 12],
      [
        {:ponger, [line: 12], nil},
        {:spawn, [line: 12], [{:__MODULE__, [line: 12], nil}, :pong, []]}
      ]},
     {{:., [line: 13], [{:__aliases__, [line: 13], [:IO]}, :puts]}, [line: 13],
      [
        {:<<>>, [line: 13],
         [
           "Process spawned as ",
           {:"::", [line: 13],
            [
              {{:., [line: 13], [Kernel, :to_string]}, [line: 13],
               [{:inspect, [line: 13], [{:ponger, [line: 13], nil}]}]},
              {:binary, [line: 13], nil}
            ]}
         ]}
      ]},
     {:ping, [line: 15], [{:ponger, [line: 15], nil}]}
   ]}
]
