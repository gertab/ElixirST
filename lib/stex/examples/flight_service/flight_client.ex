defmodule Examples.FlightClient do
  use STEx

  # recompile && Examples.FlightClient.main
  @spec main :: {pid, pid}
  def main do
    STEx.spawn(&client/1, [], &Examples.FlightServer.server/1, [])
  end

  @session "S = +{!request(binary, binary, binary, atom, number).
                         rec Y.(&{?offer(number, number, binary, binary, number, binary).
                                       +{!more_details().&{?details(number, number, binary, binary, number, binary, number, binary).
                                                                  +{!make_booking([{binary, binary}]).&{?ok(binary),
                                                                                                        ?error(binary)},
                                                                    !cancel()},
                                                           ?error(binary)},
                                         !reject().Y},
                                  ?error(binary).S}),
                  !cancel()}"
  @spec client(pid) :: :ok
  def client(pid) do
    origin = "MLA"
    destination = "CDG"
    departure_date = "2021-11-24"
    class = :economy
    passenger_no = 2

    send(pid, {:request, origin, destination, departure_date, class, passenger_no})
    IO.puts("\nSending request for a flight from #{origin} to #{destination} on #{departure_date} for #{passenger_no} passengers.")
    IO.puts("Waiting for a response from the server...\n")

    consume_offer(pid)
  end

  @spec consume_offer(pid()) :: :ok
  defp consume_offer(pid) do
    receive do
      {:offer, offer_no, total_amount, currency, duration, stops, segments} ->
        IO.puts(
          "\nOffer ##{offer_no}: \n#{currency}#{total_amount} (duration: #{duration}) Itinerary " <>
            "(#{stops} stop#{
              if stops > 1 do
                "s"
              end
            }): #{segments}"
        )

        if total_amount > 140 and stops == 0 do
          send(pid, {:reject})
          consume_offer(pid)
        else
          send(pid, {:more_details})
          IO.puts("\nRequesting updated details for offer #{offer_no}")

          receive do
            {:details, offer_no, total_amount, currency, duration, stops, segments, passenger_no, departure_time} ->
              IO.puts(
                "\nOffer ##{offer_no} (#{passenger_no} passenger/s): \n#{currency}#{total_amount} (duration: #{duration}) Itinerary " <>
                  "(#{stops} stop#{
                    if stops > 1 do
                      "s"
                    end
                  }): #{segments}\nDeparting at #{departure_time}"
              )

              send(pid, {:make_booking, [{"Tony", "Stark"}, {"Pepper", "Mac"}]})
              IO.puts("\nAccepting offer ##{offer_no}...")

              # send(pid, {:cancel})

              receive do
                {:ok, booking_reference} ->
                  # code
                  IO.puts("\nBooking performed successfully. Reference number: #{booking_reference}.")

                {:error, message} ->
                  IO.puts("\nFailed to perform booking.")
                  error(message)
              end

              :ok

            {:error, message} ->
              error(message)
          end

          :ok
        end

        :ok

      {:error, message} ->
        IO.puts("\nReceived error: " <> message)
        send(pid, {:cancel})
        :ok
    end
  end

  @spec error(binary) :: :ok
  defp error(message) do
    IO.puts("\nReceived error: " <> message)
    :ok
  end
end
