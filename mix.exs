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
      env: [
        data_path: System.get_env("COSMOS_DATA_PATH"),
        local_db_dir: System.get_env("COSMOS_LOCAL_DB_DIR"),
        monitor_metrics: System.get_env("COSMOS_MONITOR_METRICS", "true")
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ksuid, "~> 0.1.2"},
      {:quantum, "~> 3.0"}
    ]
  end
end
