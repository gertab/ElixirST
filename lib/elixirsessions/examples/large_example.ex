defmodule ElixirSessions.LargerExample do
  use ElixirSessions.Checking

  def run() do
    spawn(__MODULE__, :example1, [])
  end

  # @infer_session true
  @session """
   example1 =
    rec X.( ?address(any).
            &{
              ?option1().!A(any).!B(any).X,
              ?option2().!C().X,
              ?option3(any).!D(any).+{
                                      !hello().X,
                                      !hello2().X, !not_hello(any).X
                                      }
              }
           )
  """
  def example1() do
    pid = #self()
      receive do
        {:address, pid} ->
          pid
      end

    # send(pid, {:label, 233})

    receive do
      {:option1} ->
        a = 1
        send(pid, {:A, a})
        send(pid, {:B, a + 1})

      {:option2} ->
        _b = 2
        send(pid, {:C})

      {:option3, value} ->
        b = 3
        send(pid, {:D, b})
        case value do
          true -> send(pid, {:hello})
          false -> send(pid, {:hello2})
          _ -> send(pid, {:not_hello, 3})
        end
    end

    # case true do
    #   true ->
    #     :ok
    #   false ->
    #     :error
    # end

    example1()
  end
end
