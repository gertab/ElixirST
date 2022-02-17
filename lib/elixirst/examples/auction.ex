defmodule Examples.Auction do
  use ElixirST
  @moduledoc false


  @session "S = !bid(number).&{?sold().end,
                               ?higher(number).+{!quit().end,
                                                 !continue().S}}"
  @spec buyer(pid, number) :: atom
  def buyer(seller, amount) do
    send(seller, {:bid, amount})

    receive do
      {:sold} ->
        :ok

        {:higher, value} ->
          if value < 100 do
            send(seller, {:continue})
            buyer(seller,  amount + 10)
          else
            send(seller, {:quit})
          :ok
        end
    end
  end

  @dual "S"
  @spec seller(pid, number) :: atom
  def seller(buyer, minimum) do
    amount =
      receive do
        {:bid, amount} ->
              amount
      end

    if amount > minimum do
      send(buyer, {:sold})
      :ok
    else
      send(buyer, {:higher, amount + 5})
      receive do
        {:continue} -> seller(buyer, minimum)
        {:quit} -> :ok
      end
    end
  end
end

# explicitly: `mix sessions Examples.Auction`
