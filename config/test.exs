use Mix.Config

if File.exists?("config/test.secret.exs") do
  import_config "test.secret.exs"
end
