defmodule Examples.AuctionOther do
  use ElixirST
  @moduledoc false

  @session "auction = !bid(number).&{?sold().end,
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
end
