use Mix.Config

if File.exists?("config/dev.secret.exs") do
  import_config "dev.secret.exs"

  ## Create a file (named dev.secret.exs) in the config folder, containing the following:
  ## use Mix.Config
  ## config :elixirst,
  ##   duffel_access_token: "<access token from https://duffel.com/>"
end

config :logger, level: :info
# config :logger, level: :debug # to get more details
