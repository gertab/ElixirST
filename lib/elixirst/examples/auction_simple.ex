defmodule Examples.AuctionSimple do
  use ElixirST
  @moduledoc false

  @session "auction = !bid(number).&{?sold().end,
                               ?higher(number).+{!quit().end,
                                                 !continue().auction}}"
  @spec buyer(pid, number) :: atom
  def buyer(auctioneer, amount) do
    send(auctioneer, {:bid, amount})

    receive do
      {:sold} -> :ok

      {:higher, value} ->
        if value < 100 do
          send(auctioneer, {:continue})
          buyer(auctioneer,  amount + 10)
        else
          send(auctioneer, {:quit})
          :ok
        end
    end
  end

  @dual "auction"
  @spec auctioneer(pid, number) :: atom
  def auctioneer(buyer, minimum) do
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
        {:continue} -> auctioneer(buyer, minimum)
        {:quit} -> :ok
       end
     end
   end

  #  @session "auction = !bid(number).&{?sold().end,
  #                               ?higher(number).+{!quit().end,
  #                                                 !continue().auction}}"
  @spec problematic_buyer(pid, number) :: atom
  def problematic_buyer(auctioneer, _amount) do
    send(auctioneer, {:bid, true}) # amount?

    receive do
      {:sold} -> :ok
      # {:higher, value} -> #...
    end
  end
end
# explicitly: `mix sessions Examples.AuctionSimple`
