defmodule Mix.Tasks.Cosmos.Destroy do
  use Mix.Task

  @shortdoc "Lists how many files are in the user data dir and asks to delete them"

  def run(_args) do
    Mix.Task.run("app.start")

    data_dir = Cosmos.get_persist_dir()

    case File.ls(data_dir) do
      {:ok, []} ->
        # Directory exists but is empty
        Mix.shell().info("Directory #{data_dir} is empty. Nothing to delete.")

      {:ok, files} ->
        # Directory exists and has some files
        file_count = length(files)
        Mix.shell().info("Found #{file_count} file(s) in #{data_dir}.")

        # Only prompt if there are actually files
        if file_count > 0 do
          confirm = Mix.shell().yes?("Are you sure you want to delete all these files? (y/N)")

          if confirm do
            # Remove files (File.rm_rf! is recursive for directories)
            Enum.each(files, fn file ->
              File.rm_rf!(Path.join(data_dir, file))
            end)

            Mix.shell().info("Deleted all files from #{data_dir}.")
          else
            Mix.shell().info("Aborted. No files were deleted.")
          end
        end

      {:error, :enoent} ->
        # The data dir doesn't exist at all
        Mix.shell().info("No data dir found at #{data_dir}. Nothing to delete.")

      {:error, reason} ->
        # Some other error, e.g. permissions
        Mix.raise("Failed to read directory #{data_dir}. Reason: #{inspect(reason)}")
    end
  end
end
