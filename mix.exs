defmodule ElixirST.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixirst,
      version: "0.8.2",
      elixir: "~> 1.9",
      dialyzer: dialyzer(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),

      # Docs
      name: "ElixirST",
      source_url: "https://github.com/gertab/ElixirST",
      docs: [
        main: "docs",
        logo: "assets/logo.png",
        cover: "assets/logo-full.png",
        extras: ["LICENCE": [filename: "LICENCE", title: "Licence"], "Docs.md": [filename: "Docs.md", title: "Documentation"]],
        assets: "assets",
        source_ref: "master"
      ],

      # Leex/Yecc options
      # leex_options: [],
      erlc_paths: ["lib/elixirst/parser"],

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
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      # {:ex_doc, "~> 0.22.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
    ]
  end

  defp package do
    [
      maintainers: ["Gerard Tabone"],
      licenses: ["GPL-3.0"],
      links: %{"GitHub" => "https://github.com/gertab/ElixirST"},
      description: "ElixirST: Session Types in Elixir",
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
