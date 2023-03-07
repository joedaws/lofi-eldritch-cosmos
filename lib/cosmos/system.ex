defmodule Cosmos.System do
  def start_link do
    Supervisor.start_link(
      [
        Cosmos.Database,
        Cosmos.Entity.Cache
      ],
      strategy: :one_for_one
    )
  end
end
