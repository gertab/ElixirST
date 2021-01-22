# Input session type
@session "send '{:ping, pid}' . receive '{:pong}'"

# Processed session types [automated]
session_type =
  [send: '{:ping, pid}', recv: '{:pong}']


# Input function
def ping(pid) when is_pid(pid) do
  send(pid, {:ping, self()})

  receive do
    {:pong} ->
      IO.puts("Received pong!")
  end
end

# AST of Elixir ping() function [automated]
AST =
[
do: {:__block__, [],
  [
    {:send, [line: 21],
    [{:pid, [line: 21], nil}, {:ping, {:self, [line: 21], []}}]},
    {:receive, [line: 23],
    [
      [
        do: [
          {:->, [line: 24],
            [
              [{:{}, [line: 24], [:pong]}],
              {{:., [line: 25], [{:__aliases__, [line: 25], [:IO]}, :puts]},
              [line: 25], ["Received pong!"]}
            ]}
        ]
      ]
    ]}
  ]}
]
