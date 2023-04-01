defmodule Cosmos.Supervisor do
  def start_link do
    Supervisor.start_link(
      [
        Cosmos.Metrics,
        Cosmos.ProcessRegistry,
        Cosmos.SystemRegistry,
        Cosmos.System.Scheduler,
        Cosmos.Database,
        Cosmos.Entity.Cache,
        Cosmos.System
      ],
      strategy: :one_for_one
    )
  end
end
