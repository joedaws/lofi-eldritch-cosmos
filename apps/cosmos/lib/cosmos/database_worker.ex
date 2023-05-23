defmodule Cosmos.DatabaseWorker do
  use GenServer
  require Logger

  def start_link(persist_dir) do
    GenServer.start_link(__MODULE__, persist_dir)
  end

  def store(worker_pid, key, data) do
    GenServer.cast(worker_pid, {:store, key, data})
  end

  def get(worker_pid, key) do
    GenServer.call(worker_pid, {:get, key})
  end

  def delete(worker_pid, key) do
    GenServer.cast(worker_pid, {:delete, key})
  end 

  @impl true
  def init(persist_dir) do
    {:ok, persist_dir}
  end

  @impl true
  def handle_cast({:store, key, data}, persist_dir) do
    file_name(persist_dir, key)
    |> File.write!(:erlang.term_to_binary(data))

    {:noreply, persist_dir}
  end

  @impl true
  def handle_cast({:delete, key}, persist_dir) do
    file_name(persist_dir, key)
    |> File.rm!()
  end

  @impl true
  def handle_call({:get, key}, _from, persist_dir) do
    data =
      case File.read(file_name(persist_dir, key)) do
        {:ok, contents} -> :erlang.binary_to_term(contents)
        _ -> nil
      end

    Logger.info("#{inspect(self())}: fetching #{key}")
    {:reply, data, persist_dir}
  end

  defp file_name(persist_dir, key) do
    Path.join(persist_dir, to_string(key))
  end
end
