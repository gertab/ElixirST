defmodule Examples.FlightServer do
  defmodule Duffel do
    use HTTPoison.Base

    @endpoint "https://api.duffel.com/air/"
    @authorization DuffelApi.get()

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
          {"Authorization", "Bearer " <> @authorization},
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
  end

  # recompile && Examples.FlightServer.main
  def main do
    HTTPoison.start()
    # HTTPoison.get!("http://httparrot.herokuapp.com/get")
    # HTTPoison.request(:get, "http://httparrot.herokuapp.com/get")

    body = '{
      "data": {
          "slices": [
              {
                  "origin": "MLA",
                  "destination": "LUX",
                  "departure_date": "2021-08-21"
              }
          ],
          "passengers": [
              {
                  "type": "adult"
              },
              {
                  "type": "adult"
              },
              {
                  "age": 1
              }
          ],
          "cabin_class": "economy"
      }
  }'

    # Poison.decode!(body)
    # |> IO.inspect()

    %HTTPoison.Response{body: resp} = Duffel.post!("offer_requests", body)

    File.write!("flight.json", resp)

    Poison.decode!(resp)
  end

  def establishConnection do
    :ok
  end
end
