defmodule ElixirSessions.LargerExample do
  use ElixirSessions.Checking

  def run() do
    spawn(__MODULE__, :example1, [])
  end

  # @infer_session true
  @session """
        ?address(any).
           &{
             ?option1().!A(any).!B(any),
             ?option2().!X(),
             ?option3(any).!Y(any).+{
                                     !hello(),
                                     !hello2(), !not_hello(any)
                                    }
            }
  """
  def example1() do
    pid =
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
        send(pid, {:X})

      {:option3, value} ->
        b = 3
        send(pid, {:Y, b})
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

    # example1()
  end
end
