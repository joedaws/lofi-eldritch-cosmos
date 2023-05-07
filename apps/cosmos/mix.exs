defmodule Cosmos.MixProject do
  use Mix.Project

  def project do
    [
      app: :cosmos,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Cosmos.Application, []},
      env: [
        data_path: System.get_env("COSMOS_DATA_PATH")
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ksuid, "~> 0.1"},
      {:poolboy, "~> 1.5"},
      {:quantum, "~> 3.0"}
    ]
  end
end
