defmodule Cosmos.Database do
  require Logger

  @num_workers 3

  def start_link do
    database_dir = persist_dir()
    Logger.info("Ensuring local directory #{database_dir} has been created")
    File.mkdir_p!(database_dir)

    children = Enum.map(1..@num_workers, &worker_spec/1)
    Logger.info("#{inspect(__MODULE__)} starting #{@num_workers} database workers")
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def store(key, data) do
    key
    |> choose_worker()
    |> Cosmos.DatabaseWorker.store(key, data)
  end

  def get(key) do
    key
    |> choose_worker()
    |> Cosmos.DatabaseWorker.get(key)
  end

  def choose_worker(key) do
    :erlang.phash2(key, @num_workers) + 1
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  defp persist_dir do
    Cosmos.get_persist_dir()
  end

  defp worker_spec(worker_id) do
    default_worker_spec = {Cosmos.DatabaseWorker, {persist_dir(), worker_id}}
    Supervisor.child_spec(default_worker_spec, id: worker_id)
  end
end
