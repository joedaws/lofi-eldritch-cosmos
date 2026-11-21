defmodule Eldritch.Supervisor do
  def start_link do
    Supervisor.start_link(
      [
        Eldritch.Node.NameGenerator,
        Eldritch.Being.NameGenerator,
        Eldritch.Chronicle,
        Eldritch.Simulation,
        # runs once after everything above is up
        Supervisor.child_spec({Task, &Eldritch.Setup.run/0}, restart: :temporary)
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end
end
