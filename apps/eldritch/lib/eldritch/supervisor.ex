defmodule Eldritch.Supervisor do
  def start_link do
    Supervisor.start_link(
      [
        Eldritch.Node.NameGenerator,
        Eldritch.Being.NameGenerator
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end
end
