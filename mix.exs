defmodule LofiEldritchCosmos.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  # `MIX_ENV=prod mix release lofi` builds the whole cosmos (the ECS, the
  # simulation and the web) into _build/prod/rel/lofi. See infra/RUNBOOK.md.
  defp releases do
    [
      lofi: [
        applications: [cosmos: :permanent, eldritch: :permanent, lofi: :permanent],
        include_executables_for: [:unix]
      ]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    []
  end
end
