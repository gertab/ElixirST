defmodule Examples.AuctionD do
  use ElixirST
  @moduledoc false

  def main do
    # ElixirST.spawn(&buyer/2, [5], &auctioneer/2, [20])
    ElixirST.spawn(&buyer/2, [50], &auctioneer/2, [200])
  end

  @session "S = !bid(number).&{?sold().end,
                               ?higher(number).+{!quit().end,
                                                 !continue().S}}"
  @spec buyer(pid, number) :: atom
  def buyer(auctioneer, amount) do
    IO.puts("Buyer: Bidding €#{amount}")
    send(auctioneer, {:bid, amount})

    receive do
      {:sold} ->
        IO.puts("Buyer: Sold at €#{amount}")
        :ok

      {:higher, value} ->
        if value < 100 do
          IO.puts("Buyer: Continuing")
          send(auctioneer, {:continue})
          buyer(auctioneer,  amount + 10)
        else
          IO.puts("Buyer: Quitting")
          send(auctioneer, {:quit})
          :ok
        end
    end
  end

  @dual "S"
  @spec auctioneer(pid, number) :: atom
  def auctioneer(buyer, minimum) do
    amount =
      receive do
        {:bid, amount} ->
              IO.puts("auctioneer: Received bid of €#{amount}")
              amount
      end

    if amount > minimum do
      send(buyer, {:sold})
      IO.puts("auctioneer: Accepting bid of €#{amount}")
      :ok
    else
      new_amount = amount + 5
      send(buyer, {:higher, new_amount})
      IO.puts("auctioneer: Outbidded at €#{inspect new_amount}")
      receive do
        {:continue} -> auctioneer(buyer, minimum)
        {:quit} -> :ok
      end
    end
  end
end

# explicitly: `mix sessions Examples.AuctionD`
