defmodule Examples.Counter do
  use ElixirST
  @moduledoc false

  @session "counter = &{?incr(number).counter,
                        ?stop().!value(number).end}"
  @spec server(pid, number) :: atom
  def server(client, tot) do
    receive do
      {:incr, val} -> server(client, tot + val)
      {:stop} -> terminate(client, tot)
    end
  end

  @spec terminate(pid, number) :: atom
  defp terminate(client, tot) do
    send(client, {:value, tot})
    :ok
  end

  @dual "counter"
  @spec client(pid) :: number
  def client(server) do
    send(server, {:incr, 5})
    send(server, {:incr, 6})
    send(server, {:incr, 12})
    send(server, {:incr, 1})
    send(server, {:stop})

    val =
      receive do
        {:value, val} ->
          val
      end

    IO.puts("Total value is: #{val}")
    val
  end

  # Client with issues
  # @dual "counter"
  # @spec misbehaving_client(pid) :: number
  # def misbehaving_client(server) do
  #   send(server, {:incr, 5})
  #   send(server, {:decr, 2})
  # end

  # Examples.Counter.main
  def main do
    ElixirST.spawn(&server/2, [0], &client/1, [])
  end
end
