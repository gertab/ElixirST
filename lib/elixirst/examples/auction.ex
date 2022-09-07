defmodule Examples.Auction do
  use ElixirST
  @moduledoc false

  @session "auction = !bid(number)
                            .&{?sold().end,
                               ?higher(number).+{!quit().end,
                                                 !continue().auction}}"
  @spec buyer(pid, number) :: atom
  def buyer(auctioneer_pid, amount) do
    send(auctioneer_pid, {:bid, amount})

    receive do
      {:sold} -> :ok

      {:higher, value} -> decide(auctioneer_pid, amount, value)
    end
  end

  @spec decide(pid, number, number) :: atom
  defp decide(auctioneer_pid, amount, value) do
    if value < 100 do
      send(auctioneer_pid, {:continue})
      buyer(auctioneer_pid,  amount + 10)
    else
      send(auctioneer_pid, {:quit})
      :ok
    end
  end

  @dual "auction"
  @spec auctioneer(pid, number) :: atom
  def auctioneer(buyer_pid, minimum) do
    amount =
      receive do
        {:bid, amount} ->
              amount
      end

    if amount > minimum do
      send(buyer_pid, {:sold})
      :ok
    else
      send(buyer_pid, {:higher, amount + 5})
      receive do
        {:continue} -> auctioneer(buyer_pid, minimum)
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

  def main do
    ElixirST.spawn(&buyer/2, [50], &auctioneer/2, [200])
  end
end
# explicitly: `mix sessions Examples.Auction`
