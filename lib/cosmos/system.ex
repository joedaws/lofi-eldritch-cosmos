defmodule Cosmos.System do
  def start_link do
    Supervisor.start_link(
      [Cosmos.Entity.Cache],
      strategy: :one_for_one
    )
  end
end
