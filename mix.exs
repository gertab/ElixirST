defmodule STEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :stex_elixir,
      version: "0.4.5",
      elixir: "~> 1.9",
      dialyzer: dialyzer(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),

      # Docs
      name: "STEx",
      source_url: "https://github.com/gertab/STEx",
      # The main page in the docs
      docs: [main: "docs", extras: ["docs.md", "LICENCE"]],

      # Leex/Yecc options
      # leex_options: [],
      erlc_paths: ["lib/stex/parser"],

      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
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
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:httpoison, "~> 1.8"}
    ]
  end

  defp package do
    [
      maintainers: ["Gerard Tabone"],
      licenses: ["GPL-3.0"],
      links: %{"GitHub" => "https://github.com/gertab/STEx"},
      description: "Session types in Elixir",
      files: ~w(lib .formatter.exs mix.exs README* LICENCE docs.md)
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
