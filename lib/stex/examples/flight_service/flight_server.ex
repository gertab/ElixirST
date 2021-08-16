defmodule Examples.FlightServer do

  # recompile && Examples.FlightServer.main
  def main do
    HTTPoison.start()
    HTTPoison.get!("http://httparrot.herokuapp.com/get")
  end
end
