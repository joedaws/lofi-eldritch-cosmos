defmodule Cosmos.Database do
  @moduledoc """
  File backed persistence for entities.

  Requests for a given key are always routed to the same worker
  (chosen by hashing the key). This guarantees that writes for one
  entity are applied in the order they were issued, which a pooled
  (checkout based) approach does not: two quick successive `store/2`
  casts could otherwise land on different workers and finish out of
  order, persisting stale data.
  """
  require Logger

  @num_workers 3

  def child_spec(_) do
    data_path = Path.absname(persist_dir())
    Logger.info("Ensuring local directory #{data_path} has been created")
    File.mkdir_p!(data_path)

    workers =
      for worker_id <- 1..@num_workers do
        Supervisor.child_spec({Cosmos.DatabaseWorker, {worker_id, persist_dir()}}, id: worker_id)
      end

    %{
      id: __MODULE__,
      type: :supervisor,
      start: {Supervisor, :start_link, [workers, [strategy: :one_for_one]]}
    }
  end

  def store(key, data) do
    key |> choose_worker() |> Cosmos.DatabaseWorker.store(key, data)
  end

  def get(key) do
    key |> choose_worker() |> Cosmos.DatabaseWorker.get(key)
  end

  def delete(key) do
    key |> choose_worker() |> Cosmos.DatabaseWorker.delete(key)
  end

  @doc """
  Waits until every write queued so far has been flushed to disk.
  """
  def sync() do
    Enum.each(1..@num_workers, &Cosmos.DatabaseWorker.sync/1)
  end

  def query(filter) do
    # reads do not depend on ordering, any worker will do
    Cosmos.DatabaseWorker.query(1, filter)
  end

  defp choose_worker(key) do
    :erlang.phash2(to_string(key), @num_workers) + 1
  end

  defp persist_dir do
    Cosmos.get_persist_dir()
  end
end
