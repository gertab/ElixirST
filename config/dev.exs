use Mix.Config

if File.exists?("config/dev.secret.exs") do
  import_config "dev.secret.exs"

  ## Create a file (named dev.secret.exs) in the config folder, containing the following:
  ## use Mix.Config
  ## config :stex_elixir,
  ##   duffel_access_token: "<access token from https://duffel.com/>"
end
