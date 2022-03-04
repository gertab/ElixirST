defmodule Examples.FlightClientDecorated do
  # use ElixirST replace exs
  @moduledoc false

  # recompile && Examples.FlightClientDecorated.main
  @spec main :: {pid, pid}
  def main do
    ElixirST.spawn(&client/6, ["MLA", "CDG", "2022-11-24", :economy, 2], &Examples.FlightGateway.server/1, [])
  end

  @session "S = +{!request(origin: binary, destination: binary, departure_date: binary, class: atom, passenger_no: number).
                         rec Y.(&{?offer(offer_no: number, total_amount: number, currency: binary, duration: number, stops: number, segments: binary).
                                       +{!more_details().&{?details(offer_no: number, total_amount: number, currency: binary, duration: number, stops: number, segments: binary, passenger_no: number, departure_time: binary).
                                                                  +{!make_booking([{binary, binary}]).&{?ok(binary),
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

        # IO.puts("Offer ##{offer_no}: \n#{currency}#{total_amount} (duration: " <>
        #     "#{prettify(duration)}: Itinerary (#{stops} stops): #{segments}")

        accept? = IO.gets("Accept offer ##{offer_no}? y/n: ")

        case accept? do
          "y\n" ->
            send(pid, {:more_details})
            IO.puts("\nRequesting updated details for offer ##{offer_no}")
            # ...

          _ ->
            send(pid, {:reject})
            consume_offer(pid)
        end

      {:error, message} ->
        send(pid, {:cancel})
        IO.puts("\nReceived error: " <> message)
    end
  end

  @spec error(binary) :: :ok
  defp error(message) do
    IO.puts("\nReceived error: " <> message)
  end
end

# S_client = +{!request(origin: binary, destination: binary, dep_date: binary,
#                class: atom, pass_no: number).
#               rec Y.(&{?offer(offer_no: number, total_amount: number, currency: binary,
#                               duration: number, stops: number, segments: binary).S_details,
#                        ?error(binary).S_client}),
#              !cancel()}


# S_details = +{!more_details().&{?details(...).S_book,
#                                 ?error(binary)},
#               !reject().Y}
# S_book = +{!make_booking(...).&{?ok(binary),
#                                   ?error(binary)},
#             !cancel()}
# S_details = +{!more_details().&{?details(number, number, binary, number, number, binary, number, binary).
#                                     +{!make_booking([{binary, binary}]).&{?ok(binary),
#                                                                           ?error(binary)},
#                                       !cancel()},
#                                 ?error(binary)},
#               !reject().Y}
