defmodule Examples.Counter do
  use ElixirSessions
  @moduledoc false

  def main() do
    ST.spawn(&server/2, [0], &client/1, [])
  end

  @session "count = &{?increment().count, ?stop().!value(number).end}"
  @spec server(pid, number) :: atom
  def server(client, value) do
    receive do
      {:increment} ->
        server(client, value + 1)

        {:stop} ->
        send(client, {:value, value})
        :ok
    end
  end

  @dual "count"
  @spec client(pid) :: number
  def client(server) do
    send(server, {:increment})
    send(server, {:increment})
    send(server, {:increment})
    send(server, {:stop})

    receive do
      {:value, num} ->
        # IO.puts("Counter = " <> num)
        num
    end
  end

  # @dual "count"
  # @spec incorrect_client(pid) :: number
  # def incorrect_client(server) do
  #   send(server, {:increment})
  #   send(server, {:decrement})
  #   # send(server, {:stop})

  #   receive do
  #     {:value, num} -> num
  #   end
  # end
end
