defmodule Examples.FlightClient do
  use ElixirST
  @moduledoc false

  # recompile && Examples.FlightClient.main
  @spec main :: {pid, pid}
  def main do
    ElixirST.spawn(&client/6, ["MLA", "CDG", "2022-11-24", :economy, 2], &Examples.FlightGateway.gateway/1, [])
  end

  @session "S = +{!request(origin: binary, destination: binary, departure_date: binary, class: atom, passenger_no: number).
                         rec Y.(&{?offer(offer_no: number, total_amount: number, currency: binary, duration: number, stops: number, segments: binary).
                                       +{!more_details().
                                            &{?details(offer_no: number, total_amount: number, currency: binary, duration: number, stops: number, segments: binary, passenger_no: number, departure_time: binary).
                                                +{!make_booking([{binary, binary}]).
                                                              &{?ok(binary),
                                                                ?error(binary)},
                                                  !cancel()},
                                              ?error(binary)},
                                        !reject().Y},
                                  ?error(binary).S}),
                  !cancel()}"
  @spec client(pid, binary, binary, binary, atom, number) :: :ok
  def client(pid, origin, destination, departure_date, class, passenger_no) do
    send(pid, {:request, origin, destination, departure_date, class, passenger_no})

    IO.puts("\nSending request for a flight from #{origin} to #{destination} on #{departure_date} for #{passenger_no} passengers.")
    IO.puts("Waiting for a response from the server...\n")

    consume_offer(pid)
  end

  @spec consume_offer(pid) :: :ok
  defp consume_offer(pid) do
    receive do
      {:offer, offer_no, total_amount, currency, duration, stops, segments} ->

        IO.puts(
          "\nOffer ##{offer_no}: \n#{currency}#{total_amount} (duration: " <>
            "#{String.pad_leading(Integer.to_string(div(duration, 60)), 2, "0")}:" <>
            "#{String.pad_leading(Integer.to_string(rem(duration, 60)), 2, "0")}) Itinerary " <>
            "(#{stops} stop#{if stops > 1, do: "s"}): #{segments}"
        )

        accept? = IO.gets("Accept offer ##{offer_no}? y/n: ")

        case accept? do
          "y\n" ->
            send(pid, {:more_details})
            IO.puts("\nRequesting updated details for offer ##{offer_no}")

            receive do
              {:details, offer_no, total_amount, currency, duration, stops, segments, passenger_no, departure_time} ->
                IO.puts(
                  "\nUpdated details for offer ##{offer_no} (#{passenger_no} passenger/s): \n#{currency}#{total_amount} (duration: " <>
                    "#{String.pad_leading(Integer.to_string(div(duration, 60)), 2, "0")}:" <>
                    "#{String.pad_leading(Integer.to_string(rem(duration, 60)), 2, "0")}) Itinerary " <>
                    "(#{stops} stop#{if stops > 1, do: "s"}): #{segments}\nDeparting at #{departure_time}"
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

              {:error, message} ->
                error(message)
            end

            :ok

          _ ->
            send(pid, {:reject})
            consume_offer(pid)
        end

        :ok

      {:error, message} ->
        send(pid, {:cancel})
        error(message)
    end
  end

  @spec error(binary) :: :ok
  defp error(message) do
    IO.puts("\nReceived error: " <> message)
  end
end

  # @session "S = +{!request(binary, binary, binary, atom, number).
  #                        rec Y.(&{?offer(number, number, binary, number, number, binary).
  #                                      +{!more_details().&{?details(number, number, binary, number, number, binary, number, binary).
  #                                                                 +{!make_booking([{binary, binary}]).&{?ok(binary),
  #                                                                                                       ?error(binary)},
  #                                                                   !cancel()},
  #                                                          ?error(binary)},
  #                                        !reject().Y},
  #                                 ?error(binary).S}),
  #                 !cancel()}"
