defmodule Cosmos.DatabaseWorker do
  use GenServer
  require Logger

  def start_link({worker_id, persist_dir}) do
    GenServer.start_link(__MODULE__, persist_dir, name: via_tuple(worker_id))
  end

  def store(worker_id, key, data) do
    GenServer.cast(via_tuple(worker_id), {:store, key, data})
  end

  def get(worker_id, key) do
    GenServer.call(via_tuple(worker_id), {:get, key})
  end

  def delete(worker_id, key) do
    GenServer.cast(via_tuple(worker_id), {:delete, key})
  end

  def sync(worker_id) do
    GenServer.call(via_tuple(worker_id), :sync)
  end

  def query(worker_id, filter) do
    GenServer.call(via_tuple(worker_id), {:query, filter}, 30_000)
  end

  @impl true
  def init(persist_dir) do
    {:ok, persist_dir}
  end

  @impl true
  def handle_cast({:store, key, data}, persist_dir) do
    # write then rename so readers never see a half written file
    # (dotfiles are ignored when listing entities)
    tmp = Path.join(persist_dir, ".tmp-#{key}")
    File.write!(tmp, :erlang.term_to_binary(data))
    File.rename!(tmp, file_name(persist_dir, key))

    {:noreply, persist_dir}
  end

  @impl true
  def handle_cast({:delete, key}, persist_dir) do
    case File.rm(file_name(persist_dir, key)) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> Logger.warning("could not delete #{key}: #{inspect(reason)}")
    end

    {:noreply, persist_dir}
  end

  @impl true
  def handle_call({:get, key}, _from, persist_dir) do
    Logger.debug("#{inspect(self())}: fetching #{key}")
    {:reply, read(persist_dir, key), persist_dir}
  end

  @impl true
  def handle_call(:sync, _from, persist_dir) do
    {:reply, :ok, persist_dir}
  end

  @impl true
  def handle_call({:query, filter}, _from, persist_dir) do
    # In the local storage setup we can find all entities by
    # inspecting the file names in the persist_dir. It might be empty.
    # When no filter terms match we simply return an empty map.
    result =
      case filter do
        "entities" ->
          %{"entity_ids" => entity_ids(persist_dir)}

        "beings" ->
          being_ids =
            persist_dir
            |> entity_ids()
            |> Enum.filter(fn id -> being?(read(persist_dir, id)) end)

          %{"being_ids" => being_ids}

        _ ->
          %{}
      end

    {:reply, result, persist_dir}
  end

  defp entity_ids(persist_dir) do
    Path.wildcard(Path.join(persist_dir, "*"))
    |> Enum.map(&Path.basename/1)
  end

  defp being?(%Cosmos.Entity{} = entity) do
    # "is_being" marks beings; "ichor" identifies beings created before that marker existed
    Cosmos.Entity.component(entity, "is_being") != nil or
      Cosmos.Entity.component(entity, "ichor") != nil
  end

  defp being?(_), do: false

  defp read(persist_dir, key) do
    with {:ok, contents} <- File.read(file_name(persist_dir, key)) do
      try do
        :erlang.binary_to_term(contents)
      rescue
        ArgumentError ->
          Logger.warning("ignoring unreadable file for key #{key}")
          nil
      end
    else
      _ -> nil
    end
  end

  defp file_name(persist_dir, key) do
    Path.join(persist_dir, to_string(key))
  end

  defp via_tuple(worker_id) do
    Cosmos.ProcessRegistry.via_tuple({__MODULE__, worker_id})
  end
end
