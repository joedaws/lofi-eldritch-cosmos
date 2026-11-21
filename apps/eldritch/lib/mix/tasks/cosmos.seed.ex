defmodule Mix.Tasks.Cosmos.Seed do
  use Mix.Task

  @shortdoc "Seeds the cosmos with a landscape and beings, optionally wiping existing data"

  @moduledoc """
  Seeds the cosmos with a landscape of nodes and a population of beings.

      mix cosmos.seed [--yes] [--keep] [--beings 12] [--rings 6,10,14]

    * `--yes`    remove existing data without asking
    * `--keep`   keep existing data without asking and seed on top of it
    * `--beings` number of beings to awaken (default 12)
    * `--rings`  comma separated number of nodes on each ring of the landscape
  """

  @switches [yes: :boolean, keep: :boolean, beings: :integer, rings: :string]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    # Ensure our application (and any dependencies) is started:
    Mix.Task.run("app.start")
    # wait for the start up script to register the systems
    Eldritch.Simulation.initialize_systems()

    data_dir = Cosmos.get_persist_dir()

    case File.ls(data_dir) do
      {:ok, []} ->
        Mix.shell().info("Data dir is empty. Proceeding to seed...")

      {:ok, files} ->
        Mix.shell().info("Found #{length(files)} item(s) in #{data_dir}.")

        remove? =
          cond do
            opts[:yes] -> true
            opts[:keep] -> false
            true -> Mix.shell().yes?("Remove them to start a new cosmos? (y/N)")
          end

        if remove? do
          Eldritch.Genesis.reset()
          Mix.shell().info("Removed old data. Seeding cosmos next...")
        else
          Mix.shell().info("Keeping existing data. Seeding cosmos on top of it...")
        end

      {:error, :enoent} ->
        Mix.shell().info("No data dir found at #{data_dir}. It will be created automatically.")

      {:error, reason} ->
        Mix.raise("Failed to check directory #{data_dir}. Reason: #{inspect(reason)}")
    end

    seed_cosmos(opts)
  end

  defp seed_cosmos(opts) do
    Mix.shell().info("Seeding the cosmos with star stuff...")

    seed_opts =
      [beings: opts[:beings]]
      |> Keyword.merge(if opts[:rings], do: [rings: parse_rings(opts[:rings])], else: [])
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    %{"node_ids" => nodes, "being_ids" => beings} = Eldritch.Genesis.seed(seed_opts)
    Eldritch.Genesis.flush()
    Mix.shell().info("Created #{length(nodes)} nodes and #{length(beings)} beings.")
    Mix.shell().info("Start the simulation with: mix run --no-halt  (then open http://localhost:5454)")
  end

  defp parse_rings(rings) do
    rings |> String.split(",", trim: true) |> Enum.map(&String.to_integer(String.trim(&1)))
  end
end
