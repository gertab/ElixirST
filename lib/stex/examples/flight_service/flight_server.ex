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
    departure_date = "2021-09-21"
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

    Poison.encode!(body)
    |> IO.puts()

    resp = Duffel.post("offer_requests", Poison.encode!(body))

    case resp do
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
    end

    # File.write!("flight.json", resp)

    # Poison.decode!(resp)
  end

  def establishConnection do
    :ok
  end
end
