defmodule Mix.Tasks.Cosmos.Destroy do
  use Mix.Task

  @shortdoc "Shows how many entities exist and asks before deleting them all"

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [yes: :boolean])
    Mix.Task.run("app.start")

    case Cosmos.Database.count() do
      0 ->
        Mix.shell().info("The cosmos (#{Cosmos.Database.path()}) is empty. Nothing to delete.")

      count ->
        Mix.shell().info("Found #{count} entities in #{Cosmos.Database.path()}.")

        if opts[:yes] || Mix.shell().yes?("Are you sure you want to delete them all? (y/N)") do
          Cosmos.Database.delete_all()
          Mix.shell().info("Deleted all #{count} entities.")
        else
          Mix.shell().info("Aborted. Nothing was deleted.")
        end
    end
  end
end
