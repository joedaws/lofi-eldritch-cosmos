defmodule Cosmos.Database do
  require Logger

  @num_workers 3

  def child_spec(_) do
    data_path = Path.absname(persist_dir())
    Logger.info("Ensuring local directory #{data_path} has been created")
    File.mkdir_p!(data_path)

    :poolboy.child_spec(
      __MODULE__,
      [
        name: {:local, __MODULE__},
        worker_module: Cosmos.DatabaseWorker,
        size: @num_workers
      ],
      [persist_dir()]
    )
  end

  def store(key, data) do
    :poolboy.transaction(
      __MODULE__,
      fn worker_pid -> Cosmos.DatabaseWorker.store(worker_pid, key, data) end
    )
  end

  def get(key) do
    :poolboy.transaction(
      __MODULE__,
      fn worker_pid -> Cosmos.DatabaseWorker.get(worker_pid, key) end
    )
  end

  defp persist_dir do
    Cosmos.get_persist_dir()
  end
end
