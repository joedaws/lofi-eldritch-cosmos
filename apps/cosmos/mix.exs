defmodule Cosmos.MixProject do
  use Mix.Project

  def project do
    [
      app: :cosmos,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Cosmos.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ksuid, "~> 0.1"},
      {:quantum, "~> 3.0"},
      {:poison, "~> 5.0"},
      # 0.36 is the last release supporting Elixir < 1.17 (.mise.toml pins 1.16)
      {:exqlite, "~> 0.36.0"}
    ]
  end
end
