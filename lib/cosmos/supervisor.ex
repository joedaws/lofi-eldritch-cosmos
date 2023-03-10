defmodule Cosmos.Supervisor do
  def start_link do
    Supervisor.start_link(
      [
        Cosmos.ProcessRegistry,
        Cosmos.SystemRegistry,
        Cosmos.Database,
        Cosmos.Entity.Cache
      ],
      strategy: :one_for_one
    )
  end
end
