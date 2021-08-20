defmodule Examples.FlightServer do
  defmodule Duffel do
    use HTTPoison.Base

    @endpoint "https://api.duffel.com/air/"

    # @spec process_url(binary) :: binary
    def process_url(url) do
      @endpoint <> url
    end

    # @spec process_request_body(term) :: binary
    # def process_request_body(body)

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

    # @spec process_request_options(keyword) :: keyword
    # def process_request_options(options)

    # @spec process_response_body(binary) :: term
    # def process_response_body(body)

    # @spec process_response_chunk(binary) :: term
    # def process_response_chunk(chunk)

    # @spec process_headers([{binary, term}]) :: term
    # def process_headers(headers)

    # @spec process_response_status_code(integer) :: term
    # def process_response_status_code(status_code)
    @spec secret_key :: binary()
    def secret_key() do
      key = Application.get_env(:stex_elixir, :duffel_access_token)

      if key do
        key
      else
        IO.warn("Duffel API key not set, see config folder")
        # Get api key from https://duffel.com/ and replace the following line
        "duffel_test_abc"
      end
    end
  end

  # recompile && Examples.FlightServer.main
  def main do
    Duffel.start()

    origin = "MLA"
    destination = "LUX"
    departure_date = "2021-10-21"
    class = :economy
    passengers = 3

    body = %{
      data: %{
        cabin_class: class,
        passengers: List.duplicate(%{type: "adult"}, passengers),
        slices: [
          %{
            departure_date: departure_date,
            destination: destination,
            origin: origin
          }
        ]
      }
    }

    resp =
      case Duffel.post("offer_requests", Poison.encode!(body), [], timeout: 10000, recv_timeout: 100_000) do
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
          {:error, hd(error)["message"]}

        {:ok, %HTTPoison.Response{body: body, status_code: status_code}} when status_code >= 200 and status_code < 300 ->
          # Ok
          {:ok, Poison.decode!(body)["data"]["offers"]}
      end

    # IO.puts(length(elem(resp, 1)))
    next_offer(resp)
  end

  defp next_offer({:error, message}) do
    {:error, message}
  end

  defp next_offer({:ok, []}) do
    {:error, "No more offers available"}
  end

  defp next_offer({:ok, [next_offer | other_offers]}) do
    %{
      id: id,
      total_amount: total_amount,
      currency: currency,
      duration: duration,
      stops: stops,
      passengers: passengers,
      segments: segments
    } = process_offer(next_offer)

    IO.inspect(%{
      id: id,
      total_amount: total_amount,
      currency: currency,
      duration: duration,
      stops: stops,
      passengers: passengers,
      segments: segments
    })

    cont = IO.gets("[a]ccept/[n]ext offer/[c]ancel:")

    case cont do
      "c\n" ->
        :cancel

      "a\n" ->
        # IO.puts("Sending request to get more details")
        IO.puts("Accepting offer ##{id}")

        case Duffel.get("offers/#{id}", [], timeout: 10000, recv_timeout: 100_000) do
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
            {:error, hd(error)["message"]}

          {:ok, %HTTPoison.Response{body: body, status_code: status_code}} when status_code >= 200 and status_code < 300 ->
            # Ok
            {:ok, Poison.decode!(body)["data"]}

            IO.puts("Latest offer: ")
            IO.inspect(Poison.decode!(body)["data"])

            cont = IO.gets("[p]roceed/[c]ancel and see next offer:")

            case cont do
              "p\n" ->
                order(Poison.decode!(body)["data"])

              _ ->
                :ok
            end
        end

      _ ->
        next_offer({:ok, other_offers})
    end
  end

  defp order(details) do
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
        {:error, hd(error)["title"] <> ": " <> hd(error)["message"]}
        # {:error, Poison.decode!(body)}

      {:ok, %HTTPoison.Response{body: body, status_code: status_code}} when status_code >= 200 and status_code < 300 ->
        # Ok
        {:ok, Poison.decode!(body)["data"]}
    end
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
        born_on: "2019-08-24",
        title: "mrs",
        gender: "f",
        family_name: "Stark",
        given_name: "Morgan"
      }
    ]

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

    %{
      id: id,
      total_amount: total_amount,
      currency: currency,
      duration: duration,
      stops: stops,
      passengers: passengers,
      segments: process_segments(segments)
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
end
