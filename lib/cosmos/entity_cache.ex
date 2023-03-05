defmodule Cosmos.EntityCache do
  use GenServer
  require Logger

  def start_link([]) do
    Logger.info("Starting the entity cache")
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def server_process(entity_id) do
    GenServer.call(__MODULE__, {:server_process, entity_id})
  end

  def server_process() do
    GenServer.call(__MODULE__, {:server_process})
  end

  @impl true
  def init(_) do
    Cosmos.Database.start()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:server_process, entity_id}, _from, entity_servers) do
    case Map.fetch(entity_servers, entity_id) do
      {:ok, entity_server} ->
        Logger.info("Fetched worker process for existing entity #{entity_id}")
        {:reply, entity_server, entity_servers}

      :error ->
        {:ok, new_server} = Cosmos.EntityServer.start(entity_id)
        Logger.info("Started worker process for existing entity #{entity_id}")
        {:reply, new_server, Map.put(entity_servers, entity_id, new_server)}
    end
  end

  @impl true
  def handle_call({:server_process}, _from, entity_servers) do
    {:ok, new_server} = Cosmos.EntityServer.start()
    entity_id = Cosmos.EntityServer.get(new_server).id
    Logger.info("Started worker process for new entity #{entity_id}")
    {:reply, new_server, Map.put(entity_servers, entity_id, new_server)}
  end
end
