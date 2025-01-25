defmodule Mix.Tasks.Cosmos.Seed do
  use Mix.Task

  @shortdoc "Seeds the cosmos, optionally wiping existing data in the user data dir"

  def run(_args) do
    # Ensure our application (and any dependencies) is started:
    Mix.Task.run("app.start")

    data_dir = Cosmos.get_persist_dir()

    # Attempt to list files in the data_dir:
    case File.ls(data_dir) do
      {:ok, []} ->
        # The directory exists but is empty – nothing to remove, so just seed
        Mix.shell().info("Data dir is empty. Proceeding to seed...")
        seed_cosmos()

      {:ok, files} ->
        # The directory has files/folders
        file_count = length(files)
        Mix.shell().info("Found #{file_count} item(s) in #{data_dir}.")

        # Confirm removal
        if Mix.shell().yes?("Remove them to start a new cosmos? (y/N)") do
          Enum.each(files, fn file ->
            File.rm_rf!(Path.join(data_dir, file)) # recursive removal
          end)

          Mix.shell().info("Removed old data. Seeding cosmos next...")
          seed_cosmos()
        else
          Mix.shell().info("Skipping removal. Seeding cosmos on top of existing data...")
          seed_cosmos()
        end

      {:error, :enoent} ->
        # Directory does not exist at all
        Mix.shell().info("No data dir found at #{data_dir}. It will be created automatically.")
        seed_cosmos()

      {:error, reason} ->
        Mix.raise("Failed to check directory #{data_dir}. Reason: #{inspect(reason)}")
    end
  end

  # This function just demonstrates how you might seed your data.
  # Replace with your real seeding logic.
  defp seed_cosmos do
    Mix.shell().info("Seeding the cosmos with star stuff...")
    # Beings are here
    being_id = Eldritch.Being.Builder.build({:new, :being, :standard})

    # nodes are here
    node_id = Eldritch.Node.Builder.build({:new, :node})
  end
end
