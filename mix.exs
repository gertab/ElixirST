defmodule ElixirSessions.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixirsessions,
      version: "0.2.0",
      elixir: "~> 1.9",
      dialyzer: dialyzer(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "ElixirSessions",
      source_url: "https://github.com/gertab/ElixirSessions",
      # The main page in the docs
      docs: [main: "ElixirSessions", extras: ["README.md"]],

      # Leex/Yecc options
      # leex_options: [],
      erlc_paths: ["lib/elixirsessions/parser"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.22.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: "priv/plts",
      plt_local_path: "priv/plts",
      plt_add_apps: [:mix]
    ]
  end
end
