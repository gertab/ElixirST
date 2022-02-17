defmodule Examples.AuctionD do
  use ElixirST
  @moduledoc false

  def main do
    # ElixirST.spawn(&buyer/2, [5], &seller/2, [20])
    ElixirST.spawn(&buyer/2, [50], &seller/2, [200])
  end

  @session "S = !bid(number).&{?sold().end,
                               ?higher(number).+{!quit().end,
                                                 !continue().S}}"
  @spec buyer(pid, number) :: atom
  def buyer(seller, amount) do
    IO.puts("Buyer: Bidding €#{inspect amount}")
    send(seller, {:bid, amount})

    receive do
      {:sold} ->
        IO.puts("Buyer: Sold at €#{inspect amount}")
        :ok

        {:higher, value} ->
          if value < 100 do
            IO.puts("Buyer: Continuing")
            send(seller, {:continue})
            buyer(seller,  amount + 10)
          else
            IO.puts("Buyer: Quitting")
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
              IO.puts("Seller: Received bid of €#{inspect amount}")
              amount
      end

    if amount > minimum do
      send(buyer, {:sold})
      IO.puts("Seller: Accepting bid of €#{inspect amount}")
      :ok
    else
      new_amount = amount + 5
      send(buyer, {:higher, new_amount})
      IO.puts("Seller: Outbidded at €#{inspect new_amount}")
      receive do
        {:continue} -> seller(buyer, minimum)
        {:quit} -> :ok
      end
    end
  end
end

# explicitly: `mix sessions Examples.AuctionD`
