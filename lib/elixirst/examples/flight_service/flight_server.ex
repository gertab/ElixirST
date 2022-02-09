defmodule Examples.FlightServer do
  @moduledoc false

  defmodule Duffel do
    @moduledoc false
    use HTTPoison.Base

    @endpoint "https://api.duffel.com/air/"

    # @spec process_url(binary) :: binary
    def process_url(url) do
      @endpoint <> url
    end

    # @spec process_request_headers(term) :: [{binary, term}]
    def process_request_headers(headers) do
      headers ++
        [
          {"Authorization", "Bearer " <> secret_key()},
          {"Accept", "application/json"},
          {"Content-Type", "application/json"},
          {"Duffel-Version", "beta"}
        ]
    end

    @spec secret_key :: binary()
    def secret_key() do
      key = Application.get_env(:elixirst, :duffel_access_token)

      if key do
        key
      else
        IO.warn("Duffel API key not set, see config folder")
        # Get api key from https://duffel.com/ and replace the following line
        "duffel_test_abc"
      end
    end
  end

  # recompile && Examples.FlightServer.server
  def server(pid) do
    Duffel.start()

    # {origin, destination, departure_date, class, passenger_no} =
    receive do
      {:request, origin, destination, departure_date, class, passenger_no} ->
        {origin, destination, departure_date, class, passenger_no}

        # origin = "MLA" # "LUX"
        # destination = "CDG"
        # departure_date = "2021-11-21"
        # class = :economy
        # passenger_no = 3

        body = %{
          data: %{
            cabin_class: class,
            passengers: List.duplicate(%{type: "adult"}, passenger_no),
            slices: [
              %{
                departure_date: departure_date,
                destination: destination,
                origin: origin
              }
            ]
          }
        }

        case Duffel.post("offer_requests", Poison.encode!(body), [], timeout: 10000, recv_timeout: 100_000) do
          {:error, %HTTPoison.Error{reason: reason}} ->
            # Error
            send(pid, {:error, "Error while sending message: #{inspect(reason)}"})

          {:ok,
           %HTTPoison.Response{
             body: body,
             status_code: status_code
           }}
          when status_code >= 300 ->
            # Error
            error = Poison.decode!(body)["errors"]
            send(pid, {:error, hd(error)["message"]})

          {:ok, %HTTPoison.Response{body: body, status_code: status_code}} when status_code >= 200 and status_code < 300 ->
            # Ok
            # response = {:ok, Poison.decode!(body)["data"]["offers"]}
            # IO.puts(length(elem(resp, 1)))
            next_offer(pid, Poison.decode!(body)["data"]["offers"], 1)
        end

        server(pid)

      {:cancel} ->
        IO.puts("Server terminating")
        :ok
    end
  end

  defp next_offer(pid, [], offer_no) do
    send(pid, {:error, "No more offers available. Only #{offer_no - 1} offers found."})
  end

  defp next_offer(pid, [next_offer | other_offers], offer_no) do
    %{
      id: id,
      total_amount: total_amount,
      currency: currency,
      duration: duration,
      stops: stops,
      passengers: _passengers,
      segments: segments
    } = process_offer(next_offer)

    # IO.inspect(%{
    #   id: id,
    #   total_amount: total_amount,
    #   currency: currency,
    #   duration: duration,
    #   stops: stops,
    #   passengers: passengers,
    #   segments: segments
    # })

    # todo duration to number
    send(pid, {:offer, offer_no, total_amount, currency, parse_time(duration), stops, prettify_segments(segments)})

    receive do
      {:reject} ->
        next_offer(pid, other_offers, offer_no + 1)

      {:more_details} ->
        # IO.puts("Sending request to get more details")
        # IO.puts("More details regarding offer ##{id}")

        case Duffel.get("offers/#{id}", [], timeout: 10000, recv_timeout: 100_000) do
          {:error, %HTTPoison.Error{reason: reason}} ->
            # Error
            send(pid, {:error, "Error while sending message: #{inspect(reason)}"})
            next_offer(pid, other_offers, offer_no)

          {:ok,
           %HTTPoison.Response{
             body: body,
             status_code: status_code
           }}
          when status_code >= 300 ->
            # Error
            error = Poison.decode!(body)["errors"]
            send(pid, {:error, hd(error)["message"]})
            next_offer(pid, other_offers, offer_no)

          {:ok, %HTTPoison.Response{body: body, status_code: status_code}} when status_code >= 200 and status_code < 300 ->
            # Ok
            {:ok, Poison.decode!(body)["data"]}

            # IO.puts("Latest offer: ")
            # IO.inspect(Poison.decode!(body)["data"])
            %{
              id: _id,
              total_amount: total_amount,
              currency: currency,
              duration: duration,
              stops: stops,
              passengers: passengers,
              segments: segments,
              departure_time: departure_time
            } = process_offer(Poison.decode!(body)["data"])

            send(
              pid,
              {:details, offer_no, total_amount, currency, parse_time(duration), stops, prettify_segments(segments), length(passengers),
               departure_time}
            )

            # cont = IO.gets("[p]roceed/[c]ancel and see next offer:")

            receive do
              {:make_booking, names} ->
                order(pid, names, Poison.decode!(body)["data"])

              {:cancel} ->
                :ok
            end
        end
    end
  end

  defp order(pid, _names, details) do
    order = %{
      data: %{
        selected_offers: [details["id"]],
        payments: [
          %{
            type: "balance",
            currency: details["base_currency"],
            amount: details["total_amount"]
          }
        ],
        passengers: passenger_details(details["passengers"])
      }
    }

    case Duffel.post("orders", Poison.encode!(order), [], timeout: 10000, recv_timeout: 100_000) do
      {:error, %HTTPoison.Error{reason: reason}} ->
        # Error
        {:error, "Error while sending message: #{inspect(reason)}"}

      {:ok,
       %HTTPoison.Response{
         body: body,
         status_code: status_code
       }}
      when status_code >= 300 ->
        # Error
        error = Poison.decode!(body)["errors"]
        send(pid, {:error, hd(error)["title"] <> ": " <> hd(error)["message"]})

      {:ok, %HTTPoison.Response{body: body, status_code: status_code}} when status_code >= 200 and status_code < 300 ->
        # Ok, booking created
        send(pid, {:ok, process_booking_details(Poison.decode!(body)["data"])})
    end
  end

  defp process_booking_details(details) when is_map(details) do
    # %{
    # booking_reference:
    details["booking_reference"]
    # }
  end

  defp passenger_details(passengers) when is_list(passengers) do
    details = [
      %{
        phone_number: "+442080160508",
        email: "tony@example.com",
        born_on: "1980-07-24",
        title: "mr",
        gender: "m",
        family_name: "Stark",
        given_name: "Tony"
      },
      %{
        phone_number: "+442080160509",
        email: "potts@example.com",
        born_on: "1983-11-02",
        title: "mrs",
        gender: "m",
        family_name: "Potts",
        given_name: "Pepper"
      },
      %{
        phone_number: "+442080160506",
        email: "morgan@example.com",
        born_on: "2000-08-24",
        title: "mrs",
        gender: "f",
        family_name: "Stark",
        given_name: "Morgan"
      },
      %{
        phone_number: "+442080160506",
        email: "morgan@example.com",
        born_on: "1973-09-24",
        title: "mr",
        gender: "m",
        family_name: "Mac",
        given_name: "Morgan"
      },
      %{
        phone_number: "+442080160506",
        email: "morgan@example.com",
        born_on: "1972-10-24",
        title: "mr",
        gender: "m",
        family_name: "Mabey",
        given_name: "Ian"
      }
    ]

    # details = List.duplicate(details, length(passengers))
    # details = Enum.zip(details, 1..length(details))
    # |> Enum.map(fn {detail, index} -> %{detail | given_name: detail[:given_name]<>"#{index}"} end)

    for {passenger, detail} <- Enum.zip(passengers, details) do
      Map.merge(detail, %{id: passenger["id"], type: passenger["type"]})
    end
  end

  defp process_offer(offer) do
    id = offer["id"]
    {total_amount, _} = Float.parse(offer["total_amount"])
    currency = offer["total_currency"]
    slices = offer["slices"]
    segments = hd(slices)["segments"]
    passengers = hd(segments)["passengers"]
    stops = length(segments) - 1
    duration = hd(slices)["duration"]
    departure_time = hd(segments)["departing_at"]

    %{
      id: id,
      total_amount: total_amount,
      currency: currency,
      duration: duration,
      stops: stops,
      passengers: passengers,
      segments: process_segments(segments),
      departure_time: departure_time
    }
  end

  defp process_segments(segments) when is_list(segments) do
    for segment <- segments do
      origin_city_name = segment["origin"]["city_name"]
      origin_iata_code = segment["origin"]["iata_code"]
      destination_city_name = segment["destination"]["city_name"]
      destination_iata_code = segment["destination"]["iata_code"]
      departing_at = segment["departing_at"]
      arriving_at = segment["arriving_at"]
      marketing_carrier = segment["marketing_carrier"]["name"]
      marketing_carrier_code = segment["marketing_carrier"]["iata_code"]
      marketing_carrier_flight_number = segment["marketing_carrier_flight_number"]

      %{
        origin_city_name: origin_city_name,
        origin_iata_code: origin_iata_code,
        destination_city_name: destination_city_name,
        destination_iata_code: destination_iata_code,
        marketing_carrier: marketing_carrier,
        departing_at: departing_at,
        arriving_at: arriving_at,
        flight_number: marketing_carrier_code <> marketing_carrier_flight_number
      }
    end
  end

  defp prettify_segments(segments) when is_list(segments) do
    for segment <- segments do
      %{
        origin_city_name: origin_city_name,
        origin_iata_code: origin_iata_code,
        destination_city_name: destination_city_name,
        destination_iata_code: destination_iata_code,
        marketing_carrier: marketing_carrier,
        departing_at: _departing_at,
        arriving_at: _arriving_at,
        flight_number: flight_number
      } = segment

      "#{marketing_carrier} #{flight_number}: #{origin_city_name} (#{origin_iata_code}) -> #{destination_city_name} (#{destination_iata_code})"
    end
    |> Enum.join(", ")
  end

  defp parse_time(duration) when is_binary(duration) do
    split = String.split(duration, ~r[P|D|T|H|M])

    case length(split) do
      5 ->
        IO.warn(duration)
        IO.warn(split)
        [_, _, hours, minutes, _seconds] = split
        String.to_integer(hours) * 60 + String.to_integer(minutes)

      6 ->
        [_, days, _, hours, minutes, _seconds] = split
        String.to_integer(days) * 24 * 60 + String.to_integer(hours) * 60 + String.to_integer(minutes)

      _ ->
        # throw("Error parsing time: #{duration} :::: #{inspect split}")
        0
    end
  end
end
