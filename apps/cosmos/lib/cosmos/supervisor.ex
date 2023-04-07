defmodule Cosmos.Supervisor do
  def start_link do
    # TODO add a task module which can be used
    # as a start up script
    Supervisor.start_link(
      [
        Cosmos.ProcessRegistry,
        Cosmos.SystemRegistry,
        Cosmos.System.Scheduler,
        Cosmos.Database,
        Cosmos.Entity.Cache,
        Cosmos.System
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end
end
