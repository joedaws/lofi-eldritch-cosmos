defmodule Cosmos.DatabaseWorker do
  use GenServer
  require Logger

  def start_link({persist_dir, worker_id}) do
    Logger.info("Starting database worker #{worker_id}")

    GenServer.start_link(__MODULE__, persist_dir, name: via_tuple(worker_id))
  end

  def store(worker_id, key, data) do
    GenServer.cast(via_tuple(worker_id), {:store, key, data})
  end

  def get(worker_id, key) do
    GenServer.call(via_tuple(worker_id), {:get, key})
  end

  @impl true
  def init(persist_dir) do
    File.mkdir_p!(persist_dir)
    {:ok, persist_dir}
  end

  @impl true
  def handle_cast({:store, key, data}, persist_dir) do
    file_name(persist_dir, key)
    |> File.write!(:erlang.term_to_binary(data))

    {:noreply, persist_dir}
  end

  @impl true
  def handle_call({:get, key}, _from, persist_dir) do
    data =
      case File.read(file_name(persist_dir, key)) do
        {:ok, contents} -> :erlang.binary_to_term(contents)
        {:error, :enoent} -> :enoent
        _ -> nil
      end

    Logger.info("#{self()}: fetching #{key}")

    {:reply, data, persist_dir}
  end

  defp file_name(persist_dir, key) do
    Path.join(persist_dir, to_string(key))
  end

  defp via_tuple(worker_id) do
    Cosmos.ProcessRegistry.via_tuple({__MODULE__, worker_id})
  end
end
