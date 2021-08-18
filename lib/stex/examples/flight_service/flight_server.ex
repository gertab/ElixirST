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
        "duffel_test_abcccccccc"
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
      "data" => %{
        "cabin_class" => class,
        "passengers" => List.duplicate(%{"type" => "adult"}, passengers),
        "slices" => [
          %{
            "departure_date" => departure_date,
            "destination" => destination,
            "origin" => origin
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

      next_offer(resp)
  end

  defp next_offer({:ok, []}) do
    throw("No more offers available")
  end

  defp next_offer({:ok, [next_offer | other_offers]}) do
    IO.inspect(process_offer(next_offer))

    cont = IO.gets("next y/n:")

    case cont do
      "n\n" ->
        :ok

      _ ->
        next_offer({:ok, other_offers})
    end
  end

  defp next_offer({:error, message}) do
    throw(message)
  end

  defp process_offer(offer) do
    id = offer["id"]
    {total_amount, _} = Float.parse(offer["total_amount"])
    currency = offer["total_currency"]
    slices = offer["slices"]
    segments = hd(slices)["segments"]
    stops = length(segments) - 1
    duration = hd(slices)["duration"]

    %{id: id, total_amount: total_amount, currency: currency, duration: duration, stops: stops, segments: process_segments(segments)}
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
