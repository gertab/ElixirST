use Mix.Config

if File.exists?("config/prod.secret.exs") do
  import_config "prod.secret.exs"
end

config :logger, level: :info
