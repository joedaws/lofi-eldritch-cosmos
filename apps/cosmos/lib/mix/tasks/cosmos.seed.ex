defmodule Mix.Tasks.Cosmos.Seed do
  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")
    IO.puts("Seeding the simulation")

    # Beings are here
    being_id = Eldritch.Being.Builder.build({:new, :being, :standard})

    # nodes are here
    node_id = Eldritch.Node.Builder.build({:new, :node})
  end
end
